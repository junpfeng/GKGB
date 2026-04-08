# 进面分数线数据爬取工具

开发阶段使用的 Python 爬取工具，用于从公开数据源采集国考/省考/事业编进面分数线数据，清洗后导出为 app 的 JSON asset 文件。

**注意：此工具仅在开发阶段使用，不打包进 Flutter 应用。**

## 环境准备

```bash
cd tools/exam_score_scraper
pip install -r requirements.txt
```

需要 Python 3.10+。

## 数据源

| 考试类型 | 数据源 | 格式 |
|---------|--------|------|
| 国考 | 上岸鸭 (gwy.com) 历年汇总 | HTML 表格 |
| 省考 | 华图教育各省站 (xx.huatu.com) | HTML 表格 / Excel |
| 省考(山东) | 华图山东站 Excel 下载 | .xlsx |
| 事业编 | 华图事业编频道 + 各省人社厅 | HTML / Excel |

所有爬取严格遵守：
- robots.txt 协议检查
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
# 仅爬取山东 2024 省考
python export_json.py --province 山东 --year 2024 --type shengkao

# 仅爬取国考
python export_json.py --type guokao

# 仅爬取事业编
python export_json.py --type shiyebian --province 江苏
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
├── index.json                          # 文件索引
├── guokao_2024.json                    # 国考按年份
├── guokao_2025.json
├── jiangsu_shengkao_2024.json          # 省考按省份+年份
├── shandong_shengkao_2024.json
├── jiangsu_shiyebian_2024.json         # 事业编按省份+年份
└── ...
```

### JSON 数据格式

每个数据文件是一个数组，每条记录包含：

```json
{
  "province": "江苏",
  "city": "南京",
  "year": 2024,
  "exam_type": "省考",
  "department": "南京市鼓楼区人民政府办公室",
  "position_name": "综合管理岗",
  "position_code": "JS2024001",
  "recruit_count": 1,
  "education_req": "本科及以上",
  "degree_req": "学士及以上",
  "major_req": "中文、新闻学",
  "political_req": "中共党员",
  "work_exp_req": "二年以上基层工作经历",
  "other_req": null,
  "min_entry_score": 145.6,
  "max_entry_score": 158.3,
  "entry_count": 3,
  "source_url": "https://js.huatu.com/..."
}
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `scraper_base.py` | 爬虫基类（节流、UA、robots.txt） |
| `guokao_scraper.py` | 国考数据爬取 |
| `shengkao_scraper.py` | 省考数据爬取（含 Excel 解析） |
| `shiyebian_scraper.py` | 事业编数据爬取 |
| `data_cleaner.py` | 数据清洗和标准化 |
| `export_json.py` | 导出为 app asset 格式 |
| `requirements.txt` | Python 依赖 |

## 数据更新流程

1. 运行爬取脚本获取最新数据
2. 检查输出 JSON 文件质量
3. 更新 `index.json` 中的 version 和 updated_at
4. 确认 `pubspec.yaml` 中已注册 asset 目录
5. 运行 Flutter 应用验证数据加载
