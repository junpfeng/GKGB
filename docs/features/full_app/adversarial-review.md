# 对抗性架构审查 — 确认方案红队攻击

审查对象：`docs/features/full_app/idea.md` 确认方案
审查基准：`.claude/rules/constitution.md` 工程宪法 + 现有代码库
审查日期：2026-04-07

---

## 1. 分层违反

### ADV-01: DatabaseHelper 单例被 Service 层绕过的风险未封堵 [severity: HIGH]

**攻击路径**: 方案声明"扩展 DatabaseHelper 添加 CRUD 方法"，但 DatabaseHelper 是裸单例（`DatabaseHelper.instance`），任何 Screen 都能直接 `import 'db/database_helper.dart'` 并调用 CRUD，绕过 Service 层。

**现有代码佐证**: `main.dart` 已将 `DatabaseHelper` 注册为 `Provider<DatabaseHelper>.value`，这意味着任何 Screen 都可以通过 `context.read<DatabaseHelper>()` 直接访问数据库。这直接违反宪法的 **screens -> services -> db/models** 分层约束。

**建议**: 
- 从 `MultiProvider` 中移除 `Provider<DatabaseHelper>`，不将 DatabaseHelper 暴露给 Screen 层
- 如果 Service 层需要 DatabaseHelper，通过构造函数注入或在 Service 内部直接引用单例
- 添加 lint 规则或文档约定：`screens/` 目录下禁止 import `db/` 路径

### ADV-02: LlmManager 非 ChangeNotifier，Provider 注册语义不匹配 [severity: HIGH]

**攻击路径**: 方案声明 "LlmManager 作为 `Provider<LlmManager>` 注册"，但 LlmManager 当前不是 ChangeNotifier。当用户在 LlmSettingsScreen 切换默认模型或添加新 Provider 时，依赖 LlmManager 的 UI（如刷题页的 AI 讲解按钮状态）无法感知变更。

**建议**: 
- 要么让 LlmManager 继承 ChangeNotifier 并在 setDefault/registerProvider 时 notifyListeners
- 要么引入独立的 LlmConfigService(ChangeNotifier) 来管理配置状态，LlmManager 只做调用路由

### ADV-03: Service 层之间的依赖方向未定义 [severity: LOW]

**攻击路径**: MatchService 需要读取 ProfileService 的用户画像做匹配；StudyPlanService 可能需要 QuestionService 的错题数据生成计划。方案未说明 Service 之间是否允许互相依赖、谁依赖谁。

**建议**: 明确 Service 间的依赖图，禁止循环依赖。推荐通过构造函数注入使依赖关系显式化。

---

## 2. 状态管理缺陷

### ADV-04: 5 个 ChangeNotifier 的 Provider 注册顺序和依赖关系未设计 [severity: HIGH]

**攻击路径**: 方案声明 main.dart 注册 QuestionService, ExamService, ProfileService, MatchService, StudyPlanService。但这些 Service 之间有依赖关系（如 ExamService 需要 QuestionService 的题目数据），MultiProvider 中的 ChangeNotifierProvider 无法直接引用其他 Provider 的实例，需要用 ChangeNotifierProxyProvider 或 ProxyProvider。

**方案遗漏**: 未说明哪些 Service 需要注入其他 Service，也未说明使用 ProxyProvider 还是构造函数传参。

**建议**: 
- 绘制 Service 依赖图
- 依赖其他 Service 的使用 `ChangeNotifierProxyProvider`
- 无依赖的使用普通 `ChangeNotifierProvider`

### ADV-05: dispose 清理未考虑 [severity: LOW]

**攻击路径**: ExamService 有计时功能（Timer），StudyPlanService 可能有定时刷新逻辑。如果这些 ChangeNotifier 在 dispose 时未清理 Timer/StreamSubscription，会导致内存泄漏。

**建议**: 方案中对包含异步资源（Timer、StreamSubscription、Dio CancelToken）的 Service 明确 dispose 策略。

### ADV-06: LlmManager streamChat 的 fallback 机制缺失 [severity: HIGH]

**攻击路径**: 现有 `LlmManager.streamChat()` 无 fallback 逻辑（只有 `chat()` 有）。宪法要求 "LLM 调用使用 Stream 模式展示"，意味着主路径就是 streamChat。当主模型流式调用失败时，不会降级到 fallback 模型。

**建议**: 为 streamChat 补充 fallback 逻辑，在 Stream 出错时切换到 fallback provider 重新发起流式请求。

---

## 3. 数据完整性

### ADV-07: 数据库 schema 缺少 exam 表，但方案有 Exam model [severity: CRITICAL]

**攻击路径**: 方案声明 "新增 models: Question, **Exam**, UserAnswer..."，但现有 database_helper.dart 的 10 张表中没有 `exams` 表。ExamService 需要持久化"考试配置、历史成绩"，没有表就无法存储。方案同时声明 "数据库不变更（schema 已完整）"，这与需要 Exam 表的需求矛盾。

**建议**: 
- 要么新增 `exams` 表（记录 exam_id, subject, total_questions, score, time_limit, started_at, finished_at），这意味着数据库需要版本升级
- 要么放弃 Exam model 的持久化，用内存态管理考试过程，但历史成绩就无法查询

### ADV-08: user_answers 表缺少 exam_id 关联 [severity: HIGH]

**攻击路径**: 模拟考试场景下，同一道题可能在多次考试中被回答。当前 user_answers 表无法区分"日常刷题的答题"和"某次模拟考试的答题"，导致无法按考试维度统计成绩。

**建议**: user_answers 表增加 nullable 的 `exam_id` 字段，日常刷题为 null，模拟考试关联具体考试记录。

### ADV-09: options 字段存储为 TEXT 缺少序列化规范 [severity: HIGH]

**攻击路径**: questions 表的 `options` 字段是 TEXT，方案声明 Question model 的 options 是 `List<String>`。但未定义 TEXT <-> List<String> 的序列化格式（JSON array? 逗号分隔?）。同样的问题存在于 `certificates`、`target_cities`、`matched_items`、`risk_items`、`unmatched_items`、`subjects`、`baseline_scores`、`plan_data` 等多个 TEXT 字段。

**建议**: 统一规定所有 List/Map 类型字段使用 JSON 格式存储，并在 Model 层的 fromJson/toJson 中统一处理 `jsonDecode`/`jsonEncode` 转换。

### ADV-10: llm_config 表的 api_key_encrypted 字段与 flutter_secure_storage 方案矛盾 [severity: CRITICAL]

**攻击路径**: 方案声明 "新增 flutter_secure_storage 依赖，LlmConfigService 管理加密存储的 API Key"。但现有 llm_config 表有 `api_key_encrypted TEXT` 字段，暗示 API Key 会存入 SQLite。

宪法明确要求："API Key 使用 flutter_secure_storage 或等效加密方案存储，**禁止 SQLite 明文存储**"。

两种方案的冲突点：
1. 如果 API Key 存 flutter_secure_storage，那 llm_config 表的 `api_key_encrypted` 字段无意义
2. 如果 API Key 存 SQLite 的 `api_key_encrypted`，"encrypted" 是谁加密的？应用层自己加密再存入 SQLite 算不算"等效加密方案"？

**建议**: 明确选择一种方案并统一：
- 方案A（推荐）: API Key 仅存 flutter_secure_storage，llm_config 表删除 api_key_encrypted 字段，key 名使用 `llm_key_{provider_name}` 格式
- 方案B: 使用 AES 加密后存入 SQLite，但需要定义密钥管理策略（密钥存哪里？）

### ADV-11: 数据库版本升级路径缺失 [severity: HIGH]

**攻击路径**: 当前数据库 version=1，`openDatabase` 只有 `onCreate` 回调没有 `onUpgrade`。如果需要新增 exams 表（ADV-07）或修改字段，没有迁移路径。方案声明"数据库不变更"，但已有 schema 实际上不满足需求。

**建议**: 在 DatabaseHelper 中添加 `onUpgrade` 回调，采用增量 migration 模式（switch-case version 逐级升级）。

### ADV-12: favorites 表缺少唯一约束 [severity: LOW]

**攻击路径**: favorites 表没有 `UNIQUE(question_id)` 约束，同一题目可以被多次收藏，产生重复数据。

**建议**: 添加 `UNIQUE(question_id)` 约束，或在 Service 层做去重检查。

---

## 4. 安全

### ADV-13: flutter_secure_storage 在 Windows 平台的加密能力受限 [severity: CRITICAL]

**攻击路径**: 项目同时支持 Windows 和 Android。`flutter_secure_storage` 在 Android 使用 EncryptedSharedPreferences（AES），安全性较高。但在 Windows 上使用 `wincred.h`（Windows Credential Manager），存储大小有限（单条 credential 最大约 512 字节），且用户登录 Windows 后可通过 Credential Manager GUI 明文查看。

此外，方案还需声明 `flutter_secure_storage` 的 Windows 依赖：需要 CMake 配置和 `flutter_secure_storage_windows` 插件。

**建议**: 
- 在 Windows 平台评估使用 DPAPI 加密后存入本地文件作为替代方案
- 或接受 Windows Credential Manager 的安全级别（文档中明示风险）
- 测试单个 API Key 加上 provider 配置是否超出 wincred 存储限制

### ADV-14: LLM Provider 实现可能在异常日志中泄露 API Key [severity: HIGH]

**攻击路径**: 5 个 LLM Provider 都使用 Dio 发起 HTTP 请求。Dio 的默认日志拦截器（`LogInterceptor`）会打印完整的 request headers，其中包含 `Authorization: Bearer {api_key}`。如果开发者添加了日志拦截器用于调试，API Key 会出现在控制台日志中，违反宪法 "禁止在日志中输出用户 API Key"。

**建议**: 
- 在 LLM Provider 的 Dio 实例中禁止添加 LogInterceptor，或自定义拦截器过滤 Authorization header
- 在 Dio 基础配置中统一添加 header 脱敏逻辑

### ADV-15: Ollama Provider 默认 localhost 在 Android 不可达 [severity: HIGH]

**攻击路径**: 方案定义 OllamaProvider 的 baseUrl 为 `http://localhost:11434`。在 Android 模拟器中，localhost 指向模拟器自身而非宿主机（需用 `10.0.2.2`）。在 Android 真机上，localhost 更是完全不可达。

**建议**: 
- OllamaProvider 的 baseUrl 必须由用户在设置页配置，不使用硬编码默认值
- 或根据 Platform.isAndroid 自动替换为 `10.0.2.2`（仅适用于模拟器，真机仍需手动配置）
- 在 LlmSettingsScreen 对 Ollama 显示提示："Android 设备请填写电脑的局域网 IP"

---

## 5. 性能

### ADV-16: 题库 JSON assets 全量加载到内存 [severity: HIGH]

**攻击路径**: 方案声明示例题库通过 JSON assets 内置。首次启动时需要解析 JSON 并导入 SQLite。如果后续题库增长（每科 5-10 题只是 MVP），一次性 `rootBundle.loadString()` + `jsonDecode()` 全部 JSON 会阻塞 UI 线程。

**建议**: 
- 题库导入操作放在 `compute()` isolate 中执行
- 添加导入进度指示
- 考虑分文件加载（每科一个 JSON，按需导入）

### ADV-17: 缺少关键索引定义 [severity: HIGH]

**攻击路径**: 宪法要求 "SQLite 查询必须建立适当索引，题库查询响应 < 100ms"。但现有 _createDB 中没有创建任何索引。主要查询场景缺失索引：

- `questions` 表按 `subject`/`category` 筛选：缺少 `INDEX(subject, category)`
- `user_answers` 表按 `question_id` 查询错题：缺少 `INDEX(question_id)`
- `user_answers` 表按 `answered_at` 排序查历史：缺少 `INDEX(answered_at)`
- `daily_tasks` 表按 `plan_id, task_date` 查今日任务：缺少 `INDEX(plan_id, task_date)`
- `positions` 表按 `policy_id` 查岗位：缺少 `INDEX(policy_id)`
- `match_results` 表按 `position_id` 查匹配结果：缺少 `INDEX(position_id)`

**建议**: 在 _createDB 中补充所有必要索引的 CREATE INDEX 语句。

### ADV-18: 匹配引擎可能触发 N+1 查询 [severity: HIGH]

**攻击路径**: MatchService 的两级匹配流程：先查所有公告，再查每个公告下的岗位，再对每个岗位做匹配计算。如果实现为 `for policy in policies { for position in getPositions(policy.id) { ... } }`，就是典型的 N+1 查询。

**建议**: 
- 批量查询：一次性 JOIN 查出 policies + positions
- 或使用 `WHERE policy_id IN (...)` 批量查询岗位
- 匹配计算如果涉及 LLM 调用，需要限流和并发控制

---

## 6. 平台一致性

### ADV-19: sqflite 在 Windows 平台的兼容性未确认 [severity: HIGH]

**攻击路径**: `sqflite` 包在 Windows 上需要 `sqflite_common_ffi` 来提供 FFI 实现。pubspec.yaml 当前只依赖 `sqflite: ^2.4.2`，未添加 `sqflite_common_ffi` 依赖。Windows 构建可能在运行时找不到 SQLite 动态库。

**建议**: 
- 添加 `sqflite_common_ffi` 依赖
- 在 main.dart 中根据 `Platform.isWindows` 初始化 `sqfliteFfiInit()` 和 `databaseFactoryFfi`
- 确保 Windows 构建包含 sqlite3.dll

### ADV-20: connectivity_plus 在 Windows 桌面端的行为差异 [severity: LOW]

**攻击路径**: pubspec.yaml 依赖 `connectivity_plus`，该包在 Android 上报告 wifi/cellular/none，在 Windows 桌面上可能行为不同（总是报告 ethernet/wifi）。如果代码中有基于连接类型的逻辑（如 cellular 下不自动同步），Windows 上可能永远不会触发。

**建议**: 方案中如果使用 connectivity_plus 做网络判断，统一使用 "有网/无网" 二元判断，不依赖具体连接类型。

### ADV-21: flutter_secure_storage 未在 pubspec.yaml 中声明 [severity: HIGH]

**攻击路径**: 方案声明 "新增 flutter_secure_storage 依赖"，但这是一个"待做"事项，不是当前状态。如果实现时遗漏添加依赖，编译会失败。更关键的是，flutter_secure_storage 在 Windows 平台需要额外的 `flutter_secure_storage_windows` 依赖。

**建议**: 确认 flutter_secure_storage 的 Windows 支持状态，必要时使用 `encrypt` 包 + DPAPI 作为 Windows 平台替代方案。

---

## 审查汇总

| Severity | 数量 | 编号 |
|----------|------|------|
| CRITICAL | 3 | ADV-07, ADV-10, ADV-13 |
| HIGH | 12 | ADV-01, ADV-02, ADV-04, ADV-06, ADV-08, ADV-09, ADV-11, ADV-14, ADV-15, ADV-16, ADV-17, ADV-18, ADV-19, ADV-21 |
| LOW | 4 | ADV-03, ADV-05, ADV-12, ADV-20 |

### CRITICAL 问题要求方案修订后才能进入实现阶段：

1. **ADV-07**: 必须决定是否新增 exams 表，并同步修改"数据库不变更"的声明
2. **ADV-10**: 必须明确 API Key 的唯一存储位置（flutter_secure_storage vs SQLite），消除矛盾
3. **ADV-13**: 必须评估 flutter_secure_storage 在 Windows 平台的可行性，必要时提供替代方案
