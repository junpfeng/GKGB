# 考试日历方案 - 红队对抗审查

审查对象：`docs/features/exam_calendar/idea.md` 确认方案（锁定决策 1-14）
审查基准：`.claude/rules/constitution.md` + 现有代码实态
审查日期：2026-04-07

---

## 严重问题（CRITICAL）

### C1. flutter_local_notifications 不支持 Windows 桌面端 [severity: CRITICAL]

**决策 6/13** 声称使用 `flutter_local_notifications` 实现本地通知，**待细化** 仅模糊提到"Windows 用条件编译或 stub 降级"，但未纳入锁定决策。

**事实**：`flutter_local_notifications` 的官方 platform support 不包含 Windows（仅 Android/iOS/macOS/Linux）。本项目是 Windows + Android 双平台应用。如果实现时才发现不可用，整个 NotificationService 的接口设计、通知 ID 规则（决策 6 的 `calendarId * 100 + reminderType`）、CalendarService 的 `scheduleReminders` / `cancelReminders` 方法都会受影响。

**攻击路径**：开发者按方案实现后，Windows 端运行直接崩溃或通知静默失败，用户无任何报名截止提醒，导致错过报名。

**改进建议**：
1. 将 NotificationService 的 Windows 降级策略提升为锁定决策，不能留在"待细化"。
2. 明确降级方案：Windows 端使用应用内倒计时横幅/弹窗 + 系统托盘气泡（`windows_notification` 或 `local_notifier` 包），Android 端走 `flutter_local_notifications`。
3. NotificationService 接口需抽象为平台策略模式（`NotificationStrategy`），而非单一实现内部 `if (Platform.isWindows)`。

---

### C2. user_registrations 外键无 ON DELETE CASCADE，删除考试后产生孤儿记录 [severity: CRITICAL]

**决策 2** 的 `user_registrations.calendar_id` 设置了 `FOREIGN KEY` 但未指定 `ON DELETE` 行为。SQLite 默认行为是 `NO ACTION`（且 SQLite 默认不启用外键约束检查，需 `PRAGMA foreign_keys = ON`）。

**攻击路径**：
1. 用户添加考试 A -> 添加报名信息 -> 删除考试 A
2. `user_registrations` 中残留孤儿行，`calendar_id` 指向不存在的记录
3. 详情页加载报名信息时，join 查询返回空或异常

**改进建议**：
1. 外键加 `ON DELETE CASCADE`
2. 在 DatabaseHelper 初始化时执行 `PRAGMA foreign_keys = ON`（当前代码未见此 PRAGMA）
3. 或在 CalendarService.deleteExam 中手动先删 registrations 再删 calendar（应用层兜底）

---

### C3. 通知 ID 规则存在数值溢出与碰撞风险 [severity: CRITICAL]

**决策 6** 规定通知 ID = `calendarId * 100 + reminderType`，每个考试最多 5 条通知。

**攻击路径**：
1. `flutter_local_notifications` 的通知 ID 是 32-bit int（Android `NotificationManager` 限制）
2. 当 `calendarId` 超过 21,474,836 时，`calendarId * 100` 溢出 32-bit int
3. 虽然短期数据量不会触达，但这是一个设计上的定时炸弹
4. 更现实的问题：如果未来 reminderType 超过 5 种（方案说 5 条/考试，但如果增加"准考证打印提醒"等），100 的间隔不够灵活

**改进建议**：
使用哈希映射或持久化通知 ID 表，而非算术公式。若坚持公式，至少用 `calendarId * 10 + reminderType`（10 种足够，且溢出阈值提升 10 倍）。

---

## 高优先级问题（HIGH）

### H1. exam_calendar 表缺少 updated_at 字段，与现有表约定不一致 [severity: HIGH]

**决策 1** 的 `exam_calendar` 表有 `created_at` 但无 `updated_at`。现有 `user_profile` 和 `llm_config` 表均有 `updated_at` 字段。考试日期可能调整（如公告延期），需要记录最后修改时间。

**改进建议**：增加 `updated_at TEXT DEFAULT CURRENT_TIMESTAMP` 字段。

---

### H2. user_registrations 缺少 updated_at，且无唯一约束防止重复报名 [severity: HIGH]

**决策 2** 的表结构允许同一 `calendar_id` 创建多条 registration 记录。方案中 `getRegistration(int calendarId)` 暗示一对一关系，但表结构未用 UNIQUE 约束。

**攻击路径**：并发操作或 UI bug 导致重复插入，`getRegistration` 返回不确定结果。

**改进建议**：`calendar_id` 加 `UNIQUE` 约束，或改为 `INSERT OR REPLACE` 语义。

---

### H3. CalendarService 直接操作 DatabaseHelper，绕过了现有 Service 层的通知调度耦合 [severity: HIGH]

**决策 5** 中 CalendarService 同时承担数据 CRUD 和通知调度（`scheduleReminders` / `cancelReminders`）。这违反了单一职责原则——CalendarService 是 ChangeNotifier（UI 状态），同时又在编排通知副作用。

**攻击路径**：
1. `updateExam` 修改了考试日期但忘记调用 `scheduleReminders` 重新调度
2. `deleteExam` 忘记调用 `cancelReminders`
3. 这些都是方案未明确的事务边界问题

**改进建议**：在 `addExam` / `updateExam` / `deleteExam` 的方法文档中明确要求：数据变更与通知调度在同一方法内原子完成。或在 Service 内部的 CRUD 方法中自动触发通知同步，禁止调用方手动编排。

---

### H4. loadMonthEvents 按月查询可能导致跨月考试遗漏 [severity: HIGH]

**决策 5** 的 `loadMonthEvents(int year, int month)` 按月加载日历标记。但一个考试有 8 个时间节点（公告发布 -> 面试），可能跨越多个月份。

**攻击路径**：国考公告 10 月发布，笔试 12 月，面试次年 3 月。用户查看 12 月日历时，只能看到 `exam_date` 在 12 月的标记，看不到报名截止（可能在 11 月）的提醒。

**改进建议**：查询条件应为"任意时间节点落在该月"，即 `WHERE announcement_date LIKE '2025-12%' OR reg_start_date LIKE '2025-12%' OR reg_end_date LIKE '2025-12%' OR ...`，或使用范围查询所有 8 个日期字段。

---

### H5. 预置数据 JSON 导入缺少去重和版本管理策略 [severity: HIGH]

**决策 14** 提到预置 `assets/data/exam_calendar_sample.json`，但未说明：
1. 何时导入（首次安装？每次启动？）
2. 如何去重（用户已手动添加同名考试时怎么办）
3. 版本更新时如何合并新数据

**攻击路径**：应用更新后重复导入，用户看到两条"2025年国考"记录。

**改进建议**：
1. 使用 SharedPreferences 记录已导入版本号
2. 导入时按 `(name, exam_type, exam_date)` 联合去重
3. 仅在 DB 新建或版本升级时触发导入

---

### H6. 8 个日期字段的 TEXT 存储无格式校验 [severity: HIGH]

**决策 1** 的 8 个日期字段（`announcement_date` 到 `interview_date`）均为 `TEXT` 类型，无格式约束。

**攻击路径**：用户通过编辑页输入非法日期格式（如 "下周三"、"2025/13/40"），导致日历组件解析崩溃、通知调度失败。

**改进建议**：
1. Model 层的 `fromJson` / `toJson` 使用 `DateTime` 类型，统一 ISO8601 格式
2. 编辑页的日期选择器使用 `showDatePicker`（方案已暗示但未明确要求），禁止手动输入

---

### H7. 索引策略未覆盖关注筛选的核心查询场景 [severity: HIGH]

**决策 4** 建了 3 个索引：`(exam_date)`、`(exam_type, province)`、`(calendar_id)`。
但 **决策 8** 的筛选栏支持 "考试类型 + 省份 + 仅关注"，核心查询是 `WHERE exam_type = ? AND province = ? AND is_subscribed = 1 ORDER BY exam_date`。

现有 `idx_exam_calendar_type ON (exam_type, province)` 不包含 `is_subscribed` 和 `exam_date`，无法作为覆盖索引。

**改进建议**：调整复合索引为 `(exam_type, province, is_subscribed, exam_date)` 以覆盖最常用的筛选+排序组合。

---

## 低优先级问题（LOW）

### L1. exam_type 使用自由 TEXT 而非枚举约束 [severity: LOW]

**决策 1** 的 `exam_type TEXT NOT NULL` 注释列了"国考/省考/事业编/选调"四种值，但无 CHECK 约束。不影响功能但会产生脏数据（如"国家公务员考试" vs "国考"）。

**改进建议**：在 Model 层使用 Dart enum 映射，Service 层存储时统一转换。

---

### L2. StatsScreen 入口位置与功能语义弱关联 [severity: LOW]

**决策 7** 将日历入口放在 StatsScreen 顶部。统计页的核心语义是"学习数据回顾"，日历的核心语义是"未来考试规划"。两者方向相反。

不过考虑到 5 个 Tab 已满且方案明确排除新增 Tab，这是可接受的折中。

**建议**：入口卡片应用明确的视觉区分（不同渐变色、图标），避免用户误以为是统计数据的一部分。

---

### L3. NotificationService 设计为单例但未注册到 Provider 树 [severity: LOW]

**决策 6** NotificationService 是"单例，非 ChangeNotifier"，**决策 12** 只注册 CalendarService 到 Provider。这意味着 NotificationService 游离在 Provider 体系之外。

当前项目的其他非 ChangeNotifier 服务（如 DatabaseHelper）也是单例直接访问，所以这与现有模式一致。但如果未来需要在 UI 层展示通知状态（如"已设置 3 条提醒"），需要额外的状态桥接。

**建议**：可接受，但在 CalendarService 中暴露通知状态（如 `int activeReminderCount`），避免 UI 直接访问 NotificationService。

---

### L4. 迁移 v5->v6 未提及回滚策略 [severity: LOW]

**决策 3** 描述了升级路径（`if (oldVersion < 6)` 事务建表），但 SQLite 不支持降级。如果迁移失败中途崩溃，事务回滚可保证原子性，这点方案已用事务包裹。但如果需要回退到旧版本应用，v6 的新表会残留。

**建议**：这是 SQLite 的固有限制，风险可接受。建议在迁移代码中使用 `CREATE TABLE IF NOT EXISTS` 以防重入。

---

## 确认无问题的部分

- **分层依赖方向**：CalendarService -> DatabaseHelper，Screen -> CalendarService，符合宪法 `screens -> services -> db/models` 约束。
- **Provider 注册模式**：决策 12 使用 `ChangeNotifierProvider` 无依赖注入，与现有 QuestionService、ProfileService 模式一致。
- **DB 版本迁移模式**：决策 3 的 `if (oldVersion < 6)` + 事务包裹，与 v4、v5 的迁移代码风格一致。
- **文件命名规范**：所有新文件名使用小写下划线，符合宪法代码风格。
- **模型层设计**：新增 `ExamCalendarEvent` / `UserRegistration` 放在 `lib/models/`，符合架构约束。
- **表结构索引**：基本覆盖了单表主查询场景（exam_date 排序、type+province 筛选、calendar_id 关联）。
- **范围边界**：明确排除了 AI 抓取、资格预检、成绩查询，避免了范围蔓延。
- **验收标准**：14 条 mechanical 检查 + 1 条 test + 1 条 manual，覆盖了所有锁定决策的交付物。
