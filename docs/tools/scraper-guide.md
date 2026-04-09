# 真题爬虫工具链 — 使用说明

> 本文档是 `tools/scraper/` Python 爬虫工具链和 `tools/collect_idioms.dart` 成语采集工具的完整使用手册。

---

## 目录

- [1. 概述](#1-概述)
- [2. 环境准备](#2-环境准备)
- [3. 快速开始](#3-快速开始)
- [4. 命令行参数详解](#4-命令行参数详解)
- [5. 各爬虫详细说明](#5-各爬虫详细说明)
  - [5.1 粉笔网爬虫 (fenbi_scraper.py)](#51-粉笔网爬虫)
  - [5.2 QZZN 论坛爬虫 (qzzn_scraper.py)](#52-qzzn-论坛爬虫)
  - [5.3 省级人事考试网爬虫 (gov_scraper.py)](#53-省级人事考试网爬虫)
  - [5.4 小红书爬虫 (xiaohongshu_scraper.py)](#54-小红书爬虫)
- [6. 数据处理管线](#6-数据处理管线)
  - [6.1 标准化 (normalizer.py)](#61-标准化)
  - [6.2 去重 (dedup.py)](#62-去重)
- [7. 输出格式与目录结构](#7-输出格式与目录结构)
- [8. 配置文件详解 (config.py)](#8-配置文件详解)
- [9. 成语采集工具 (collect_idioms.dart)](#9-成语采集工具)
- [10. Flutter 端数据导入](#10-flutter-端数据导入)
- [11. 合规与安全](#11-合规与安全)
- [12. 故障排查](#12-故障排查)
- [13. 扩展指南](#13-扩展指南)

---

## 1. 概述

本工具链用于从 4 个数据源抓取 2020–2025 年公务员/事业编考试真题，经标准化、去重后输出为 JSON 文件，供 Flutter 应用离线使用。

**数据流总览：**

```
数据源（粉笔/QZZN/官网/小红书）
        ↓ 各 Scraper.scrape()
    原始题目 list[dict]
        ↓ normalizer.normalize_batch()
    标准化题目 list[dict]
        ↓ dedup.dedup()
    去重题目 list[dict]
        ↓ main.save_all_groups()
    assets/questions/real_exam/{guokao,shengkao,shiyebian}/*.json
        ↓ Flutter real_exam_service.dart
    SQLite 本地数据库
```

**工具清单：**

| 文件 | 语言 | 作用 |
|------|------|------|
| `tools/scraper/main.py` | Python | 主入口，调度爬取→标准化→去重→输出 |
| `tools/scraper/config.py` | Python | 全局配置（URL、间隔、覆盖范围、输出路径） |
| `tools/scraper/base_scraper.py` | Python | 爬虫基类（限速、robots.txt、重试） |
| `tools/scraper/fenbi_scraper.py` | Python | 粉笔网 API 爬虫（主力源） |
| `tools/scraper/qzzn_scraper.py` | Python | QZZN 论坛 HTML 爬虫 |
| `tools/scraper/gov_scraper.py` | Python | 省级人事考试网 HTML 爬虫 |
| `tools/scraper/xiaohongshu_scraper.py` | Python | 小红书图片+OCR 爬虫（默认关闭） |
| `tools/scraper/normalizer.py` | Python | 字段标准化（科目/分类/题型映射） |
| `tools/scraper/dedup.py` | Python | MD5 内容哈希去重 |
| `tools/collect_idioms.dart` | Dart | 成语释义+例句采集 |

---

## 2. 环境准备

### 2.1 Python 爬虫环境

**前置条件：** Python 3.10+

```bash
# 进入爬虫目录
cd tools/scraper

# 安装依赖
pip install -r requirements.txt
```

**依赖说明：**

| 包 | 版本要求 | 用途 |
|----|----------|------|
| `requests` | ≥2.31.0 | HTTP 请求，含连接池和重试 |
| `beautifulsoup4` | ≥4.12.0 | HTML 页面解析 |
| `lxml` | ≥4.9.0 | bs4 的高性能 HTML 解析后端 |
| `selenium` | ≥4.15.0 | 浏览器自动化（JS 重型页面） |
| `fake-useragent` | ≥1.4.0 | User-Agent 轮换（备用） |
| `urllib3` | ≥2.0.0 | 底层 HTTP 库 |

### 2.2 Dart 成语采集环境

**前置条件：** Flutter 3.x / Dart 3.x，项目依赖已安装（`flutter pub get`）

依赖 `pubspec.yaml` 中已有的 `dio` 和 `html` 包，无需额外安装。

---

## 3. 快速开始

### 运行 Python 爬虫

```bash
cd tools/scraper

# 运行全部爬虫（首次可能返回空数据，因各爬虫 TODO 待补全）
python main.py

# 仅运行粉笔网（需要 Cookie）
python main.py --source fenbi --fenbi-cookie "你的Cookie"

# 仅运行 QZZN
python main.py --source qzzn

# 仅运行某省官网
python main.py --source gov --province jiangsu

# 标准化已有原始数据（不爬取）
python main.py --normalize-only --input /path/to/raw_data.json
```

### 运行 Dart 成语采集

```bash
# 在项目根目录执行
dart run tools/collect_idioms.dart
```

---

## 4. 命令行参数详解

### `main.py` 参数

| 参数 | 值 | 默认 | 说明 |
|------|----|------|------|
| `--source` | `all` / `fenbi` / `qzzn` / `gov` / `xiaohongshu` | `all` | 指定运行哪个数据源 |
| `--province` | 省份英文 key | — | 仅 `--source gov` 时有效，限定单省爬取 |
| `--fenbi-cookie` | Cookie 字符串 | 环境变量 `FENBI_COOKIE` | 粉笔网登录态 |
| `--xhs-cookie` | Cookie 字符串 | — | 小红书登录态 |
| `--normalize-only` | 无需值（flag） | — | 跳过爬取，仅对已有数据标准化+去重 |
| `--input` | 文件路径 | — | 与 `--normalize-only` 配合，指定原始 JSON |

**省份 key 对照：**

| Key | 省份 | 配置网址 |
|-----|------|----------|
| `jiangsu` | 江苏 | jszk.com.cn (待确认) |
| `zhejiang` | 浙江 | zjrsks.com (待确认) |
| `shanghai` | 上海 | rsj.sh.gov.cn (待确认) |
| `shandong` | 山东 | sdzk.cn (待确认) |

---

## 5. 各爬虫详细说明

### 5.1 粉笔网爬虫

**文件：** `fenbi_scraper.py`
**数据源：** tiku.fenbi.com — 国内最大公考题库平台，题量大、解析详细
**状态：** 框架完整，API 端点和解析逻辑已实现，需配置有效 Cookie 测试

#### 前置准备

1. **获取 Cookie：** 在浏览器中登录 fenbi.com → F12 → Network → 复制请求头中的 `Cookie` 值
2. **传入方式（二选一）：**
   - 命令行参数：`--fenbi-cookie "your_cookie_value"`
   - 环境变量：`export FENBI_COOKIE="your_cookie_value"`

#### API 调用链路

```
Step 1: GET /api/xingce/subLabels
        → 获取省份/地区列表（含 labelId）
        → 筛选 TARGET_LABELS: {国考, 江苏, 浙江, 上海, 山东}

Step 2: GET /api/xingce/papers/?labelId={id}&pageSize=50
        → 每个地区的试卷列表
        → 筛选 TARGET_YEARS (2020–2025)

Step 3: POST /api/xingce/exercises (paperId={id})
        → 创建答题会话，获取 exerciseId
        → 若已存在则复用

Step 4: GET /api/xingce/exercises/{exerciseId}
        → 获取 questionIds 列表 + chapters 分章信息

Step 5: GET /api/xingce/solutions?ids={id1},{id2},...
        → 批量获取题目详情（每批 20 题）
        → 含：题干(HTML)、选项、答案索引、解析、难度、材料
```

#### 数据字段映射

| 粉笔原始字段 | 标准字段 | 转换逻辑 |
|-------------|---------|---------|
| `content` (HTML) | `content` | 去 HTML 标签，保留公式 alt 文本 |
| `accessories[0].options[]` (HTML) | `options` | 去标签，加 `A./B./C./D.` 前缀 |
| `correctAnswer.choice` ("0,2") | `answer` | 索引转字母："0"→"A"，"0,2"→"AC" |
| `solution` (HTML) | `explanation` | 去 HTML 标签 |
| `difficulty` (float) | `difficulty` | 四舍五入，clamp 到 1–5 |
| `material.content` (HTML) | 拼入 `content` | `【材料】...【题目】...` 格式 |
| chapters 顺序映射 | `category` | 章节名→标准分类名 |

#### 覆盖范围

- **考试类型：** 国考（副省级/地市级/行政执法）、省考（A/B/C 类）
- **科目：** 行测（默认 prefix=xingce），可扩展 shenlun、gonggong
- **年份：** 2020–2025
- **地区：** 全国、江苏、浙江、上海、山东

#### 使用示例

```bash
# 爬取全部目标地区的行测真题
python main.py --source fenbi --fenbi-cookie "session=abc123; ..."

# 仅爬取（直接使用类）
python -c "
from fenbi_scraper import FenbiScraper
scraper = FenbiScraper(cookie='your_cookie', prefix='xingce')
results = scraper.scrape()
print(f'共 {len(results)} 题')
"
```

---

### 5.2 QZZN 论坛爬虫

**文件：** `qzzn_scraper.py`
**数据源：** bbs.qzzn.com — 公考社区论坛，用户整理发布的真题回忆版
**状态：** 框架搭建完成，HTML 选择器和帖子解析逻辑需实际调研后补全

#### 工作原理

```
1. 遍历版块帖子列表（国考/省考专区）
2. 按标题关键词筛选真题帖子（年份 + "真题/行测/申论"等）
3. 进入帖子详情页，提取正文文本
4. 正则解析题目结构：题号→题干→ABCD选项→答案→解析
5. 关键词启发式自动分类
```

#### 题目识别正则

爬虫使用以下正则从论坛纯文本中提取标准题目格式：

```
{序号}. {题目内容}
A. {选项A}  B. {选项B}  C. {选项C}  D. {选项D}
【答案】{ABCD}
【解析】{解析内容}（可选）
```

#### 自动分类规则

| 关键词 | 分类 |
|--------|------|
| 数据、图表、增长率、比重 | 资料分析 |
| 逻辑、推理、假设、削弱、加强 | 判断推理 |
| 工程、行程、概率、排列、组合、利润 | 数量关系 |
| 法律、常识、政治、历史、地理、科技 | 常识判断 |
| 其他 | 言语理解（默认） |

#### 待完成项

- [ ] 确认 QZZN 论坛版块实际 URL 路径
- [ ] 调整帖子列表页的 HTML 选择器（CSS Selector）
- [ ] 调整帖子详情页的正文提取选择器
- [ ] 测试正则对实际帖子格式的覆盖率

---

### 5.3 省级人事考试网爬虫

**文件：** `gov_scraper.py`
**数据源：** 各省人事考试网官方站点
**状态：** 通用框架完成，各省页面解析需逐省适配

#### 已配置省份

| 省份 | URL (待确认) | 状态 |
|------|-------------|------|
| 江苏 | jszk.com.cn | 框架就绪，需确认域名和页面结构 |
| 浙江 | zjrsks.com | 同上 |
| 上海 | rsj.sh.gov.cn | 同上 |
| 山东 | sdzk.cn | 同上 |

#### 通用爬取策略

```
1. 访问省级网站首页
2. 遍历所有 <a> 链接，按关键词筛选真题页面
   关键词：真题、试题、行测、申论、笔试、历年
3. 从链接文本/URL 中提取年份（正则匹配 202X）
4. 从标题猜测科目（行测/申论/公基）
5. 解析 HTML 页面提取题目，或下载 PDF/Word 文件
```

#### 特殊挑战

- **格式多样：** 部分省份以 PDF/Word 格式发布，需引入 `pdfminer` / `python-docx`
- **答案分离：** 部分省份题目和答案分别发布在不同页面
- **结构差异：** 每个省网站 HTML 结构完全不同，需逐一编写选择器

#### 使用示例

```bash
# 爬取全部配置省份
python main.py --source gov

# 仅爬取江苏
python main.py --source gov --province jiangsu
```

#### 扩展新省份

在 `config.py` 的 `GOV_EXAM_CONFIG["sites"]` 中添加：

```python
"guangdong": {
    "name": "广东",
    "url": "http://www.gdrsks.gov.cn",
    "enabled": True,
},
```

然后在 `gov_scraper.py` 中为该省编写页面解析逻辑。

---

### 5.4 小红书爬虫

**文件：** `xiaohongshu_scraper.py`
**数据源：** xiaohongshu.com — 社交平台，用户发布的真题回忆版（图片为主）
**状态：** 框架搭建完成，**默认关闭**，需手动启用

#### 为什么默认关闭？

1. **强制登录：** 搜索和查看笔记需要有效的 Cookie
2. **图片为主：** 真题以图片形式发布，需 OCR 识别
3. **签名验证：** API 请求需要 X-Sign 签名（需逆向分析）
4. **反爬严格：** 有较强的反爬机制
5. **质量不稳定：** 用户回忆版内容准确性参差不齐

#### 启用方法

**Step 1：修改配置**

编辑 `config.py`，将小红书的 `enabled` 改为 `True`：

```python
XIAOHONGSHU_CONFIG = {
    "base_url": "https://www.xiaohongshu.com",
    "search_keywords": ["国考真题", "省考真题", "行测真题回忆"],
    "enabled": True,  # ← 改为 True
}
```

**Step 2：获取 Cookie**

浏览器登录小红书 → F12 → Network → 复制 Cookie

**Step 3：配置 OCR 服务**

推荐方案：
- **本地 OCR：** PaddleOCR（免费、离线、中文识别好）
- **云 OCR：** 百度云/阿里云 OCR API（付费、更准确）

**Step 4：运行**

```bash
python main.py --source xiaohongshu --xhs-cookie "your_cookie_here"
```

#### OCR 文本识别的宽松正则

由于 OCR 输出可能含有错字、不规则换行，爬虫使用了宽松的正则：
- 选项前缀兼容全角/半角：`A/a/Ａ`
- 题目内容最少 10 字（过滤噪音）
- 选项长度限制 2–50 字
- 所有 OCR 来源数据标记 `source: "xiaohongshu_ocr"`，便于后续质量审核

---

## 6. 数据处理管线

### 6.1 标准化

**文件：** `normalizer.py`

所有爬虫的原始输出经过统一标准化，确保字段格式一致。

#### 处理流程

```python
normalize(raw_dict)  →  标准化 dict 或 None（验证失败时跳过）
normalize_batch(list) →  批量处理，返回有效列表 + 跳过计数
```

#### 字段校验规则

| 字段 | 校验/转换 | 示例 |
|------|----------|------|
| `content` | 去 HTML 标签，去多余空白，最少 5 字 | — |
| `subject` | 同义词映射（如 "行政职业能力测验"→"行测"） | 无效科目则跳过 |
| `category` | 别名映射（如 "言语"→"言语理解"） | 空则用 subject |
| `type` | 映射到 `single/multiple/judge/subjective` | "单选题"→"single" |
| `options` | 统一为 `["A. xxx", "B. xxx", ...]`，最多 5 个 | 客观题至少 2 个选项 |
| `answer` | 大写，仅保留 A–E 字母 | "ac" → "AC" |
| `explanation` | 去 HTML 标签 | — |
| `difficulty` | 整数 1–5，默认 2 | 7 → 5, -1 → 1 |
| `year` | 整数 2000–2030 范围 | 超范围则置 0 |
| `exam_type` | 映射到 "国考/省考/事业编/选调" | — |
| `region` | 映射地区名（"国考"→"全国"） | — |

#### 科目映射表

```
行政职业能力测验  →  行测
行政能力测验      →  行测
公共基础知识      →  公基
公共基础          →  公基
```

#### 分类映射表（行测子分类）

```
言语 / 言语理解与表达       →  言语理解
数量                       →  数量关系
逻辑 / 图形推理 / 定义判断   →  判断推理
  / 类比推理 / 逻辑判断
资料                       →  资料分析
常识 / 政治 / 法律 / 经济   →  常识判断
```

### 6.2 去重

**文件：** `dedup.py`

基于内容 MD5 哈希的去重机制，确保同一题不会从多个数据源重复入库。

#### 哈希计算方法

```
1. 取题目 content + 所有选项文字（去掉 A./B. 前缀）
2. 对每段文字做归一化：
   - 去除所有空白字符
   - 去除中英文标点（，。？！、；：""''【】《》()[] 等）
   - 转小写
3. 用 | 分隔拼接
4. 计算 MD5
```

#### 去重策略

- **优先保留解析完整的版本：** 若新版本有 `explanation` 而旧版本没有，替换
- **同等情况先到先得：** 首次出现的版本保留

#### 两种去重模式

```python
# 模式 1：批次内去重（爬虫运行时使用）
deduped = dedup(questions)

# 模式 2：增量去重（Flutter 导入时使用）
new_only = dedup_against_existing(new_questions, existing_hash_set)
```

---

## 7. 输出格式与目录结构

### 输出目录

```
assets/questions/real_exam/
├── index.json              ← 文件清单（Flutter 端读取入口）
├── guokao/                 ← 国考
│   ├── 全国_2020_行测.json
│   ├── 全国_2021_行测.json
│   ├── ...
│   └── 全国_2025_申论.json
├── shengkao/               ← 省考
│   ├── 江苏_2024_行测.json
│   ├── 浙江_2023_申论.json
│   ├── 上海_2025_行测.json
│   └── 山东_2024_行测.json
└── shiyebian/              ← 事业编
    ├── 全国_2022_公基.json
    └── 全国_2024_公基.json
```

**文件命名规范：** `{地区}_{年份}_{科目}.json`

### 单个 JSON 文件结构

```json
{
  "paper": {
    "name": "2024年全国国考行测真题",
    "region": "全国",
    "year": 2024,
    "exam_type": "国考",
    "exam_session": "副省级",
    "subject": "行测",
    "time_limit": 7200,
    "total_score": 100,
    "question_ids": []
  },
  "questions": [
    {
      "subject": "行测",
      "category": "言语理解",
      "type": "single",
      "content": "下列各句中，没有语病的一句是：",
      "options": [
        "A. 选项一内容",
        "B. 选项二内容",
        "C. 选项三内容",
        "D. 选项四内容"
      ],
      "answer": "B",
      "explanation": "本题考查病句辨析。A项主语残缺...",
      "difficulty": 2,
      "region": "全国",
      "year": 2024,
      "exam_type": "国考",
      "exam_session": "副省级",
      "is_real_exam": 1
    }
  ],
  "generated_at": "2026-04-08T10:30:00.000000",
  "source": "scraped",
  "total": 135
}
```

### 字段说明

**paper（试卷元数据）：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 试卷名称，格式 "{年份}年{地区/考试类型}{科目}真题" |
| `region` | string | 地区：全国、江苏、浙江、上海、山东 |
| `year` | int | 年份：2020–2025 |
| `exam_type` | string | 国考 / 省考 / 事业编 / 选调 |
| `exam_session` | string | 卷别：副省级 / 地市级 / 行政执法 / A类 / B类 / C类 |
| `subject` | string | 行测 / 申论 / 公基 / 职业能力倾向测验 / 综合应用能力 |
| `time_limit` | int | 考试时长（秒），行测默认 7200，申论默认 10800 |
| `total_score` | float | 总分，默认 100 |
| `question_ids` | list | Flutter 导入后填充的数据库 ID 列表 |

**questions（题目列表）：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `subject` | string | 是 | 科目 |
| `category` | string | 是 | 行测子分类：言语理解/数量关系/判断推理/资料分析/常识判断 |
| `type` | string | 是 | 题型：single / multiple / judge / subjective |
| `content` | string | 是 | 题目内容（纯文本，≥5 字） |
| `options` | list[string] | 是* | 选项，格式 "A. xxx"。客观题至少 2 个 |
| `answer` | string | 是 | 答案字母：单选 "A"，多选 "AC" |
| `explanation` | string | 否 | 解析说明 |
| `difficulty` | int | 否 | 难度 1–5，默认 2 |
| `region` | string | 否 | 地区 |
| `year` | int | 否 | 年份 |
| `exam_type` | string | 否 | 考试类型 |
| `exam_session` | string | 否 | 卷别 |
| `is_real_exam` | int | 是 | 固定为 1（真题标记） |

---

## 8. 配置文件详解

**文件：** `config.py`

### 请求配置

```python
REQUEST_DELAY_MIN = 2.0   # 最小请求间隔（秒）— 合规要求 ≥2s
REQUEST_DELAY_MAX = 5.0   # 最大请求间隔（秒，随机抖动防检测）
REQUEST_TIMEOUT = 30      # 单次请求超时（秒）
MAX_RETRIES = 3           # 最大重试次数
RETRY_DELAY = 10          # 重试基础等待（秒，实际按指数退避）
```

### User-Agent

```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) ... ExamPrepBot/1.0 (educational-use; contact@example.com)
```

标识为教育用途爬虫，包含联系方式（建议替换为真实邮箱）。

### 目标覆盖范围

```python
TARGET_YEARS = [2020, 2021, 2022, 2023, 2024, 2025]
```

**国考科目配置：**

| 卷别 | 行测题量 | 行测时限 | 申论题量 | 申论时限 |
|------|---------|---------|---------|---------|
| 副省级 | 135 题 | 120 分钟 | 5 题 | 180 分钟 |
| 地市级 | 130 题 | 120 分钟 | 5 题 | 180 分钟 |

**省考/事业编配置：** 类似结构，详见 `config.py` 中的 `SHENGKAO_SUBJECTS` 和 `SHIYEBIAN_SUBJECTS`。

### 输出路径

自动定位到项目根目录下的 `assets/questions/real_exam/`，无需手动配置。

### 日志

- **级别：** INFO（可在 `config.py` 中改为 DEBUG 查看详细信息）
- **文件：** `tools/scraper/scraper.log`
- **同时输出到控制台**

---

## 9. 成语采集工具

**文件：** `tools/collect_idioms.dart`
**输出：** `assets/data/idioms_preset.json`

### 功能

从题库中选词填空题的选项里提取四字成语，然后爬取每个成语的百度汉语释义和人民日报例句。

### 工作流程

```
1. 扫描 assets/questions/ 下所有 JSON 文件
2. 筛选分类为"言语理解/言语运用"且内容含"___"的选词填空题
3. 从选项中正则提取四字汉字成语（^[\u4e00-\u9fff]{4}$）
4. 加载已有 idioms_preset.json（增量更新，跳过已采集的）
5. 对每个新成语：
   a. 爬取百度汉语释义（hanyu.baidu.com）
   b. 爬取人民日报 2020–2025 例句（search.people.com.cn）
6. 按拼音排序，写入 JSON
```

### 输出格式

```json
[
  {
    "text": "一毛不拔",
    "definition": "形容非常吝啬。出自《孟子·尽心上》。",
    "examples": [
      {
        "sentence": "...一毛不拔的铁公鸡...",
        "year": 2024,
        "source_url": "http://search.people.com.cn/..."
      }
    ]
  }
]
```

### 使用说明

```bash
# 在项目根目录运行
dart run tools/collect_idioms.dart
```

**注意事项：**
- 需联网访问百度汉语和人民日报搜索
- 请求间隔 ≥2s（内置限速）
- 支持增量更新，已有的成语自动跳过
- 每个成语最多保留 5 条例句（按年份降序）

---

## 10. Flutter 端数据导入

爬虫输出的 JSON 文件通过 Flutter 端的 `real_exam_service.dart` 自动导入。

### 导入流程

```
1. App 首次启动 → ensureSampleData()
2. 读取 assets/questions/real_exam/index.json（清单文件）
3. 遍历清单中的每个 JSON 文件
4. 对每道题计算内容哈希（与 Python 端 dedup.py 算法一致）
5. 与数据库已有哈希比对，跳过重复
6. 插入新题到 SQLite questions 表
7. 创建/更新 real_exam_papers 表的试卷记录
```

### 保持一致性

Python 端 `dedup.py` 和 Dart 端 `real_exam_service.dart` 使用相同的内容哈希算法，确保：
- 爬虫批次间不重复
- App 多次导入不重复
- 跨数据源去重

---

## 11. 合规与安全

### robots.txt 合规

- 每次请求前自动检查目标 URL 是否被 `robots.txt` 允许
- 被禁止的 URL 自动跳过并记录日志
- robots.txt 加载失败时保守处理（允许访问）

### 请求限速

- 每次请求间隔 **2–5 秒**（随机抖动）
- 429 (Too Many Requests) 自动指数退避重试
- User-Agent 明确标识为教育用途爬虫

### 数据使用

- 抓取数据**仅用于本地离线使用**
- 打包进 APK/IPA，不做网络分发
- 禁止二次分发或商业使用

### Cookie 安全

- Cookie 通过命令行参数或环境变量传入，**不硬编码在代码中**
- 日志中不输出 Cookie 值

---

## 12. 故障排查

### 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 爬虫运行但无数据返回 | 各爬虫 `scrape()` 中的 TODO 未实现 | 查看具体 scraper 的 TODO 注释，补全解析逻辑 |
| `robots.txt 拒绝` 日志 | 目标 URL 被 robots.txt 禁止 | 确认爬取路径是否被允许，必要时调整 |
| `HTTP 429` | 请求频率过高被限制 | 自动退避重试；可增大 `REQUEST_DELAY_MIN` |
| `Cookie 过期` | 登录态失效 | 重新在浏览器登录，获取新 Cookie |
| `lxml not found` | 依赖未安装 | `pip install -r requirements.txt` |
| `ModuleNotFoundError` | 未在正确目录运行 | 确保 `cd tools/scraper` 后再运行 |
| Dart 成语采集报网络错误 | 百度汉语/人民日报不可达 | 检查网络，确认目标站点可访问 |

### 查看日志

```bash
# 实时查看日志
tail -f tools/scraper/scraper.log

# 搜索错误
grep ERROR tools/scraper/scraper.log
```

---

## 13. 扩展指南

### 添加新数据源

1. **创建爬虫文件** `tools/scraper/new_source_scraper.py`
2. **继承 `BaseScraper`，实现 `scrape()` 方法：**

```python
from base_scraper import BaseScraper

class NewSourceScraper(BaseScraper):
    def __init__(self):
        super().__init__("NewSource", "https://example.com")

    def scrape(self) -> list[dict]:
        results = []
        # 使用 self.get(url) / self.post(url) 发请求
        # 自动带限速、robots 检查、重试
        resp = self.get("https://example.com/questions")
        if resp:
            # 解析并返回标准格式 dict 列表
            pass
        return results
```

3. **在 `main.py` 中注册：**

```python
def run_new_source() -> list[dict]:
    from new_source_scraper import NewSourceScraper
    scraper = NewSourceScraper()
    return scraper.scrape()
```

4. **在 `config.py` 中添加配置**
5. **输出 dict 包含标准字段即可，normalizer 会处理映射**

### 添加新省份

编辑 `config.py` 中的 `GOV_EXAM_CONFIG["sites"]` 和 `SHENGKAO_SUBJECTS`，然后在 `gov_scraper.py` 中为该省网站编写 HTML 选择器。

### 调整覆盖年份

修改 `config.py` 中的 `TARGET_YEARS`：

```python
TARGET_YEARS = list(range(2018, 2027))  # 扩展到 2018–2026
```
