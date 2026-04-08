# 真题爬虫工具链

## 概述

Python 爬虫工具，从 4 个数据源抓取 2020-2025 年国考/省考/事业编真题，
标准化后输出 JSON 文件到 `assets/questions/real_exam/`。

## 目录结构

```
tools/scraper/
├── requirements.txt        # Python 依赖
├── config.py               # 配置（URL、间隔、覆盖范围）
├── base_scraper.py         # 爬虫基类（限速/robots/重试）
├── fenbi_scraper.py        # 粉笔网爬虫
├── qzzn_scraper.py         # QZZN 论坛爬虫
├── gov_scraper.py          # 各省人事考试网爬虫
├── xiaohongshu_scraper.py  # 小红书爬虫（默认关闭）
├── normalizer.py           # 数据标准化
├── dedup.py                # MD5 内容去重
├── main.py                 # 主入口（调度 + 输出）
└── README.md               # 本文档
```

## 快速开始

```bash
# 1. 安装依赖（推荐 Python 3.10+）
pip install -r requirements.txt

# 2. 运行全部爬虫
python main.py

# 3. 运行指定数据源
python main.py --source fenbi --fenbi-cookie "your_cookie_here"
python main.py --source gov --province jiangsu
python main.py --source qzzn

# 4. 仅标准化已有原始数据
python main.py --normalize-only --input raw_data.json
```

## 合规说明

- 遵守各网站 `robots.txt` 协议
- 请求间隔 ≥ 2 秒（配置在 `config.py` 中）
- 携带明确 User-Agent 标识（含项目信息）
- 抓取数据仅用于本地离线使用，不二次分发

## 待实现（TODO）

各爬虫已搭建完整框架，具体页面解析逻辑需在实际调研目标网站后补全：

### 粉笔网（`fenbi_scraper.py`）
- [ ] 确认 API 端点和参数格式
- [ ] 配置有效登录 Cookie（`--fenbi-cookie` 参数）
- [ ] 调整字段映射（`_parse_question` 方法）

### QZZN 论坛（`qzzn_scraper.py`）
- [ ] 确认版块 URL 路径
- [ ] 调整帖子列表 HTML 选择器
- [ ] 补全正则表达式提取逻辑

### 省级人事考试网（`gov_scraper.py`）
- [ ] 逐省确认网站域名和页面结构
- [ ] 处理 PDF/Word 格式真题（需 pdfminer/python-docx）
- [ ] 关联答案文件（部分省份分开发布）

### 小红书（`xiaohongshu_scraper.py`）
- [ ] 配置登录 Cookie 和签名验证
- [ ] 接入 OCR 服务（推荐 paddleocr）
- [ ] 图片质量过滤

## 输出格式

```json
{
  "paper": {
    "name": "2024年全国国考行测真题",
    "region": "全国",
    "year": 2024,
    "exam_type": "国考",
    "subject": "行测",
    "time_limit": 7200,
    "total_score": 100
  },
  "questions": [
    {
      "subject": "行测",
      "category": "言语理解",
      "type": "single",
      "content": "题目内容...",
      "options": ["A. xxx", "B. xxx", "C. xxx", "D. xxx"],
      "answer": "A",
      "explanation": "详细解析...",
      "difficulty": 2,
      "region": "全国",
      "year": 2024,
      "exam_type": "国考",
      "exam_session": "",
      "is_real_exam": 1
    }
  ]
}
```

## 输出目录

```
assets/questions/real_exam/
├── guokao/             # 国考
│   └── 全国_2024_行测.json
├── shengkao/           # 省考
│   ├── 江苏_2024_行测.json
│   └── 浙江_2023_申论.json
└── shiyebian/          # 事业编
    └── 全国_2024_公基.json
```
