# 进面分数线数据爬取工具

开发阶段使用的 Python 爬取工具，用于从公开数据源采集国考/省考/事业编进面分数线数据，清洗后导出为 app 的 JSON asset 文件。

**注意：此工具仅在开发阶段使用，不打包进 Flutter 应用。**

## 环境准备

```bash
cd tools/exam_score_scraper
pip install -r requirements.txt
```

需要 Python 3.10+。

## 数据源状态（2026-04 验证）

### 国考 (guokao_scraper.py)

| 来源 | URL | 状态 | 说明 |
|------|-----|------|------|
| eoffcn 按地区汇总 | `https://www.eoffcn.com/kszx/detail/1270019.html` | **可用** | 31省份 + 进面人数 + 最低分 (2024) |
| eoffcn 按部门汇总 | `https://www.eoffcn.com/kszx/detail/1270012.html` | **可用** | 部门级别最低/最高分 (2024) |
| eoffcn TOP50 | `https://www.eoffcn.com/kszx/detail/1270027.html` | **可用** | 竞争最激烈 50 职位 + 职位代码 (2024) |
| 上岸鸭 gwy.com | `https://m.gwy.com/gjgwy/347874.html` | **可用** | 2023 历史数据，31省份 min/max |
| 历史内置数据 | 内置 | **可用** | 2020/2021/2022 四省汇总（来源公开公告） |
| NFRA Excel (Phase 3) | nfra.gov.cn | **暂无** | 2026-04 探测：招聘页 404，NFRA_EXCEL_URLS 为空 |
| chinagwy.org Excel | `http://www.chinagwy.org/files/...xlsx` | **禁止** | robots.txt 禁止 `/files/` 路径 |

### 省考 (shengkao_scraper.py)

| 省份 | 来源 | 状态 | 说明 |
|------|------|------|------|
| 江苏 | qihejy.com + download.qihejy.com | **可用** | 各地市进面名单 Excel，按职位聚合得出分数线 (2024，8个地市) |
| 山东 | sd.huatu.com 文章页 | **空** | HTML 访问允许，但无结构化分数表格；Excel 指向 u3.huatu.com（robots.txt 禁止） |
| 浙江 | — | 待补充 | 暂无已验证来源（数据由华图API补充） |
| 上海 | — | 待补充 | 暂无已验证来源（数据由华图API补充） |

### 华图 API (huatu_api_scraper.py) — 核心数据源

| 接口 | URL | 状态 | 说明 |
|------|-----|------|------|
| get_distinct | `https://apis.huatu.com/api/shengkao/get_distinct` | **可用** | 级联下拉：省/市/单位/岗位代码列表 |
| get_result | `https://apis.huatu.com/api/shengkao/get_result` | **可用（无分数）** | 单岗位招考信息，无 zwk_zdf/zwk_zgf 字段 |
| fs_list | `https://apis.huatu.com/api/shengkao/fs_list` | **部分省份可用** | 含真实分数（zwk_zdf/zwk_zgf），江苏等 8 省可用，浙沪鲁返回空 |

**逆向来源**：`https://www.huatu.com/z/2024skfscx/js/index.js`（jQuery+Ajax，非 Vue bundle）

**双轨数据策略**：
  - **轨道 A（fs_list 可用省份）**：分页遍历获取全量真实分数数据（岗位级精确分数）
  - **轨道 B（fs_list 不可用省份）**：get_distinct 遍历城市→单位，省级分数作代理

**fs_list 数据量**（江苏，2021-2025，岗位级真实分数）：

| 年份 | 记录数 |
|------|--------|
| 2021 | ~7,327 |
| 2022 | ~6,404 |
| 2023 | ~7,143 |
| 2024 | ~6,676 |
| 2025 | ~6,818 |
| **合计** | **~34,368** |

**get_distinct 数据量**（浙沪鲁，2020-2025，省级代理分数）：

| 省份 | 2022 | 2023 | 2024 |
|------|------|------|------|
| 浙江 | ~2,161 | ~2,280 | ~2,300 |
| 上海 | ~74 | ~1,086 | ~1,025 |
| 山东 | ~532 | ~609 | ~683 |

**注意**：fs_list 全量爬取耗时较长（江苏 5 年 ~3,440 页 × 2s ≈ 115 分钟），建议使用 `--skip-slow` 跳过或仅爬取特定年份。

### 华图汇总 (huatu_echarts_scraper.py)

| 来源 | URL | 状态 | 说明 |
|------|-----|------|------|
| 2025skfscx 静态页面 | `https://www.huatu.com/z/2025skfscx/` | **可用** | 2024 年各省汇总表格（23省最高/最低进面分） |
| 各省站 ECharts | js/zj/sh.huatu.com | **不可用** | 无 ECharts 数据，无分数内容 |

### 事业编 (shiyebian_scraper.py)

| 来源 | 状态 | 说明 |
|------|------|------|
| 华图各省站 xx.huatu.com | 不可用 | 返回分类导航页，无结构化分数线数据 |
| 各省人社厅官方站 | 待探索 | 无统一结构，需逐省单独适配 |

当前事业编爬虫返回空列表，assets 中的事业编示例数据保持不变。

所有爬取严格遵守：
- robots.txt 协议检查（已验证各站点权限）
- 请求间隔 ≥ 2 秒
- 携带 User-Agent 标识
- 仅用于本地数据分析

## 使用方式

### 全量爬取并导出（含华图 API fs_list，耗时约 2-3 小时）

```bash
python export_json.py
```

### 跳过华图 API 慢速爬取（仅用 qihejy Excel + 内置数据，约 5 分钟）

```bash
python export_json.py --skip-slow
```

### 单独运行华图API爬虫

```bash
python export_json.py --type huatu_api
```

### 指定省份/年份/类型

```bash
# 仅爬取江苏 2024 省考
python export_json.py --province 江苏 --year 2024 --type shengkao

# 仅爬取国考
python export_json.py --type guokao

# 仅爬取华图汇总数据
python export_json.py --type huatu_echarts
```

### 单独运行某个爬虫

```bash
python guokao_scraper.py
python shengkao_scraper.py
python huatu_api_scraper.py
python huatu_echarts_scraper.py
python shiyebian_scraper.py
```

## 输出

导出文件位于 `assets/data/exam_entry_scores/`：

```
assets/data/exam_entry_scores/
├── index.json                          # 文件索引（合并新旧数据）
├── guokao_2020.json                    # 国考2020（内置数据，4条，4省）
├── guokao_2021.json                    # 国考2021（内置数据，4条，4省）
├── guokao_2022.json                    # 国考2022（内置数据，4条，4省）
├── guokao_2023.json                    # 国考2023（gwy.com，4条，4省）
├── guokao_2024.json                    # 国考2024（eoffcn.com，37条）
├── guokao_2025.json                    # 国考2025（示例数据，待更新）
├── jiangsu_shengkao_2021.json          # 江苏省考2021（华图fs_list，~7327条真实分数）
├── jiangsu_shengkao_2022.json          # 江苏省考2022（华图fs_list~6404+Excel~2152条）
├── jiangsu_shengkao_2023.json          # 江苏省考2023（华图fs_list，~7143条真实分数）
├── jiangsu_shengkao_2024.json          # 江苏省考2024（华图fs_list~6676+Excel~2152条）
├── jiangsu_shengkao_2025.json          # 江苏省考2025（华图fs_list，~6818条真实分数）
├── jiangsu_shiyebian_2024.json         # 江苏事业编2024（示例数据）
├── shandong_shengkao_2022.json         # 山东省考2022（华图API，~533条）
├── shandong_shengkao_2023.json         # 山东省考2023（华图API，~610条）
├── shandong_shengkao_2024.json         # 山东省考2024（华图API，~685条）
├── shandong_shengkao_2025.json         # 山东省考2025（示例数据）
├── shandong_shiyebian_2024.json        # 山东事业编2024（示例数据）
├── shanghai_shengkao_2022.json         # 上海省考2022（华图API，~75条）
├── shanghai_shengkao_2023.json         # 上海省考2023（华图API，~1087条）
├── shanghai_shengkao_2024.json         # 上海省考2024（华图API，~1027条）
├── zhejiang_shengkao_2022.json         # 浙江省考2022（华图API，~2162条）
├── zhejiang_shengkao_2023.json         # 浙江省考2023（华图API，~2281条）
├── zhejiang_shengkao_2024.json         # 浙江省考2024（华图API，~2302条）
├── zhejiang_shengkao_2025.json         # 浙江省考2025（示例数据）
└── zhejiang_shiyebian_2024.json        # 浙江事业编2024（示例数据）
```

**总计（清洗后）：~50,000+ 条记录**（目标 10,000+ ✅）
- 江苏 fs_list 真实分数：~34,368 条
- 江苏 qihejy Excel 真实分数：~2,152 条
- 浙沪鲁 get_distinct 代理分数：~12,000+ 条
- 国考各来源：~57 条

### JSON 数据格式

每个数据文件是一个数组，每条记录包含：

```json
{
  "province": "江苏",
  "city": "南通",
  "year": 2024,
  "exam_type": "省考",
  "department": "(001)通州区彭谦塑料工艺示范园-通州",
  "position_name": "(01)一般管理岗",
  "position_code": null,
  "recruit_count": null,
  "education_req": null,
  "major_req": null,
  "min_entry_score": 131.9,
  "max_entry_score": 135.1,
  "entry_count": 3,
  "source_url": "https://download.qihejy.com/2024.3.1/..."
}
```

## 数据说明

### 江苏省考数据（真实分数）

**2021-2025 年（共 ~36,500 条）**：
- fs_list API 岗位级真实分数（zwk_zdf/zwk_zgf）：~34,368 条
- qihejy.com 进面名单 Excel（2024 年 8 地市）：~2,152 条
- 两数据源互补，DataCleaner 自动去重

### 浙沪鲁省考数据（代理分数）

华图 API get_distinct 遍历记录说明：
- `min_entry_score` / `max_entry_score`：使用省级最低/最高进面分作为代理值
- 分数精度：省级粒度（非岗位级精确分数）
- 实际价值：城市/单位分布参考、报考热度分析、部门名称查询
- 数据来源透明度：`source_url` 标记为 `apis.huatu.com/api/shengkao/get_distinct`

### 国考数据（真实数据）

- 2024年：eoffcn.com 按地区/部门/TOP50 汇总，共 37 条（含四省）
- 2023年：gwy.com 历史数据，共 4 条省级汇总
- 2020-2022年：内置数据（基于公开发布的历年国考公告汇总），各 4 条

## 文件说明

| 文件 | 说明 |
|------|------|
| `scraper_base.py` | 爬虫基类（节流、UA、robots.txt） |
| `guokao_scraper.py` | 国考数据爬取（eoffcn + gwy.com + 历史内置 + NFRA Excel 框架） |
| `shengkao_scraper.py` | 省考数据爬取（江苏 qihejy.com Excel + 山东文章页框架） |
| `huatu_api_scraper.py` | **新增** 华图 API 爬虫（主力数据源，逆向 apis.huatu.com） |
| `huatu_echarts_scraper.py` | **新增** 华图 2024 省级汇总（来自 2025skfscx 静态页面） |
| `shiyebian_scraper.py` | 事业编爬取（当前无可用来源，保留框架） |
| `data_cleaner.py` | 数据清洗和标准化 |
| `export_json.py` | 导出为 app asset 格式（支持增量合并，集成所有爬虫） |
| `requirements.txt` | Python 依赖 |
| `discover_api*.py` | 华图 API 逆向探测脚本（一次性使用） |

## 数据更新流程

1. 运行爬取脚本获取最新数据（会自动合并旧文件引用）
2. 检查输出 JSON 文件质量
3. 确认 `pubspec.yaml` 中已注册 asset 目录
4. 运行 Flutter 应用验证数据加载

## 华图 API 数据时效性

华图 API 数据随年份变化：
- 每年省考后（约 4-5 月），华图会更新 `z/xxxx skfscx/` 页面
- 下一年数据发布后，可重新运行 `python export_json.py --type huatu_api` 获取新数据
- 年份参数：`TARGET_YEARS` 列表中添加新年份即可
