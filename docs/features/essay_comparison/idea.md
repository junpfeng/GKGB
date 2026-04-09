# 申论小题多名师答案对比

## 核心需求
考生备考申论小题（概括、分析、对策、应用文）时，需要参考多位名师答案来理解不同答题角度和得分点。类似微信小程序"囊中对比"，提供多名师答案并排对比、AI 分析共同要点和差异的功能。

目标名师：袁东、飞扬、千寻、唐棣、kiwi 等
目标机构：粉笔、华图、中公、四海、超格、上岸村 等

## 调研上下文

### 现有申论体系
- `EssayService`：已实现 AI 批改功能（streamChat 流式评分），依赖 LlmManager
- `EssaySubmission` 模型：topic, content, wordCount, timeSpent, aiScore, aiComment
- `EssayMaterial` 模型：theme, materialType, content, source
- `EssayTrainingScreen`：写作练习 + AI 批改
- `EssayMaterialScreen`：素材库浏览
- DB 表：`essay_materials`、`essay_submissions`

### 架构参考
- 当前 DB 版本：v14，新表用 v15
- Provider 注册模式：`ChangeNotifierProxyProvider` (单依赖) / `ChangeNotifierProxyProvider2` (双依赖)
- 模型模式：`@JsonSerializable()` + `fromDb()` / `toDb()` / `copyWith()`
- Practice 页面入口：通过 `activeSubjects` 的 categories 动态生成 `AccentCard`
- 预置数据导入模式：参考 `ExamEntryScoreService`（页面进入时 loadFromAssets 导入）

### 设计文档
用户提供了详细的 `design.md`，已覆盖：
- 3 张新表 SQL schema（essay_sub_questions, teacher_answers, user_composite_answers）
- Service 接口设计（EssayComparisonService 7 个方法）
- UI 三级导航结构（试卷选择 → 小题列表 → 答案对比页）
- 集成方案（DB v15, Provider 注册, PracticeScreen 入口）

## 范围边界
- 做：申论小题数据模型、名师答案存储与展示、答案对比 UI（横滑/列表双模式）、AI 分析得分要点、用户综合答案编辑、预置数据导入
- 不做：大作文对比、自动爬取名师答案、社区贡献机制、答案评分/打分功能

## 初步理解
这是一个**内容展示+对比分析**型功能，核心价值是将散落在各处的名师答案集中展示并用 AI 提取共性。技术复杂度中等（3 表 + 1 Service + 1 Screen），但内容收集工作量大（每题 5-6 位名师答案）。

代码实现与现有申论体系（EssayService）相互独立，新建 EssayComparisonService 处理所有业务逻辑。

## 待确认事项
1. PracticeScreen 入口方式：design.md 说在申论分类下新增"小题对比"入口，但 PracticeScreen 的入口是通过 ExamCategoryService 的 activeSubjects 动态生成的，需要确认如何添加
2. AI 分析调用方式：chat() 还是 streamChat()？design.md 提到 analyzeWithAI 返回 String（非 Stream），但宪法要求 LLM 调用用 Stream 模式
3. 预置数据的初始覆盖范围：v1 先覆盖哪些年份和省份？
4. 用户综合答案是否需要 AI 辅助生成？

## 确认方案

核心思路：新建独立的 EssayComparisonService + EssayComparisonScreen，通过预置 JSON 导入申论小题和名师答案，提供横滑对比 + AI 分析得分要点的功能。

### 锁定决策

数据层：
- 新增 3 张表（DB v14 → v15）：
  - `essay_sub_questions`（year INT, region TEXT, exam_type TEXT, exam_session TEXT, question_number INT, question_text TEXT, question_type TEXT, material_summary TEXT, created_at TEXT, UNIQUE(year, region, exam_type, exam_session, question_number)）
  - `teacher_answers`（sub_question_id INT FK, teacher_name TEXT, teacher_type TEXT['teacher'|'institution'], answer_text TEXT, score_points TEXT[JSON], word_count INT, source_note TEXT, created_at TEXT, UNIQUE(sub_question_id, teacher_name)）
  - `user_composite_answers`（sub_question_id INT FK, content TEXT, notes TEXT, created_at TEXT, updated_at TEXT, UNIQUE(sub_question_id)）
- 索引（v15 迁移中创建）：
  - `idx_essay_sub_questions_filter ON essay_sub_questions(year, region, exam_type)`
  - `idx_teacher_answers_question ON teacher_answers(sub_question_id)`
  - `idx_user_composite_answers_question ON user_composite_answers(sub_question_id)`
- v15 迁移必须用 `db.transaction` 包裹所有 DDL（3 张表 + 3 个索引），确保原子性
- 新增 3 个模型：`EssaySubQuestion`、`TeacherAnswer`、`UserCompositeAnswer`，使用 `@JsonSerializable()` + `fromDb()`/`toDb()`/`copyWith()`
- `TeacherAnswer.scorePoints` 在模型中声明为 `List<String>`，`fromDb()` 中对 score_points 字段做 `jsonDecode`，`toDb()` 中做 `jsonEncode`
- 预置数据：`assets/data/essay_sub_questions_preset.json`，v1 包含示例数据（2024 国考 2-3 道小题 + 每题 3-4 位名师答案）用于开发调试
- `saveCompositeAnswer` 使用 `INSERT OR REPLACE` 语义（配合 UNIQUE 约束）

服务层：
- 新增 `EssayComparisonService extends ChangeNotifier`
- 依赖：`LlmManager`（通过构造函数注入）
- 方法签名：
  - `Future<void> importPresetData()` — 幂等导入预置数据（页面进入时触发，参考 ExamEntryScoreService 模式）
  - `Future<List<EssaySubQuestion>> loadExams({int? year, String? region, String? examType})` — 筛选试卷
  - `Future<List<EssaySubQuestion>> loadSubQuestions({required int year, required String region, required String examType})` — 获取某套试卷的小题
  - `Future<List<TeacherAnswer>> loadTeacherAnswers(int subQuestionId)` — 获取某题的名师答案
  - `Future<void> saveCompositeAnswer(int subQuestionId, String content, {String? notes})` — 保存用户综合答案
  - `Stream<String> analyzeWithAI(int subQuestionId)` — 流式 AI 分析
  - `Future<Map<String, int>> getTeacherStats()` — 名师统计

UI 层：
- 新增页面：`lib/screens/essay_comparison_screen.dart`（`EssayComparisonScreen`）
- 三级导航（单文件内通过状态切换）：试卷选择 → 小题列表 → 答案对比页
- 使用 `PopScope` 拦截返回事件：非顶级导航层时回退到上一级而非退出页面（Android 物理返回键适配）
- 答案对比页：顶部题目（可折叠）+ 中部横滑 PageView（默认卡片模式，可切换列表模式）+ 底部用户综合答案编辑区 + AI 分析按钮（流式输出）
- AI 流式分析：Screen 层持有 `StreamSubscription` 引用，`dispose()` 中必须 `cancel()`
- Windows/Android 统一默认卡片模式
- 状态管理：EssayComparisonService 自身作为 ChangeNotifier
- 入口：PracticeScreen 中硬编码独立入口卡片（类似面试练习入口），放在申论相关卡片附近

主要技术决策：
- 入口方式：硬编码 AccentCard，不修改 ExamCategoryService，原因是这是跨科目的辅助功能
- AI 调用：LlmManager.streamChat() 流式输出，符合宪法性能约束
- Provider 注册：ChangeNotifierProxyProvider<LlmManager, EssayComparisonService>，序号 21（MasterQuestionService 之后）

技术细节：
- 数据结构：见上方 3 张表 schema
- 接口签名：见上方 7 个方法
- 状态流转：idle → loading → loaded（筛选/加载），idle → analyzing → analyzed（AI 分析），idle → editing → saved（综合答案）
- 路由变更：PracticeScreen → EssayComparisonScreen（Navigator.push）

范围边界：
- 做：3 表 + 3 模型 + 1 Service + 1 Screen + 预置数据导入 + AI 流式分析 + 横滑/列表双模式
- 不做：大作文对比、自动爬取名师答案、社区贡献机制、答案评分打分功能
- 保护策略：EssayComparisonService 与 EssayService 完全独立，不修改现有申论功能代码

### 待细化
- AI 分析的 prompt 模板具体内容（方向：提取共同得分要点、差异点、综合建议；只发送名师答案+题目，不含用户综合答案）
- 筛选栏 UI 细节（年份/省份/考试类型的 Dropdown/Chip 样式）
- 预置数据 JSON 的具体结构格式
- `loadExams` 返回去重的试卷维度数据（Service 层内 group by year/region/exam_type）
- `notifyListeners()` 在每个状态转换点的具体调用时机
- Windows 上 PageView 翻页适配（左右箭头按钮）

### 验收标准
- [mechanical] 3 个模型文件存在：判定 `grep -r "EssaySubQuestion" lib/models/`
- [mechanical] Service 文件存在：判定 `grep -r "EssayComparisonService" lib/services/`
- [mechanical] Screen 文件存在：判定 `grep -r "EssayComparisonScreen" lib/screens/`
- [mechanical] DB v15 迁移：判定 `grep "version.*15\|oldVersion < 15" lib/db/database_helper.dart`
- [mechanical] Provider 注册：判定 `grep "EssayComparisonService" lib/main.dart`
- [mechanical] PracticeScreen 入口：判定 `grep "EssayComparison\|小题对比" lib/screens/practice_screen.dart`
- [manual] 启动应用：运行 `flutter run -d windows` 验证 PracticeScreen 可见"小题对比"入口，点击进入三级导航，预置数据正确加载，横滑/列表模式切换正常，AI 分析流式输出
