# 红蓝对抗审查：real_exam_collection

> 审查对象：`idea.md` 初步理解 + `advanced-features-design.md` 第一章锁定决策
> 审查基准：现有代码库（DB version=3）+ 工程宪法 `constitution.md`
> 审查日期：2026-04-07

---

## 第 1 轮 — 红队攻击

### [CRITICAL] 1. DB 迁移方案 ALTER TABLE 添加字段缺乏 NOT NULL / DEFAULT 保护，存量数据产生脏状态

- **描述**：方案提出对 `questions` 表 `ALTER TABLE ADD COLUMN` 增加 `region`、`year`、`exam_type`、`exam_session`、`is_real_exam` 五个字段。SQLite 的 ALTER TABLE ADD COLUMN 要求新增列必须有 DEFAULT 值或允许 NULL。但如果后续查询逻辑（如按 region 筛选）未处理 NULL，所有存量题目（非真题）的 region/year/exam_type 均为 NULL，WHERE 条件 `region = ?` 永远不会匹配到它们，导致"非真题也查不到"的诡异行为。
- **影响**：存量数百道题目在真题筛选 UI 中消失；如果 `is_real_exam` 默认为 NULL 而非 0，则无法可靠区分真题和普通题。
- **建议修复**：
  1. 所有新增字段必须有显式 DEFAULT 值：`is_real_exam INTEGER DEFAULT 0`、`region TEXT DEFAULT ''`、`year INTEGER DEFAULT 0`、`exam_type TEXT DEFAULT ''`、`exam_session TEXT DEFAULT ''`。
  2. 迁移脚本中增加 `UPDATE questions SET is_real_exam = 0 WHERE is_real_exam IS NULL` 保底。
  3. 查询层对 `is_real_exam` 做显式过滤：真题专区仅查 `is_real_exam = 1`，普通刷题不受影响。

### [CRITICAL] 2. 现有 _onUpgrade 迁移使用 try-catch 静默吞错，新版本迁移可能悄无声息地失败

- **描述**：`database_helper.dart` 的 `_onUpgrade` 中，每个 ALTER/CREATE 操作都被 `try { ... } catch (e) { debugPrint('跳过: $e'); }` 包裹。当 v3→v4 迁移执行真题字段的 ALTER TABLE 时，如果任何一条 SQL 失败（如字段名拼写错误、类型不匹配），错误被静默吞掉，数据库停留在半迁移状态：version 已写入 4，但字段实际不存在。后续所有真题查询全部崩溃，且无法自动修复（因为 version 已经是 4，不会重新触发迁移）。
- **影响**：用户升级后应用崩溃，且无法通过重启恢复。这是数据层的 single point of failure。
- **建议修复**：
  1. 将整个版本迁移包在一个事务中（`db.transaction((txn) => ...)`），任何一步失败则全部回滚，version 不变。
  2. 移除 try-catch 静默模式，改为在事务失败时抛出异常并上报。
  3. 增加迁移后校验步骤：检查新增列是否存在于 `PRAGMA table_info(questions)` 结果中。

### [CRITICAL] 3. `real_exam_papers` 新表缺乏设计细节，与 exams 表职责边界模糊

- **描述**：方案提到"新增 `real_exam_papers` 表（整套试卷元数据）"，但待确认事项第 2 条明确质疑"是复用 exams 表加字段还是新建表？"，该决策未锁定。现有 `exams` 表承载模拟考试记录（含 score、started_at、finished_at 等运行时状态），而真题试卷是元数据（原始题序、分值分布、年份地区）。如果复用 exams 表，会导致：(a) 每位用户每做一次真题模考就产生一条 exams 记录，无法区分"试卷模板"和"考试实例"；(b) exams 表需要加 region/year 等字段，进一步膨胀。
- **影响**：数据模型混乱，后续统计（如"某套真题的平均得分"）需要复杂聚合查询。
- **建议修复**：
  1. 必须新建 `real_exam_papers` 表，作为试卷模板：`id, region, year, exam_type, exam_session, subject, title, total_score, time_limit, question_ids(JSON), source, created_at`。
  2. `exams` 表增加 `paper_id INTEGER` 外键指向 `real_exam_papers.id`（可为 NULL，NULL 表示自定义组卷）。
  3. 这样 `real_exam_papers` 是静态模板，`exams` 是用户的每次考试实例，职责分离清晰。

### [CRITICAL] 4. Question 模型缺少真题字段，fromDb/toDb 未同步扩展会导致数据丢失

- **描述**：现有 `Question` 类有 10 个字段，`fromDb()` 和 `toDb()` 硬编码了这 10 个字段。方案要求新增 `region`、`year`、`exam_type`、`exam_session`、`is_real_exam` 五个字段。如果开发者只改了 DB schema 但忘了同步 Question 模型（这在当前手写 fromDb/toDb 的模式下极易发生），则：(a) 插入真题时新字段不会写入 DB；(b) 读取真题时新字段丢失，UI 无法显示地区/年份。
- **影响**：真题功能完全无效，但不会报错（字段默认为 NULL），极难排查。
- **建议修复**：
  1. 在 Question 类中增加五个字段，同时更新 `fromDb()`、`toDb()`、`@JsonSerializable` 注解和 `question.g.dart`。
  2. 更严格地说，宪法规定"所有需要序列化的模型使用 json_serializable"，当前 Question 同时有 `fromJson/toJson`（生成的）和 `fromDb/toDb`（手写的），两套序列化路径必须同步更新，这本身就是设计债务。建议将 `fromDb/toDb` 也纳入代码生成，或至少写单测验证字段一致性。

### [HIGH] 5. N+1 查询：loadWrongQuestions 逐条查询题目详情

- **描述**：`QuestionService.loadWrongQuestions()` 先调用 `_db.queryWrongQuestionIds()` 获取错题 ID 列表，然后对每个 ID 调用 `_db.queryQuestionById(id)` 逐条查询。当错题数量达到数百条时，产生 N+1 次 DB 查询。真题功能上线后，题库规模和答题量将显著增长，错题量也会随之增加。
- **影响**：错题本加载时间线性增长，数百条错题时可能超过宪法规定的 100ms 响应限制。
- **建议修复**：
  1. 改为单次 JOIN 查询：`SELECT q.* FROM questions q JOIN (SELECT DISTINCT question_id FROM user_answers WHERE is_correct = 0) wa ON q.id = wa.question_id`。
  2. 加上 LIMIT/OFFSET 支持分页加载。

### [HIGH] 6. queryMatchResults 中存在 SQL 注入风险（字符串拼接而非参数化）

- **描述**：`DatabaseHelper.queryMatchResults()` 中 `${isTarget ? 1 : 0}` 直接拼入 SQL 字符串。虽然当前 isTarget 是 bool 类型不会被注入，但这种模式违反参数化查询的最佳实践。如果真题功能扩展查询时复制这种模式处理用户输入的 region/year 字符串，就会产生真实的 SQL 注入漏洞。
- **影响**：当前无直接漏洞，但建立了危险的代码模式先例。
- **建议修复**：改为参数化查询 `WHERE mr.is_target = ?` 并传入 `whereArgs`。在真题查询方法中严格使用参数化。

### [HIGH] 7. 真题筛选查询缺少复合索引，性能将不达标

- **描述**：方案要求支持"按地区+年份+考试类型"三级筛选。现有索引仅有 `idx_questions_subject_category`。如果新增字段后不建对应索引，三级筛选查询将对 questions 表做全表扫描。随着真题数据导入（设计文档提到覆盖国考+各省省考近 3 年），questions 表规模可能达到数万行。
- **影响**：违反宪法"题库查询响应 < 100ms"约束。
- **建议修复**：
  1. v4 迁移中增加复合索引：`CREATE INDEX idx_questions_real_exam ON questions(is_real_exam, region, year, exam_type)`。
  2. 考虑增加 `CREATE INDEX idx_questions_region_year ON questions(region, year)` 覆盖最常用的二级筛选。

### [HIGH] 8. ExamService._timer 在 Provider dispose 时机可能泄漏

- **描述**：`ExamService` 的 `dispose()` 调用 `_stopTimer()` 来取消定时器。但在 `main.dart` 中，`ExamService` 通过 `ChangeNotifierProxyProvider` 注册，其 `update` 回调是 `prev ?? ExamService(qs)`。如果 Provider 因为依赖变更重建 ExamService 实例，旧实例的 Timer 不会被取消（因为 `prev` 被丢弃但 `dispose` 时机不确定）。真题模考还原功能会频繁使用考试计时器，放大此问题。
- **影响**：多个 Timer 并行运行，每秒多次 notifyListeners 导致 UI 卡顿和状态混乱。
- **建议修复**：
  1. `ChangeNotifierProxyProvider` 的 `update` 回调应始终返回 `prev!` 并通过 setter 更新依赖，而非创建新实例。
  2. 或改为 `ChangeNotifierProvider` + 手动依赖注入，确保单例生命周期。

### [HIGH] 9. 用户贡献真题的 AI 结构化流程可能绕过 LlmManager

- **描述**：方案提到"用户文字粘贴 -> AI 解析为标准题目格式"。宪法明确规定"禁止绕过 LlmManager 直接调用具体模型 Provider"。但当前代码中 `QuestionService.gradeEssay()` 接收 `LlmManager` 作为参数传入（而非通过构造函数依赖注入），这意味着新的 AI 结构化方法可能沿用这种"临时传入"模式，如果调用方传错对象或直接 new 一个 Provider，就违反了宪法。
- **影响**：AI 调用路径不一致，fallback 机制可能失效。
- **建议修复**：
  1. `QuestionService` 构造函数应接收 `LlmManager` 依赖（同 ExamService 的模式），而非方法级传参。
  2. 在 `main.dart` 中改用 `ChangeNotifierProxyProvider` 注入 LlmManager 依赖。

### [HIGH] 10. QuestionListScreen 一次加载 50 题且无分页，真题场景下可能爆内存

- **描述**：`_QuestionListScreenState._loadQuestions()` 硬编码 `limit: 50`，且没有下拉加载更多（无 offset 递增逻辑）。真题模式下，某省某年行测可能有 120+ 题，UI 只显示前 50 题。同时宪法规定"禁止一次性加载全部数据"。
- **影响**：(a) 真题不完整展示；(b) 如果改为不限制 limit，则违反宪法性能约束。
- **建议修复**：
  1. 实现无限滚动分页：初始加载 20 条，滚动到底部加载下一页。
  2. 使用 `ScrollController` 监听滚动位置，触发 `loadQuestions(offset: currentOffset)` 追加加载。

### [HIGH] 11. 真题试卷还原模考缺乏 question_ids 有序关联设计

- **描述**：方案提到"支持整套试卷还原（保留原始题序和分值分布）"，但现有数据结构中没有任何地方记录"某套试卷包含哪些题目、以什么顺序排列、每题多少分"。`exams` 表仅存 subject/total_questions/score，题目通过 `user_answers.exam_id` 反向关联，无法预定义试卷结构。
- **影响**：无法实现"完全还原某年某省真题试卷"的核心功能。
- **建议修复**：
  1. `real_exam_papers` 表增加 `question_ids TEXT`（JSON 数组，有序题目 ID 列表）和 `score_distribution TEXT`（JSON 对象，每题分值）。
  2. 开始模考时，从 paper 读取 question_ids 按序加载题目，而非随机抽题。

### [LOW] 12. loadWrongQuestions 和 loadFavorites 直接调用 notifyListeners 而非 _safeNotify

- **描述**：`QuestionService` 中 `loadQuestions()` 使用了 `_safeNotify()`（通过 `scheduleMicrotask`）避免 build 期间通知，但 `loadWrongQuestions()` 和 `loadFavorites()` 仍然直接调用 `notifyListeners()`。Git 历史显示曾有 "fix: QuestionService 在 build 期间调用 notifyListeners 导致崩溃" 的修复，说明这个问题确实发生过。
- **影响**：在某些导航时序下（如从错题本 Tab 切换时），可能再次触发 "setState during build" 异常。
- **建议修复**：所有 `notifyListeners()` 调用统一替换为 `_safeNotify()`。

### [LOW] 13. _showFinishDialog 中正确题数统计逻辑错误

- **描述**：`PracticeSessionScreen._showFinishDialog()` 中 `final correct = _submitted.values.where((v) => v).length`。但 `_submitted` 的 value 只是表示"是否已提交"（始终为 true），并非"是否正确"。所以 `correct` 实际等于 `_submitted.length`（已提交题数），而非正确题数。
- **影响**：练习完成弹窗显示的"正确 N 题"数据永远等于已答题数，给用户造成全部正确的错觉。
- **建议修复**：在 `_submitted` Map 中存储 `bool isCorrect` 而非简单的 `true`，或另维护一个 `_correctIds` Set。

### [LOW] 14. 平台一致性：真题文件导入路径在 Windows 和 Android 可能不同

- **描述**：现有 `_importSampleData()` 使用 `rootBundle.loadString(filePath)` 从 assets 加载，这在两个平台一致。但如果真题功能支持"用户导入 JSON 文件"（从本地文件系统选择），Windows 的文件路径格式（反斜杠、驱动器号）与 Android（内容 URI）完全不同。宪法规定"平台差异代码集中在 services 层处理"。
- **影响**：如果未做平台适配，用户导入功能在其中一个平台崩溃。
- **建议修复**：使用 `file_picker` 等跨平台文件选择库，返回统一的文件引用，在 service 层处理平台差异。

### [LOW] 15. idea.md 四个待确认事项未锁定就进入设计阶段

- **描述**：`idea.md` 的"待确认事项"列出了 4 个关键决策点（真题入口位置、表结构选择、AI 结构化范围、初始数据来源），均标注"Step 3 完成后追加"，但"确认方案"部分为空。在决策未锁定的情况下进入实现，极可能导致返工。
- **影响**：开发过程中需要频繁回退和重做，浪费工时。
- **建议修复**：在开始任何编码前，必须锁定这四个决策并写入"确认方案"部分。特别是第 2 条（表结构选择）直接影响 DB migration 和模型层设计。
