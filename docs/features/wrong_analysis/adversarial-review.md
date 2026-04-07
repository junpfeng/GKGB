# 错题深度分析 — 红队对抗审查

> 审查对象：`docs/features/wrong_analysis/idea.md` ## 确认方案  
> 审查基准：`.claude/rules/constitution.md` 工程宪法 + 现有代码实现  
> 审查轮次：1（轻量扩展模块）

---

## 严重问题（CRITICAL）

### C1. submitAnswer 耦合 WrongAnalysisService — 分层违反 + 循环依赖风险

**severity: CRITICAL**

方案决策 #6：「扩展 `QuestionService.submitAnswer()`：答案错误时异步调用 `WrongAnalysisService.analyzeError()`」。

问题：QuestionService 位于 services 层，WrongAnalysisService 也位于 services 层且 **构造函数注入了 QuestionService**（决策 #4）。如果 QuestionService 反过来调用 WrongAnalysisService，就形成了 **双向依赖**：

```
QuestionService → WrongAnalysisService（submitAnswer 触发分析）
WrongAnalysisService → QuestionService（构造函数注入）
```

这直接违反宪法「分层依赖方向：screens → services → db/models，禁止反向依赖」的精神——同层双向耦合同样是架构腐化。

**改进方案**：submitAnswer 本身不应感知 WrongAnalysisService。有两种干净的做法：
- **(A) Screen 层编排**：PracticeSessionScreen / QuestionDetailScreen 的 `_confirmAnswer` 在 `submitAnswer()` 返回后，自行判断 `!isCorrect` 则调用 `WrongAnalysisService.analyzeError()`。编排逻辑在 Screen 层，两个 Service 互不感知。
- **(B) 事件回调**：QuestionService 暴露 `onAnswerSubmitted` Stream，WrongAnalysisService 订阅。但增加了复杂度，不推荐此场景使用。

推荐方案 A，最简单且符合现有模式。

---

### C2. LLM 错因分析用 chat() 非 streamChat() — 违反宪法性能约束

**severity: CRITICAL**

方案决策 #4 / #7：`analyzeError()` 调用 `LlmManager.chat()` 分析错因。

宪法明确规定：「LLM 调用使用 Stream 模式展示，避免长时间无响应」。虽然 analyzeError 是后台异步任务不直接展示 UI，但 `chat()` 是同步等待完整响应，对于网络慢或大模型响应慢的场景，一次 chat() 可能 hang 10-30 秒，期间无法取消、无法超时控制。

**改进方案**：
- analyzeError 内部用 `streamChat()` 收集完整响应（`await stream.join()`），这样至少可以加 timeout 和 cancel 控制。
- 或者明确为 chat() 调用设置 timeout（当前 LlmManager.chat 有无 timeout？需确认）。
- 方案文档应明确：后台分析任务的超时策略（建议 15s），超时则 error_type 留空，后续可重试。

---

## 高优先级问题（HIGH）

### H1. 现有 loadWrongQuestions 存在 N+1 查询，新功能会放大此问题

**severity: HIGH**

当前 `QuestionService.loadWrongQuestions()` 实现（第 86-108 行）：先 `queryWrongQuestionIds()` 拿到 ID 列表，然后 **逐个** `queryQuestionById(id)` — 这是经典 N+1 问题。

方案新增的 `queryTopWrongCategories` 和 `queryCategoryAccuracy` 等查询虽然用 JOIN + GROUP BY 设计合理，但如果 WrongAnalysisService 内部复用 loadWrongQuestions 做数据预处理，N+1 问题会扩散。

**改进建议**：
- loadWrongQuestions 应重构为单次 JOIN 查询（`SELECT q.* FROM questions q JOIN user_answers ua ON ... WHERE ua.is_correct = 0`），这不在本次范围但应作为 tech debt 登记。
- 确保新增的 WrongAnalysisService 方法全部走 DatabaseHelper 的聚合查询，不要调用 loadWrongQuestions。

---

### H2. error_type 索引设计不足 — 统计查询缺少复合索引

**severity: HIGH**

方案决策 #3：新增索引 `idx_user_answers_error_type ON user_answers(error_type)`。

但实际查询场景是：
- `getErrorTypeDistribution({String? subject})` → 需要 JOIN questions 表按 subject 过滤后 GROUP BY error_type
- `getTopWrongCategories` → JOIN questions，GROUP BY category，WHERE is_correct = 0
- `getCategoryAccuracy` → GROUP BY category，含 is_correct 聚合

单列 error_type 索引对这些查询帮助有限。真正需要的复合索引是：
- `idx_user_answers_correct_question ON user_answers(is_correct, question_id)` — 加速所有「错题」相关的 JOIN 查询
- error_type 单列索引可保留但优先级低（仅用于纯 error_type 分布统计，不带 subject 过滤时）

---

### H3. WrongAnalysisService 对 QuestionService 的依赖是否必要

**severity: HIGH**

方案决策 #4：WrongAnalysisService 构造函数注入 QuestionService + LlmManager。

审查现有方法签名：
- `analyzeError(Question, String, String)` — 直接接收参数，不需要 QuestionService
- `getErrorTypeDistribution` / `getTopWrongCategories` / `getCategoryAccuracy` — 全是 DB 查询，通过 DatabaseHelper 即可
- `generateDiagnosisReport` / `getRecentWrongStats` — 同上

**实际上 WrongAnalysisService 只需要 DatabaseHelper + LlmManager**，不需要注入 QuestionService。如果注入了 QuestionService，会导致：
1. Provider 注册时不必要的 ProxyProvider 依赖链
2. 与 C1 中的循环依赖风险叠加

**改进方案**：WrongAnalysisService 只注入 LlmManager（DatabaseHelper 已是单例直接用 `DatabaseHelper.instance`），Provider 注册简化为 `ChangeNotifierProxyProvider<LlmManager, WrongAnalysisService>`。

---

### H4. UserAnswer 模型缺少 error_type 字段

**severity: HIGH**

当前 `UserAnswer` 模型（`lib/models/user_answer.dart`）没有 error_type 字段，`toDb()` 和 `fromDb()` 也不包含。方案文档只提到 DB 层 ALTER 和 Service 层方法，没有提到更新 UserAnswer 模型。

如果不更新模型，`insertAnswer()` 和后续读取逻辑会忽略 error_type 字段，导致：
- `toDb()` 永远不会写入 error_type（需要单独 UPDATE，增加复杂度）
- `fromDb()` 永远丢失 error_type 信息

**改进方案**：在方案中明确添加一条决策：更新 UserAnswer 模型，增加 `errorType` 字段（nullable String，默认 null），同步更新 `toDb()` / `fromDb()` / `json_serializable` 注解。

---

### H5. 异步分析的错误处理和重试策略缺失

**severity: HIGH**

方案决策 #13：「submitAnswer 返回后异步触发分析，分析结果后续更新到 DB」。

但没有回答：
- 分析失败（LLM 不可用、网络超时）时怎么办？error_type 永远为空？
- 是否有重试机制？用户打开错题分析页时，对 error_type 为空的记录是否自动补分析？
- 大量历史错题（用户升级到 v7 后）的 error_type 全部为空，批量补分析会产生大量 LLM 调用，如何限流？

**改进方案**：
- 分析失败时 error_type 留空，方案已隐含此行为但应显式说明
- 错题分析页打开时，对 error_type 为空的前 N 条（如 5 条）自动触发补分析，避免一次性全量调用
- 补分析应设置并发限制（串行或最多 2 并发）

---

## 低优先级问题（LOW）

### L1. error_type 用字符串而非枚举约束

**severity: LOW**

error_type 定义为 `TEXT DEFAULT ''`，5 种合法值靠文档约定。如果 LLM 返回了非预期值（如 `"knowledge_gap"` 而非 `"blind_spot"`），regex 降级可能无法捕获。

**建议**：在 Dart 侧定义 enum + validation，`updateAnswerErrorType` 方法在写入前校验合法性。DB 层无法加 CHECK 约束（SQLite ALTER 不支持），但 Service 层可以守门。

---

### L2. 诊断报告用 generateDiagnosisReport() → Stream<String>，但错因分析用 chat() 非 Stream

**severity: LOW**

决策 #4 中两个 LLM 方法风格不一致：诊断报告用 Stream（正确），错因分析用 chat()（见 C2）。即使 C2 已修复，建议在方案中统一说明 LLM 调用模式选择原则：面向用户展示用 Stream，后台任务用 chat+timeout。

---

### L3. getCategoryAccuracy 的 LEFT JOIN 语义需明确

**severity: LOW**

决策 #17 提到 `getCategoryAccuracy 需 LEFT JOIN 确保无答题记录的分类也显示`。但 LEFT JOIN 的左表是 questions 还是某个 categories 枚举表？当前没有独立的分类表，categories 散落在 questions.category 字段中。

实际实现应该是：`SELECT DISTINCT category FROM questions` 作为全分类集，再 LEFT JOIN user_answers 计算正确率。方案中应明确这一点，避免实现时遗漏无答题分类。

---

### L4. 饼图空数据的边界已覆盖，但 TOP 10 空数据未提及

**severity: LOW**

决策 #16 提到饼图空数据友好提示，但 TOP 10 列表和知识图谱在零数据时的行为未描述。应统一处理。

---

## 确认无问题的部分

- **DB Migration 策略**（决策 #2）：version 6 → 7，事务包裹 ALTER，_createDB 同步包含新字段 — 符合现有模式（见 _onUpgrade 中 oldVersion < 2/3/4/5/6 的处理方式），可回滚（ALTER ADD COLUMN 是幂等的）。
- **LLM 调用合规**（决策 #4/#7）：通过 LlmManager.chat()/streamChat() 调用，未绕过 LlmManager 直接耦合具体 Provider — 符合宪法。
- **Prompt 注入防护**（决策 #15）：用 `<user_answer>` 标签包裹 — 合理的轻量防护。
- **新增页面路由**（决策 #8/9/10）：入口在 PracticeScreen 错题本 Tab，新页面独立文件 — 符合现有导航模式。
- **Provider 注册**（决策 #12）：ChangeNotifierProxyProvider2 注入依赖 — 符合 main.dart 现有模式（但依赖列表需根据 H3 调整）。
- **范围边界清晰**：明确了不做 graphview 网状图谱、自动周报、掌握度评分 — 避免过度设计。
- **纯数据模型**（决策 #11）：ErrorAnalysis 作为非 DB 模型放在 models/ — 合理。
