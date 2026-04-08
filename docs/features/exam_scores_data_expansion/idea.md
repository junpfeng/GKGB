# 进面分数线数据扩充（exam_scores_data_expansion）

## 核心需求
当前进面分数线真实数据仅 ~2,192 条（江苏省考 2,151 + 国考 41），其余均为示例数据。目标通过逆向华图查询系统 API + 补充政府 Excel + HTML 内容挖掘等手段，将数据扩充到 **10,000+ 条真实记录**，覆盖四省（江浙沪鲁）× 三类考试（国考/省考/事业编）× 多年。

## 调研上下文

### 已有爬虫工具链（tools/exam_score_scraper/）
- **ScraperBase** (`scraper_base.py`): 基类，2s 节流、robots.txt 检查、User-Agent、自动重试
- **GuokaoScraper** (`guokao_scraper.py`): 国考爬虫，数据源 eoffcn.com + gwy.com，产出 37+4=41 条
- **ShengkaoScraper** (`shengkao_scraper.py`): 省考爬虫，仅江苏 qihejy.com Excel 实现，产出 2,151 条；山东/浙江/上海无数据源
- **ShiyebianScraper** (`shiyebian_scraper.py`): 事业编爬虫，框架存在但无数据源，返回空列表
- **DataCleaner** (`data_cleaner.py`): 省份/考试类型标准化、分数范围 30-300 校验、复合键去重
- **export_json.py**: 编排器，按省份+类型+年份分组输出 JSON + index.json 增量合并
- **requirements.txt**: requests, beautifulsoup4, pandas, lxml, openpyxl

### 已有 JSON asset 数据
- 13 个文件，真实数据仅 `jiangsu_shengkao_2024.json`（2,151 条）和 `guokao_2024.json`（37 条）+ `guokao_2023.json`（4 条）
- 其余为示例/占位数据

### Flutter 端无需变更
- ExamEntryScore model、exam_entry_scores 表（v14）、ExamEntryScoreService（loadFromAssets）、ExamEntryScoresScreen 均已完整实现
- 数据扩充后只需替换 assets JSON 文件，app 自动加载

### 数据扩充计划（5 个 Phase）
1. **Phase 1 - 华图 skfscx API 逆向**（核心）：逆向 `huatu.com/z/2024skfscx/` Vue SPA 的后端 API，批量获取四省多年数据。预期 5,000-20,000 条
2. **Phase 2 - 山东文章页 HTML 挖掘**：分析 sd.huatu.com 85KB 文章页内联数据。预期 200-500 条
3. **Phase 3 - 政府 Excel 补充**：国家金融监管总局等中央机关公示 Excel。预期 100-300 条
4. **Phase 4 - 华图 ECharts 数据提取**：省站页面 ECharts 图表 JS 数组。预期 50-200 条城市级汇总
5. **Phase 5 - 管道集成**：更新 export_json.py 集成所有新爬虫，全量导出

## 范围边界
- 做：新建/修改 Python 爬虫脚本、数据清洗、JSON asset 更新、index.json 更新、README 更新
- 不做：Flutter 端代码变更（model/service/screen/db 均不动）、运行时爬取功能、自动更新机制

## 初步理解
这是一个纯 Python 工具链扩展任务。核心突破点是逆向华图查询系统 API（Phase 1），如果成功可一次性获取大量数据。其余 Phase 是补充手段。所有新爬虫继承已有 ScraperBase，输出标准 record dict 经 DataCleaner 清洗后由 export_json.py 统一导出。最终产出是更新后的 assets JSON 文件。

## 待确认事项
见下方互动确认

## 确认方案

核心思路：通过华图 API 逆向 + HTML 挖掘 + 政府 Excel + ECharts 提取，多源互补将进面分数线数据从 ~2,192 条扩充到 10,000+ 条，覆盖四省 × 三类考试 × 2020-2025。

### 锁定决策

工具层（纯 Python，不涉及 Flutter 代码变更）：

Phase 1 - 华图 skfscx API 逆向（核心突破）：
  - 新建: `tools/exam_score_scraper/huatu_api_scraper.py`
  - 继承 ScraperBase，独立文件（一个 API 可能覆盖国考/省考/事业编）
  - 目标: `https://www.huatu.com/z/2024skfscx/` Vue SPA 后端 API
  - 逆向策略（按顺序尝试，直到成功）：
    1. WebFetch 下载页面 HTML → 提取 JS bundle URL
    2. 下载 JS bundle → 正则搜索 API 端点（axios/fetch/api/fscx/score 等关键词）
    3. 若 JS 混淆严重 → 引入 Playwright 浏览器自动化，捕获 Network 面板 API 请求
    4. 若 Playwright 也失败 → 新建 `discover_api.py` 一次性脚本，手动抓包记录 API URL 到配置
  - 参数: 省份编码映射（江浙沪鲁）× 年份（2020-2025）× 考试类型
  - 输出: 标准 record dict，兼容 DataCleaner

Phase 2 - 山东文章页 HTML 挖掘：
  - 修改: `tools/exam_score_scraper/shengkao_scraper.py`
  - 新增 `_scrape_shandong_article()` 方法
  - 解析 sd.huatu.com 文章页 <div class="content"> 内的内联表格/结构化文本
  - 尝试: HTML table、"职位：XXX 最低分：XXX" 模式、子页面链接

Phase 3 - 政府 Excel 补充：
  - 修改: `tools/exam_score_scraper/guokao_scraper.py`
  - 新增 `_scrape_nfra_excel()` 方法
  - 数据源: 国家金融监管总局 nfra.gov.cn 等中央机关公示 Excel
  - 复用 pandas Excel 解析模式

Phase 4 - 华图 ECharts 数据提取（最低优先级）：
  - 新建: `tools/exam_score_scraper/huatu_echarts_scraper.py`（轻量级）
  - 正则提取 JS 数组 `data: [...]` / `series: [{data: [...]}]`
  - 产出城市级汇总数据（非岗位级，辅助热度分析）

Phase 5 - 管道集成：
  - 修改: `tools/exam_score_scraper/export_json.py` — 集成所有新爬虫
  - 修改: `tools/exam_score_scraper/requirements.txt` — 添加 playwright（可选依赖）
  - 修改: `tools/exam_score_scraper/README.md` — 更新数据源状态表
  - 更新: `assets/data/exam_entry_scores/*.json` — 真实数据替换示例
  - 更新: `assets/data/exam_entry_scores/index.json`

数据范围：
  - 省份: 江苏、浙江、上海、山东
  - 考试类型: 国考、省考、事业编
  - 年份: 2020-2025
  - 所有 Phase 数据互补，不因某 Phase 数据充足而跳过其他

合规：
  - 所有域名先检查 robots.txt
  - 请求间隔 ≥2s
  - 携带 User-Agent 标识
  - 数据仅用于本地学习分析

范围边界：
  - 做：5 个 Phase 全部执行，Python 爬虫开发，数据清洗导出，asset 更新
  - 不做：Flutter 端代码变更（model/service/screen/db 不动），运行时爬取，自动更新

### 待细化
  - 华图 API 具体 URL 和参数结构：需逆向后确定
  - 各 Phase 具体网站 HTML 结构和解析规则：实现时根据实际页面确定
  - Playwright 是否需要：取决于 Phase 1 静态分析结果

### 验收标准
  - [mechanical] 华图 API 爬虫存在：判定 `ls tools/exam_score_scraper/huatu_api_scraper.py`
  - [mechanical] ECharts 爬虫存在：判定 `ls tools/exam_score_scraper/huatu_echarts_scraper.py`
  - [mechanical] export_json 集成新爬虫：判定 `grep "huatu_api" tools/exam_score_scraper/export_json.py`
  - [mechanical] 四省均有真实数据（每省 ≥1 个非示例 JSON）：判定 `wc -l` 各省 JSON 文件记录数
  - [mechanical] index.json 已更新：判定 `cat assets/data/exam_entry_scores/index.json`
  - [mechanical] README 已更新：判定 `grep "huatu_api" tools/exam_score_scraper/README.md`
  - [manual] 运行 `python tools/exam_score_scraper/export_json.py` 全量导出成功，总记录数显著增长
  - [manual] Flutter 应用 `flutter run -d windows` 进入分数线页面，四省均可筛选到真实数据
