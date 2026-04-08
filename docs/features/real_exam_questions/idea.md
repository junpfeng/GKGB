# 真题题库（2020-2025）

## 核心需求
科目练习板块中，需要从2020年至2025年间所有的真题和解析。

## 调研上下文

### 已有基础设施
- **Question 模型**已支持真题字段：`region`、`year`、`examType`、`examSession`、`isRealExam`
- **RealExamPaper 模型**已支持试卷模板：`name`、`region`、`year`、`examType`、`subject`、`questionIds`
- **数据库表**`questions` 和 `real_exam_papers` 已就绪，schema 支持真题标记和年份筛选
- **RealExamScreen** 已有三级筛选（examType → region → year）和试卷列表展示
- **QuestionService** 已有 `getAvailableExamTypes()`、`getAvailableRegions()`、`getAvailableYears()` 等真题查询方法
- **ExamCategoryRegistry** 定义了国考/省考/事业编/选调的科目结构
- **现有示例数据**通过 `assets/questions/*.json` 加载，`ensureSampleData()` 方法处理

### 产品设计参考
- 题库刷题系统：按科目分类（行测5大类/申论/公基），支持顺序练习、随机练习、专项练习
- 模拟考试：按真实考试时间题量模拟
- 题目解析：每题附详细解析，支持 AI 追问讲解

## 范围边界
- 做：2020-2025年国考/省考行测真题数据（含题目、选项、答案、解析）的导入和展示
- 不做：待确认

## 初步理解
用户需要大量真题数据填充到已有的练习系统中。核心问题是：
1. **数据来源**：2020-2025年真题数据从哪里来？
2. **数据范围**：覆盖哪些考试类型（国考/省考/事业编）？哪些科目？
3. **数据格式**：如何组织和导入这些数据？
4. **数据量预估**：6年真题大约几千道题

## 待确认事项
1. 真题数据来源问题
2. 覆盖的考试类型和科目范围
3. 数据导入方式
4. 解析内容的来源

## 确认方案

### 锁定决策

数据层：
  - 数据模型：复用现有 Question（isRealExam=1, year, region, examType）和 RealExamPaper 模型，无需新增模型
  - 数据库变更：无 schema 变更，现有表已完整支持
  - 序列化：JSON 文件 → Question.fromJson() → SQLite

爬虫工具链（新增 tools/scraper/）：
  - 语言：Python 3（requests + BeautifulSoup + Selenium 备用）
  - 数据源：
    1. 粉笔网（fenbi.com）— 主力源，题量大、解析详细
    2. QZZN 论坛 — 社区整理真题补充
    3. 各省人事考试网 — 官方真题（部分年份）
    4. 小红书 — 真题回忆版补充
  - 产出：标准化 JSON → assets/questions/real_exam/
  - 去重策略：基于题目内容 hash 跨源去重
  - 合规：遵守 robots.txt，请求间隔 ≥ 2s，携带 User-Agent

覆盖范围：
  - 国考（2020-2025）：行测（副省级+地市级）、申论
  - 省考（2020-2025）：江苏、浙江、上海、山东，行测+申论
  - 事业编（2020-2025）：行测/公基/综合应用能力
  - 解析：答案 + 详细文字解析

服务层：
  - 扩展 QuestionService.ensureSampleData() 支持批量真题导入
  - 导入逻辑：检查已导入数量，增量加载新 JSON 文件
  - 无新 LLM 调用
  - 新增依赖：无 Flutter 新依赖；Python 侧 requests/bs4/selenium

UI 层：
  - 无新页面，现有 RealExamScreen 三级筛选已支持
  - 科目练习 Tab 自动展示新导入的真题数据
  - 可能微调：真题数量统计标签更新

主要技术决策：
  - 爬虫用 Python 而非 Dart：生态成熟，反爬处理方便
  - 离线打包而非在线下载：用户体验好，无需联网
  - 多源去重用内容 hash：避免同一题重复入库

技术细节：
  - JSON 文件结构：assets/questions/real_exam/{exam_type}/{region}_{year}.json
  - 每个 JSON 文件包含 questions 数组和 paper 元数据
  - 去重 hash：md5(normalize(content + options))
  - 导入流程：app 启动 → 检查 real_exam 目录 → 逐文件加载 → 跳过已存在题目

范围边界：
  - 做：Python 爬虫脚本、JSON 标准化、assets 组织、批量导入逻辑
  - 不做：在线题库更新、用户端爬虫、申论自动批改、新 UI 页面

### 待细化
  - 各数据源的具体页面结构和反爬策略（需实际调研目标网站）
  - 小红书图片 OCR 识别（如真题以图片形式发布）
  - 事业编各地考试科目差异适配

### 验收标准
  - [mechanical] 爬虫脚本存在：判定 `ls tools/scraper/*.py`
  - [mechanical] JSON 数据文件存在：判定 `ls assets/questions/real_exam/`
  - [mechanical] Question 含真题标记：判定 grep "is_real_exam" 查询逻辑
  - [test] 导入逻辑正确：`flutter test test/real_exam_import_test.dart`
  - [manual] 运行 `flutter run -d windows`，进入科目练习 → 真题 Tab，能按考试类型/地区/年份筛选到 2020-2025 真题并正常作答
