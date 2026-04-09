# 进面分数线数据扩充计划

## Context

当前 `exam_entry_scores` 功能已实现完整的 Model/Service/DB/Screen，数据从 `assets/` JSON 导入 SQLite。但实际数据严重不足：

| 数据 | 数量 | 状态 |
|------|------|------|
| 江苏省考 2024 | 2,151 | 真实数据（qihejy.com Excel） |
| 国考 2024+2023 | 41 | 真实数据（eoffcn.com HTML） |
| 浙江/上海/山东省考 | ~11 | 示例数据 |
| 事业编（全部） | ~10 | 示例数据 |
| 历史年份 2020-2023 | ~4 | 几乎空白 |

**目标**：通过逆向华图查询系统 API + 补充政府 Excel 等手段，将数据扩充到 **10,000+ 条真实记录**，覆盖四省（江浙沪鲁）× 三类考试（国考/省考/事业编）× 多年。

---

## Phase 1: 逆向华图 skfscx 查询系统 API（核心突破点）

华图 `https://www.huatu.com/z/2024skfscx/` 是 Vue.js SPA，有省份/城市/年份下拉筛选。数据通过后端 API 加载，但 API URL 未暴露在 HTML 中。

### 步骤

1. **下载 SPA 页面，提取 JS bundle URL**
   - `WebFetch` 获取页面 HTML
   - 解析 `<script src="...">` 标签，找到 webpack/vite 打包的 JS 文件路径

2. **下载 JS bundle，搜索 API 端点**
   - 在 JS 源码中搜索：`axios`, `fetch(`, `/api/`, `fscx`, `score`, `fenshu`, `.json`, `province`, `city`
   - 识别 API URL 模式和请求参数结构

3. **测试 API 调用**
   - 用 `requests` 直接调用发现的 API
   - 验证返回 JSON 包含分数数据
   - 检查 robots.txt 合规

4. **实现 `huatu_api_scraper.py`**
   - 继承 `ScraperBase`
   - 配置省份→华图编码映射
   - 遍历四省 × 多年，逐页获取数据
   - 输出标准 record dict（与现有 data_cleaner 兼容）

### 文件变更
- 新建: `tools/exam_score_scraper/huatu_api_scraper.py`
- 修改: `tools/exam_score_scraper/export_json.py` — 集成华图 API 爬虫

### 如果 API 逆向失败（JS 高度混淆）
- 回退方案：用 Playwright 执行一次浏览器自动化，抓取 Network 面板中的 API 请求
- 新建: `tools/exam_score_scraper/discover_api.py`（一次性脚本，捕获 API URL/参数）
- 新增依赖: `playwright` 到 `requirements.txt`（标记为可选）

### 预期产出
- 省考: 四省 × 2-3 年 = 5,000-20,000 条
- 事业编: 如果 API 也覆盖事业编 = 2,000-8,000 条

---

## Phase 2: 山东文章页 HTML 内容挖掘

`sd.huatu.com/2024/1029/1559730.html` 已成功获取（85KB），但之前只找 Excel 链接。85KB 的 HTML 可能包含内联数据。

### 步骤

1. 获取文章 HTML，分析 `<div class="content">` 内的正文结构
2. 尝试多种提取策略：
   - HTML table（之前漏掉的嵌套表格）
   - 结构化文本（`职位：XXX 最低分：XXX` 模式）
   - 文章内的其他链接（可能链接到各地市分数线子页面）
3. 如果有数据则加入 `shengkao_scraper.py`

### 文件变更
- 修改: `tools/exam_score_scraper/shengkao_scraper.py` — 新增 `_scrape_shandong_article()` 方法

### 预期产出
- 200-500 条山东省考数据（如果文章包含内联表格）

---

## Phase 3: 政府网站 Excel 文件补充

已知可用的政府 Excel：
- **国家金融监管总局**: `https://www.nfra.gov.cn/chinese/docfile/2024/...xls` (~915KB, 2024面试名单)
- 其他中央机关可能有类似的公示 Excel

### 步骤

1. 检查 nfra.gov.cn robots.txt
2. 下载并解析 Excel（复用 `shengkao_scraper.py` 中的 pandas Excel 解析模式）
3. 提取江浙沪鲁的国考岗位数据

### 文件变更
- 修改: `tools/exam_score_scraper/guokao_scraper.py` — 新增 `_scrape_nfra_excel()` 方法

### 预期产出
- 100-300 条国考数据

---

## Phase 4: 华图省站 ECharts 数据提取

`js.huatu.com/skzwb/{year}/fenshu/` 等页面的 ECharts 图表数据以 JS 数组形式硬编码在 HTML 中。

### 步骤

1. 获取各省页面 HTML
2. 用正则提取 `data: [...]` 或 `series: [{data: [...]}]` JS 数组
3. 解析为城市级别汇总数据（非岗位级别，作为补充）

### 文件变更
- 新建: `tools/exam_score_scraper/huatu_echarts_scraper.py`（轻量级）

### 预期产出
- 50-200 条城市级汇总数据（辅助热度分析）

---

## Phase 5: 管道集成和数据导出

### 步骤

1. 更新 `export_json.py` 集成所有新爬虫
2. 运行全量爬取 `python export_json.py`
3. 用真实数据替换示例 JSON 文件
4. 更新 `index.json`
5. 更新 `README.md` 数据源状态表

### 文件变更
- 修改: `tools/exam_score_scraper/export_json.py`
- 修改: `tools/exam_score_scraper/requirements.txt`（如需 Playwright）
- 修改: `tools/exam_score_scraper/README.md`
- 更新: `assets/data/exam_entry_scores/*.json`

---

## 验证策略

1. **每个爬虫单独运行** `python xxx_scraper.py`，检查输出记录数和数据质量
2. **管道运行** `python export_json.py`，确认所有 JSON 文件正确生成
3. **数据质量检查**：
   - 分数范围 30-300（data_cleaner 自动校验）
   - 去重正确（同一岗位不重复）
   - 城市名称是真实地名
4. **Flutter 应用验证**：`flutter analyze` + `flutter test` + 手动运行确认数据加载
5. **合规检查**：所有域名 robots.txt 已检查，请求间隔 ≥2s

---

## 关键文件清单

| 文件 | 操作 |
|------|------|
| `tools/exam_score_scraper/huatu_api_scraper.py` | 新建 |
| `tools/exam_score_scraper/huatu_echarts_scraper.py` | 新建 |
| `tools/exam_score_scraper/discover_api.py` | 新建（回退方案） |
| `tools/exam_score_scraper/guokao_scraper.py` | 修改（NFRA Excel） |
| `tools/exam_score_scraper/shengkao_scraper.py` | 修改（山东文章页） |
| `tools/exam_score_scraper/shiyebian_scraper.py` | 修改（接入华图 API） |
| `tools/exam_score_scraper/export_json.py` | 修改（集成新爬虫） |
| `tools/exam_score_scraper/requirements.txt` | 可能修改 |
| `tools/exam_score_scraper/README.md` | 修改 |
| `assets/data/exam_entry_scores/*.json` | 更新数据 |
| `assets/data/exam_entry_scores/index.json` | 更新索引 |

## 执行顺序

Phase 1 是核心（华图 API 可能覆盖大部分缺口），其余 Phase 并行补充。如果 Phase 1 成功获取足够数据，Phase 2-4 优先级降低。
