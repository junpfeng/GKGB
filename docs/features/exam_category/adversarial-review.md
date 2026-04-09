# 考试类型差异化服务系统 红队审查报告

审查范围: `docs/features/exam_category/idea.md` 确认方案 + `docs/features/exam_category/design.md` 完整设计
审查基线: `.claude/rules/constitution.md` 架构约束

---

## 红队审查发现

### [CRITICAL] setTarget() 先写内存后写 DB，异常时内存/DB 状态不一致

设计 3.4 节描述 `setTarget()` 需要: 检查学习计划冲突 -> 暂停旧计划 -> 写入新目标 -> 更新内存状态 -> notifyListeners。这涉及多步 DB 写操作（暂停旧计划 status='paused' + 写入/替换 user_exam_targets 记录），但设计中没有任何事务（transaction）包裹。若暂停旧计划成功但写入新目标失败（如 UNIQUE 约束冲突），数据库将处于"旧计划已暂停但新目标未写入"的脏状态。

设计第 390 行明确写"先同步更新所有内存状态，再单次 notifyListeners()"，但未说明内存更新与 DB 写入的先后关系。若先更新内存再写 DB，DB 写入失败后内存已通知下游重建 UI，出现幽灵状态。

**建议修复**: setTarget() 中的"暂停旧计划 + 删除旧目标 + 插入新目标"三步必须包裹在单个 `db.transaction()` 中。内存状态更新和 notifyListeners() 必须在事务提交成功之后执行。增加 try-catch 回滚策略。

---

### [CRITICAL] ExamCategoryService 构造函数注入到下游 Service，但 Service 层持有引用读取 activeExamTypeValues 时无线程安全保证

设计 1.6 节明确: "Service 持有引用但不监听变更，每次方法调用时读取当前值即可"。但 ExamCategoryService 的 `_activeCategory`、`_activeSubType` 等字段在 `setTarget()` 中被异步修改（含 await DB 操作）。在 setTarget() 执行过程中，若下游 Service（如 DashboardService）同时调用 `activeExamTypeValues`，可能读到中间状态（_activeCategory 已更新但 _activeSubType 尚未更新）。

Dart 虽然是单线程事件循环，但 `setTarget()` 是 async 方法，每个 await 点都是潜在的中断点。如果 setTarget() 在 await DB 写入后、更新 `_activeSubType` 前让出执行权，此时 UI 重建触发的 Service 方法调用会读到不一致状态。

**建议修复**: 在 setTarget() 中，先完成所有 DB 操作，然后一次性（同步地）更新全部内存字段，最后 notifyListeners()。可以用一个局部变量暂存解析结果，所有 await 完成后再赋值给实例字段。或者增加一个 `_isUpdating` 锁标志，在更新期间让 getter 返回旧值。

---

### [HIGH] 学习计划冲突处理的"弹确认对话框"逻辑放在 Service 层违反分层约束

设计 3.4 节描述: "切换目标前，检查是否有 active 学习计划 -> 弹出确认对话框"。确认方案第 89 行也锁定了这一流程。但 `ExamCategoryService` 是 Service 层，根据 constitution.md 架构约束"screens -> services -> db/models，禁止反向依赖"，Service 层不应弹对话框（需要 BuildContext），也不应知道 UI 的存在。

如果在 ExamCategoryService.setTarget() 中触发对话框，要么需要传入 BuildContext（Service 依赖 UI），要么需要回调机制（增加复杂度）。设计文档未明确这个 UI 交互由谁发起。

**建议修复**: 将冲突检测拆为两步: (1) ExamCategoryService 提供 `Future<bool> hasConflictingPlan(String newExamCategoryId)` 纯查询方法; (2) Screen 层（ProfileScreen 或 ExamTargetScreen）调用此方法，若有冲突则自行弹对话框，用户确认后再调用 `setTarget(target, pauseExistingPlan: true)`。保持 Service 层无 UI 依赖。

---

### [HIGH] 探索模式使用魔法字符串 '__explore__' 作为 examCategoryId，缺乏类型安全

确认方案第 79 行锁定: "探索模式持久化: 写入特殊 UserExamTarget 记录（examCategoryId='__explore__'）"。这个魔法字符串散布在 DB 写入、loadTargets() 读取判断、条件路由等多处。若任何一处拼写错误（如 '_explore_'），探索模式将静默失效，用户被困在引导页循环中。

此外，`__explore__` 这个值会通过 `ExamCategoryRegistry` 查找时命中 null（Registry 中无此 id），设计 284 行的错误恢复逻辑"若 Registry 无法匹配已保存的 examCategoryId，自动清除该条目并进入探索模式"会把探索模式记录也当作无效数据清除，形成死循环: 写入探索标记 -> loadTargets() 发现无法匹配 -> 清除 -> 进入探索模式 -> 写入探索标记 -> ...

**建议修复**: (1) 将 `'__explore__'` 提取为 `ExamCategoryService` 的 static const 常量; (2) 在 loadTargets() 的错误恢复逻辑中，**先**检查是否为探索模式标记，**再**执行 Registry 匹配失败的清除逻辑，避免误清除; (3) 考虑替代方案: 用 SharedPreferences 存储一个 bool flag，而非污染 user_exam_targets 表。

---

### [HIGH] DB 查询 `OR exam_type = ''` 在大数据量下导致索引失效和全表扫描

设计 1.7 节的查询条件 `WHERE exam_type IN (?) OR exam_type = ''` 中的 OR 子句会导致 SQLite 查询优化器无法有效使用 exam_type 上的索引（如果有的话）。当 questions 表数据量增长（数万题目）时，每次刷题查询都会退化为全表扫描。

constitution.md 性能约束明确要求"题库查询响应 < 100ms"。这个 OR 模式在移动端（Android 低端机）上可能无法满足。

**建议修复**: 使用 UNION 替代 OR: `SELECT ... WHERE exam_type IN (?) UNION ALL SELECT ... WHERE exam_type = ''`，让两个分支各自使用索引。或者在 DB 迁移中做一次性数据修补，将 `exam_type = ''` 的历史题目补上对应的 exam_type 值（根据 subject 可推断），从而消除 OR 子句。

---

### [HIGH] ExamCategoryService 作为 ChangeNotifier 通过构造函数注入到下游 Service，但 dispose 时机未定义

设计 1.6 节说明 ExamCategoryService 通过 ChangeNotifierProvider 管理生命周期，并通过构造函数注入到多个下游 Service（StudyPlanService、DashboardService、AssistantService 等）。这些下游 Service 本身也是 ChangeNotifier，由 ChangeNotifierProxyProvider 管理。

问题在于: 如果 ExamCategoryService 的 ChangeNotifierProvider 因 widget 树重建而 dispose，但下游 Service 仍持有其引用并继续调用其 getter，会抛出 "A ChangeNotifier was used after being disposed" 异常。设计文档完全没有提到 dispose 相关的处理。

**建议修复**: (1) 确保 ExamCategoryService 在 Provider 列表中的位置早于所有依赖它的 Service（设计已提到"最前面注册"，需验证实现时确实如此）; (2) 下游 Service 在访问 ExamCategoryService 时增加空值/disposed 检查; (3) 在设计文档中明确 ExamCategoryService 的 dispose() 行为（如清理内存状态、取消未完成的 DB 操作）。

---

### [HIGH] UserExamTarget 模型的 isPrimary 字段为 int 类型，与 Dart 惯例不符且易误用

确认方案锁定 `isPrimary` 为 `int`（1=主目标）。json_serializable 默认不会将 int 自动转换为 bool，所有消费方都需要手写 `target.isPrimary == 1` 判断，而非 `target.isPrimary`。这在多处使用时容易出错（如误写 `if (target.isPrimary)` 在 Dart 中不会编译错误但永远为 true，因为非 null int 是 truthy...实际上 Dart 不允许 int 作为 bool 条件，所以这点倒是安全的）。

但更严重的问题是: SQLite 的 INTEGER 存储允许任意整数值。若某处错误地写入 `isPrimary = 2` 或 `isPrimary = -1`，查询 `WHERE is_primary = 1` 不会匹配，导致 v1 的"单主目标"语义被意外破坏。

**建议修复**: 在 UserExamTarget 模型中增加一个 `bool get isPrimaryTarget => isPrimary == 1;` 便利 getter，所有业务逻辑使用此 getter。在 setTarget() 写入时硬编码 isPrimary = 1，不接受外部传入。

---

### [HIGH] 条件路由使用 Consumer 在 app.dart 的 home 属性中，可能导致引导页与主页之间无过渡动画

设计 2.2 节的条件路由实现:
```dart
home: Consumer<ExamCategoryService>(
  builder: (ctx, service, _) {
    if (!service.hasTarget && !service.isExploreMode) {
      return const ExamTargetScreen();
    }
    return const HomeScreen();
  },
)
```

当用户在 ExamTargetScreen 选择目标后，ExamCategoryService.setTarget() 触发 notifyListeners()，Consumer 重建，直接从 ExamTargetScreen 切换到 HomeScreen。这是一个无动画的硬切换（widget 替换），用户体验突兀。更严重的是，ExamTargetScreen 中的 State 会被直接销毁（无 dispose 回调时机保证），如果 setTarget() 的 DB 写入尚未完成就触发了重建，可能出现状态异常。

**建议修复**: 使用 Navigator.pushReplacement 进行页面切换而非 Consumer 条件渲染。ExamTargetScreen 完成 setTarget() 后主动 `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()))`，这样有标准的页面过渡动画，且时序完全由 ExamTargetScreen 控制。app.dart 的 home 仅做初始判断。

---

### [HIGH] design.md 3.4 节学习计划冲突处理引入新的 status 枚举值 'paused' 但未更新相关查询

设计说"暂停的计划 status 设为 'paused'"，这是在现有 'active'/'completed' 基础上新增的值。但设计中未提及需要审查所有查询 study_plans 表的代码:
- 查询"当前活跃计划"的 `WHERE status = 'active'` 不受影响（正确排除 paused）
- 但查询"所有计划列表"的地方如果用 `WHERE status != 'completed'` 来找"进行中"的计划，会意外包含 paused 的计划
- 统计相关查询（如完成率计算）是否需要将 paused 视为特殊状态

**建议修复**: 在设计文档中明确列出所有涉及 study_plans.status 查询的代码位置，逐一确认 paused 状态的处理方式。建议在 StudyPlanService 中增加 `pausedPlans` getter 和相关查询方法。

---

### [LOW] SubjectCategory 的 iconCodePoint 和 iconFontFamily 字段将 Material Icons 的实现细节编码到静态注册表中

SubjectCategory 使用 `iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons'` 这种方式存储图标信息。这些 code point 值是 Flutter Material Icons 包的内部实现细节，在 Flutter 版本升级时可能发生变化（虽然概率低）。且这些魔法数字难以维护和审查（谁能直接看出 0xe25c 是什么图标？）。

设计原则第 3 条"纯数据模型: 模型层不包含 Flutter UI 类型（IconData/Color），UI 映射在视图层完成"是合理的。但当前方案本质上仍然是在模型层编码 UI 信息，只是换了一种表示形式（int 代替 IconData）。

**建议修复**: 使用语义化的字符串标识符（如 `iconName: 'calculate'`），在视图层的 SubjectCategoryUI 扩展中维护一个 `Map<String, IconData>` 映射表。这样模型层真正与 UI 解耦，且更易读。

---

### [LOW] 验收标准缺少对"切换目标后 DashboardService 缓存清除"的机械化验证

idea.md 验收标准仅覆盖文件存在性、Provider 注册、硬编码移除、手动场景测试。但设计中明确描述的关键行为"DashboardScreen 监听 ExamCategoryService 变更后调用 DashboardService.refreshDashboard(force: true) 强制刷新"没有对应的验收标准。如果实现时遗漏缓存清除，看板会显示旧目标的数据，这是一个严重的用户可见 bug。

**建议修复**: 增加验收标准: `[manual] 切换备考目标后看板数据立即刷新为新目标对应数据（雷达轴标签、统计数据均更新）`。

---

### [LOW] 设计方案未提及 Windows 与 Android 平台差异处理

constitution.md 要求"平台差异代码通过 Platform.isAndroid / Platform.isWindows 判断，集中在 services 层处理"。本设计涉及大量 UI 变更（引导页卡片布局、全局指示条、底部弹出 Sheet 选择子类型），但未提及桌面端与移动端的布局适配:
- ExamTargetScreen 的 7 张卡片在 Windows 宽屏上应该如何排列？
- 底部 Sheet 在 Windows 桌面端的交互是否合适（桌面端通常用 Dialog 而非 Bottom Sheet）
- ExamTypeBadge 指示条在桌面端窗口缩放时的行为

v2 延后列表中有"响应式布局"，但 v1 至少应保证不出现 Windows 端的布局溢出。

**建议修复**: 在设计中增加最小化的平台适配说明: ExamTargetScreen 使用 GridView 自适应列数（宽屏 3 列、窄屏 2 列）；子类型选择在 Windows 端使用 Dialog 替代 BottomSheet。

---

### [LOW] ExamCategoryRegistry 作为纯静态类，单元测试时无法 mock

设计 1.2 节将 Registry 定义为纯静态类（所有方法为 static）。这意味着依赖 Registry 的代码（ExamCategoryService.loadTargets() 中根据 examCategoryId 查找配置）无法在测试中替换 Registry 的行为。如果未来需要测试"Registry 中不存在某 id"的边界场景，只能依赖实际 Registry 不包含的 id 字符串。

**建议修复**: 可接受当前设计（v1 Registry 是稳定的静态数据，mock 需求低）。但建议在 ExamCategoryService 中将 Registry 查找抽象为一个可选的函数参数（`ExamCategory? Function(String id)? lookupFn`），默认使用 Registry，测试时可注入自定义查找逻辑。

---

## 确认无问题的部分

- **DB 迁移策略**: 仅新增 user_exam_targets 表，不修改现有表，v10->v11 路径清晰，零数据丢失风险。同时在 _createDB 中添加新表（新装用户路径）。
- **历史数据兼容**: `OR exam_type = ''` 的思路正确（虽然有性能问题需优化），确保老用户升级后数据不丢失。
- **分层设计**: ExamCategoryService 位于 Service 层，Screen 通过 Consumer/context.watch 访问，符合 screens -> services -> db/models 方向（学习计划冲突对话框除外）。
- **LLM 抽象遵守**: 设计中 AI 相关场景（StudyPlanService prompt 注入、AssistantService 上下文感知）均通过现有 LlmManager 通道，未绕过 LlmProvider 接口。
- **API Key 安全**: 本设计不涉及 API Key 处理，无泄露路径。
- **UNIQUE 约束**: user_exam_targets 表的 `UNIQUE(exam_category_id, sub_type_id, province)` 合理防止重复目标。
- **功能显隐机制**: 通过 `supportedFeatures` Set 控制入口可见性（非灰色禁用），用户体验合理。
- **SubType 预解析规则**: 确保 ExamSubType.subjects 始终非空，消费者无需实现回退逻辑，减少 null 检查散布。
