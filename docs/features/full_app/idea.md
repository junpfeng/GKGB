# 考公考编智能助手 — 完整实现

## 核心需求
参考 docs/product-design.md，实现完整的考公考编智能助手。所有功能模块都要支持使用 DeepSeek、千问、Claude、OpenAI、Ollama 等大语言模型的交互。

## 调研上下文

### 已有实现
- 5 个 Tab 骨架页面（刷题/模考/岗位/统计/我的），全部为占位 UI，无业务逻辑
- SQLite 数据库 schema 已完整定义 10 张表（questions, user_answers, favorites, user_profile, talent_policies, positions, match_results, study_plans, daily_tasks, llm_config）
- LLM 抽象层：LlmProvider 接口（chat/streamChat/testConnection）+ LlmManager（注册/默认/fallback）
- QuestionService（ChangeNotifier）仅有 totalQuestions/answeredCount/correctCount 统计属性
- pubspec.yaml 已有：sqflite, path_provider, dio, provider, json_annotation, connectivity_plus, build_runner, json_serializable
- 缺少：flutter_secure_storage、models/ 目录、具体 LLM Provider 实现

### 产品设计文档要点
- 5 大模块：题库刷题、模拟考试、人才引进匹配、岗位定制学习路线、多大模型接入
- 技术栈：Flutter 3.x, SQLite, Dio, Provider, json_serializable, Material Design 3
- 数据安全：API Key 加密存储，用户画像仅本地存储

## 范围边界
- 做：5大模块完整 UI + 业务逻辑、数据持久化、5个 LLM Provider 完整实现、示例题库数据、每个模块的 LLM 交互、单元测试
- 不做：公告爬虫（用手动添加+AI解析替代）、云端同步、后台定时任务(WorkManager)

## 初步理解
项目已有完整的数据库 schema 和基础骨架，需要自底向上实现：数据模型层 → 服务层 → UI 层，确保每个功能模块都有 LLM 交互入口。

## 待确认事项
无（已全部确认）

## 确认方案

核心思路：基于已有骨架，按数据层→服务层→UI层自底向上实现全部5大模块

### 锁定决策

数据层：
  - 新增 models：Question, Exam, UserAnswer, UserProfile, TalentPolicy, Position, MatchResult, StudyPlan, DailyTask, LlmConfig
  - 所有 model 使用 json_serializable，字段与现有 database_helper.dart 表结构对齐
  - 数据库不变更（schema 已完整），仅扩展 DatabaseHelper 添加 CRUD 方法
  - 新增 assets/questions/ 目录，内置示例题库 JSON 文件（行测5科 + 申论 + 公基，每科5-10题）

服务层：
  - 扩展 QuestionService：题目查询、答题记录、错题收藏、按科目/题型筛选
  - 新增 ExamService（ChangeNotifier）：组卷、计时、评分、历史成绩
  - 新增 ProfileService（ChangeNotifier）：用户画像 CRUD
  - 新增 MatchService（ChangeNotifier）：公告管理、两级匹配引擎、匹配结果
  - 新增 StudyPlanService（ChangeNotifier）：计划生成、每日任务、动态调整
  - LLM 完整实现 5 个 Provider：
    - DeepSeekProvider (OpenAI兼容, api.deepseek.com)
    - QwenProvider (DashScope API, dashscope.aliyuncs.com)
    - ClaudeProvider (Anthropic API, api.anthropic.com)
    - OpenAiProvider (OpenAI API, api.openai.com)
    - OllamaProvider (本地 REST, localhost:11434)
  - DeepSeek/OpenAI 共用 OpenAI 兼容基类，只换 baseUrl 和 key
  - 新增 flutter_secure_storage 依赖，LlmConfigService 管理加密存储的 API Key

UI 层：
  - 重写 PracticeScreen：科目选择→题目列表→答题界面（QuestionCard widget）
  - 新增 QuestionDetailScreen：单题作答、查看解析、AI追问讲解
  - 重写 ExamScreen：考试配置→计时答题→评分报告 + AI 分析薄弱点
  - 重写 PolicyMatchScreen：公告列表、手动添加公告、AI解析公告、匹配结果列表
  - 新增 PositionDetailScreen：岗位匹配详情 + 筛选理由卡片（MatchReasonCard widget）
  - 重写 ProfileScreen：用户画像编辑表单（学历/专业/院校/政治面貌/证书/目标城市等）
  - 新增 LlmSettingsScreen：模型选择、API Key 输入、连接测试
  - 重写 StatsScreen：今日/累计统计数据、各科正确率
  - 新增 StudyPlanScreen：学习计划总览 + AI 生成计划
  - 新增 DailyTaskScreen：今日任务清单
  - 通用 widgets：QuestionCard, MatchReasonCard, ProgressRing

LLM 交互场景（全模块覆盖）：
  - 刷题：题目 AI 讲解、追问答疑
  - 模考：考后 AI 分析薄弱点、申论/主观题 AI 批改
  - 岗位匹配：公告文本 AI 解析为结构化岗位、模糊条件 AI 判断
  - 学习路线：AI 生成学习计划、根据错题分布生成复习建议
  - 面试模拟：AI 生成面试题 + 答题框架（基础版）

数据库变更（红蓝对抗修订）：
  - DB version 升到 2，添加 onUpgrade 迁移
  - 新增 exams 表：id, subject, total_questions, score, time_limit, started_at, finished_at, status
  - user_answers 表增加 nullable exam_id 字段（区分刷题 vs 模考答题）
  - llm_config 表删除 api_key_encrypted 字段（API Key 仅存 flutter_secure_storage）
  - 补充所有必要索引：questions(subject,category), user_answers(question_id), user_answers(answered_at), user_answers(exam_id), daily_tasks(plan_id,task_date), positions(policy_id), match_results(position_id), favorites(question_id) UNIQUE
  - 所有 List/Map 类型的 TEXT 字段统一使用 JSON 格式存储

状态管理：
  - main.dart 移除 Provider<DatabaseHelper>（Screen 禁止直接访问 DB）
  - LlmManager 改为 ChangeNotifier（setDefault/registerProvider 时 notifyListeners）
  - Service 依赖图（注册顺序从上到下）：
    1. ChangeNotifierProvider: QuestionService（无依赖）
    2. ChangeNotifierProvider: ProfileService（无依赖）
    3. ChangeNotifierProvider: LlmManager（无依赖）
    4. ChangeNotifierProxyProvider: ExamService（依赖 QuestionService）
    5. ChangeNotifierProxyProvider: MatchService（依赖 ProfileService, LlmManager）
    6. ChangeNotifierProxyProvider: StudyPlanService（依赖 QuestionService, LlmManager）
  - 包含 Timer/StreamSubscription 的 Service 必须在 dispose 中清理

安全措施（红蓝对抗修订）：
  - API Key 仅存 flutter_secure_storage，key 格式 `llm_key_{provider_name}`
  - flutter_secure_storage 在 Windows 使用 DPAPI，安全级别可接受（文档标注）
  - Dio 拦截器脱敏 Authorization header，禁止 LogInterceptor 打印请求头
  - OllamaProvider baseUrl 用户可配置（非硬编码），Android 端显示提示

性能措施（红蓝对抗修订）：
  - 题库 JSON 导入使用 compute() isolate，每科一个 JSON 文件分文件加载
  - 匹配引擎使用 JOIN/IN 批量查询，避免 N+1
  - streamChat() 补充 fallback 逻辑（主模型 Stream 出错时切换 fallback）

平台兼容（红蓝对抗修订）：
  - 添加 sqflite_common_ffi 依赖，Windows 端 main.dart 初始化 sqfliteFfiInit() + databaseFactoryFfi
  - connectivity_plus 统一使用有网/无网二元判断

主要技术决策：
  - 公告数据：手动添加+AI解析，不做爬虫。原因：爬虫目标网站不确定，手动方式MVP可用
  - 5个LLM Provider全部完整实现。原因：用户要求所有功能支持多模型交互
  - 示例题库：JSON assets内置。原因：确保首次启动即可演示完整流程
  - API Key存储：仅 flutter_secure_storage。原因：宪法要求加密存储，禁止SQLite明文

技术细节：
  - Question model: id, subject, category, type, content, options(List<String>), answer, explanation, difficulty, createdAt
  - Exam model: id, subject, totalQuestions, score, timeLimit, startedAt, finishedAt, status
  - UserProfile model: 与 user_profile 表字段一一对应（education, degree, major, majorCode, university, is985, is211, workYears, hasGrassrootsExp, politicalStatus, certificates, age, gender, hukouProvince, targetCities）
  - MatchResult model: id, positionId, matchScore(0-100), matchedItems(List<String>), riskItems(List<String>), unmatchedItems(List<String>), advice, isTarget, matchedAt
  - DeepSeekProvider: baseUrl="https://api.deepseek.com/v1", OpenAI chat/completions 格式
  - QwenProvider: baseUrl="https://dashscope.aliyuncs.com/compatible-mode/v1", OpenAI兼容格式
  - ClaudeProvider: baseUrl="https://api.anthropic.com/v1", Anthropic messages 格式
  - OpenAiProvider: baseUrl="https://api.openai.com/v1", OpenAI chat/completions 格式
  - OllamaProvider: baseUrl 用户可配置，默认 "http://localhost:11434"，/api/chat 格式
  - 题库JSON格式: { "subject": "行测", "category": "言语理解", "questions": [...] }，每科独立文件

范围边界：
  - 做：5大模块完整UI+业务逻辑、数据持久化、5个LLM Provider完整实现、所有模块LLM交互、示例数据、单元测试、申论/主观题AI批改、面试模拟基础版
  - 不做：公告爬虫、云端同步、后台定时任务(WorkManager)

### 待细化
  - 匹配引擎的评分权重细节：引擎实现时根据产品文档中的匹配维度设计
  - 学习计划的阶段划分算法：实现时根据可用天数和薄弱点动态计算

### 验收标准
  - [mechanical] models 目录存在且包含所有数据模型：判定 `ls lib/models/*.dart`
  - [mechanical] 5个 LLM Provider 文件存在：判定 `ls lib/services/llm/*_provider.dart`
  - [mechanical] 示例题库 assets 存在：判定 `ls assets/questions/*.json`
  - [mechanical] sqflite_common_ffi 在 pubspec.yaml 中：判定 `grep sqflite_common_ffi pubspec.yaml`
  - [test] 全量测试通过：`flutter test`
  - [mechanical] flutter analyze 零错误：`flutter analyze`
  - [manual] 刷题流程：运行 `flutter run -d windows` 验证 `选择科目→答题→查看解析→AI讲解→错题本可见`
  - [manual] 用户画像：验证 `填写个人信息→保存→重启后数据保留`
  - [manual] LLM设置：验证 `配置任意模型 API Key→保存→测试连接成功`
  - [manual] 岗位匹配：验证 `手动添加公告→AI解析→匹配结果展示筛选理由`
  - [manual] 学习路线：验证 `选定目标岗位→AI生成学习计划→每日任务清单`
