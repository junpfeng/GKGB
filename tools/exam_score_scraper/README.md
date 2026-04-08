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
| chinagwy.org Excel | `http://www.chinagwy.org/files/...xlsx` | 禁止 | robots.txt 禁止 `/files/` 路径 |

### 省考 (shengkao_scraper.py)

| 省份 | 来源 | 状态 | 说明 |
|------|------|------|------|
| 江苏 | qihejy.com + download.qihejy.com | **可用** | 各地市进面名单 Excel，按职位聚合得出分数线 (2024，8个地市) |
| 山东 | sd.huatu.com 文章页 | 部分可用 | HTML 访问允许，但 Excel 下载指向 u3.huatu.com（robots.txt 禁止），无 HTML 表格可解析 |
| 浙江 | — | 待补充 | 暂无已验证的可用结构化来源 |
| 上海 | — | 待补充 | 暂无已验证的可用结构化来源 |

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

### 全量爬取并导出

```bash
python export_json.py
```

### 指定省份/年份/类型

```bash
# 仅爬取江苏 2024 省考
python export_json.py --province 江苏 --year 2024 --type shengkao

# 仅爬取国考
python export_json.py --type guokao

# 仅爬取 2024 年国考
python export_json.py --type guokao --year 2024
```

### 单独运行某个爬虫

```bash
python guokao_scraper.py
python shengkao_scraper.py
python shiyebian_scraper.py
```

## 输出

导出文件位于 `assets/data/exam_entry_scores/`：

```
assets/data/exam_entry_scores/
├── index.json                          # 文件索引（合并新旧数据）
├── guokao_2023.json                    # 国考2023（gwy.com，4条，4省）
├── guokao_2024.json                    # 国考2024（eoffcn.com，37条）
├── guokao_2025.json                    # 国考2025（示例数据，待更新）
├── jiangsu_shengkao_2024.json          # 江苏省考2024（真实数据，2151条，8地市）
├── jiangsu_shengkao_2025.json          # 江苏省考2025（示例数据）
├── jiangsu_shiyebian_2024.json         # 江苏事业编2024（示例数据）
├── shandong_shengkao_2024.json         # 山东省考2024（示例数据，待更新）
├── shandong_shengkao_2025.json         # 山东省考2025（示例数据）
├── shandong_shiyebian_2024.json        # 山东事业编2024（示例数据）
├── shanghai_shengkao_2024.json         # 上海省考2024（示例数据）
├── zhejiang_shengkao_2024.json         # 浙江省考2024（示例数据）
├── zhejiang_shengkao_2025.json         # 浙江省考2025（示例数据）
└── zhejiang_shiyebian_2024.json        # 浙江事业编2024（示例数据）
```

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

### 江苏省考数据（真实数据）

来源为 `qihejy.com` 汇总的各地市进面名单 Excel，包含进面人员的行测/申论/总分。
爬虫按 `[单位名称, 职位名称]` 分组统计，取总分的 min/max 作为该职位的进面分数线。

覆盖地市：南通、扬州、泰州、镇江、徐州、淮安、宿迁、连云港（2024年，共2151条职位）

### 国考数据（真实数据）

- 2024年：eoffcn.com 按地区/部门/TOP50 汇总，共 37 条（江苏/浙江/上海/山东 4 省）
- 2023年：gwy.com 历史数据，共 4 条省级汇总

## 文件说明

| 文件 | 说明 |
|------|------|
| `scraper_base.py` | 爬虫基类（节流、UA、robots.txt） |
| `guokao_scraper.py` | 国考数据爬取（eoffcn + gwy.com） |
| `shengkao_scraper.py` | 省考数据爬取（江苏 qihejy.com Excel） |
| `shiyebian_scraper.py` | 事业编爬取（当前无可用来源，保留框架） |
| `data_cleaner.py` | 数据清洗和标准化 |
| `export_json.py` | 导出为 app asset 格式（支持增量合并） |
| `requirements.txt` | Python 依赖 |

## 数据更新流程

1. 运行爬取脚本获取最新数据（会自动合并旧文件引用）
2. 检查输出 JSON 文件质量
3. 确认 `pubspec.yaml` 中已注册 asset 目录
4. 运行 Flutter 应用验证数据加载
