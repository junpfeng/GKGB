# Adversarial Review: exam_entry_scores_data

审查对象: `docs/features/exam_entry_scores_data/idea.md` 确认方案
审查日期: 2026-04-08

---

## 检查清单

### 1. 分层依赖 — PASS

方案严格遵循 screens -> services -> db/models 方向。Service 层新增 `loadFromAssets()` 读取 asset 并写入 SQLite，Screen 层仅移除 UI 元素，不引入反向依赖。Python 爬取工具在 `tools/` 目录，完全隔离于 Flutter 工程。

### 2. Provider 正确性 — WARN

**问题**: `ExamEntryScoreService` 当前在 `main.dart:154` 通过 `ChangeNotifierProvider(create: (_) => ExamEntryScoreService())` 注册，即在 `runApp` 内部惰性创建。

方案要求 `loadFromAssets()` 在 app 启动时执行（main.dart 初始化流程中异步执行，不阻塞 UI）。但如果沿用现有注册方式，service 实例在 `runApp` 之后才创建，无法在 `runApp` 之前调用 `loadFromAssets()`。

项目中其他预导入服务（CalendarService、HotTopicService、IdiomService）的模式是：在 `runApp` 之前创建实例 + 执行导入 + 通过 `ChangeNotifierProvider.value(value: ...)` 注入。

**建议**: 实现时需将 ExamEntryScoreService 改为与 IdiomService 相同的模式：

```dart
// main.dart runApp 之前
final entryScoreService = ExamEntryScoreService();
await entryScoreService.loadFromAssets();

// MultiProvider 中
ChangeNotifierProvider.value(value: entryScoreService),
```

方案文档应明确这一注册方式变更，避免实现时遗漏。

### 3. SQLite 迁移 — PASS

`exam_type` 列定义为 `TEXT NOT NULL`（database_helper.dart:463），添加 `'事业编'` 作为新值无需 schema 变更。表版本保持 v13 正确。UNIQUE 约束 `(province, city, year, exam_type, position_code, department)` 可正常容纳新 examType 值。`batchUpsertEntryScores` 使用 `INSERT OR REPLACE`，与 asset 导入场景兼容。

### 4. API Key 安全 — PASS (N/A)

本功能移除 Dio 网络爬取，改为纯本地 asset 读取，不涉及任何 API Key 或网络凭证。

### 5. LLM 抽象 — PASS (N/A)

本功能不涉及 LLM 调用。

### 6. 平台适配 — PASS

`rootBundle.loadString` 是 Flutter framework API，Windows 和 Android 平台行为一致。项目已有 7+ 处使用此模式（question_service.dart、real_exam_service.dart、calendar_service.dart、hot_topic_service.dart、idiom_service.dart 等），无平台问题。

---

## 补充审查

### 移除 fetchScores/Dio 的影响面 — PASS

`fetchScores()` 仅在两处被调用：
- `exam_entry_score_service.dart:167` — 定义处
- `exam_entry_scores_screen.dart:597` — `_doFetch` 中调用

`isFetching` 状态仅在 Screen 的 AppBar 按钮中使用（第 79、87 行），与 `_showFetchDialog` 一起移除即可。

`importScores()` 仅在 service 内部定义（第 289 行），无外部调用者。可安全移除。

`Dio` import 仅在 `exam_entry_score_service.dart:2`，移除不影响其他文件。

**结论**: 移除爬取相关代码不会破坏任何外部依赖。

### 数据量与启动时间 — WARN

**问题**: 方案说"首次启动导入不阻塞 UI"，但 main.dart 现有模式（calendarService、hotTopicService、idiomService）都是 `await` 同步等待导入完成后才 `runApp`。如果进面分数线数据量较大（数万条），首次启动会有可感知的等待。

**建议**: 
- 如果数据量 < 5000 条，沿用现有 `await` 模式即可，简单可靠
- 如果数据量 > 10000 条，考虑在 `runApp` 后异步导入（但需处理用户在导入完成前进入分数线页面的空状态）
- 方案应明确预期数据规模，以便选择合适策略

### 验收标准完整性 — PASS

验收标准覆盖了：工具存在性、运行时爬取移除、asset 存在、pubspec 注册、事业编支持、首次导入方法、测试通过、analyze 通过、手动验证。覆盖充分。

---

## 总结

| 检查项 | 结论 |
|--------|------|
| 分层依赖 | PASS |
| Provider 正确性 | WARN — 需明确注册方式从 `create` 改为 `value` |
| SQLite 迁移 | PASS |
| API Key 安全 | PASS (N/A) |
| LLM 抽象 | PASS (N/A) |
| 平台适配 | PASS |
| 移除影响面 | PASS |
| 数据量/启动时间 | WARN — 需明确预期数据规模 |

无 CRITICAL 问题。2 个 WARN 建议在实现前确认。
