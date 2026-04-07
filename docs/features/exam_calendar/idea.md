# 考试日历与报名管家

## 核心需求
基于 `docs/advanced-features-design.md` 第五章，为考生提供考试日历（月视图+列表）、报名提醒（多级倒计时）、报名信息管理（准考证号、考场等）。

## 调研上下文

### 现有架构
- DB version = 5，11 个 Provider
- 5 个底部 Tab 已满（刷题/模考/岗位/统计/我的）
- 无日历或通知包（需新增 table_calendar + flutter_local_notifications）
- ProfileScreen 有 4 个菜单项（摸底测试、AI 设置、学习计划、关于）
- StudyPlan model 已有 examDate 字段，DailyTask 有 taskDate

### 可复用
- fl_chart 已有（可做倒计时可视化）
- GlassCard / GradientButton 样式组件
- Provider 注入模式已成熟

## 范围边界
- 做：考试日历（月视图+列表视图）、考试数据手动添加/编辑、报名信息管理、本地通知提醒、关注筛选
- 不做：AI 自动抓取公告（需爬虫，后续迭代）、报名资格预检（需复杂匹配逻辑）、成绩查询跳转

## 待确认事项
（见 Step 3）

## 确认方案

核心思路：新建考试日历表 + 报名信息表，使用 table_calendar 月视图展示考试时间线，flutter_local_notifications 实现多级提醒，在统计页顶部增加入口。

### 锁定决策

**数据层：**

1. 新增 `exam_calendar` 表：
   ```sql
   CREATE TABLE exam_calendar (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT NOT NULL,                -- 考试名称，如"2025年国考"
     exam_type TEXT NOT NULL,           -- 国考/省考/事业编/选调
     province TEXT DEFAULT '',          -- 省份（空表示全国）
     announcement_date TEXT,            -- 公告发布日期
     reg_start_date TEXT,               -- 报名开始
     reg_end_date TEXT,                 -- 报名截止
     payment_deadline TEXT,             -- 缴费截止
     ticket_print_date TEXT,            -- 准考证打印
     exam_date TEXT,                    -- 笔试日期
     score_release_date TEXT,           -- 成绩公布
     interview_date TEXT,               -- 面试日期
     source_url TEXT DEFAULT '',        -- 公告链接
     is_subscribed INTEGER DEFAULT 0,   -- 是否关注
     notes TEXT DEFAULT '',             -- 备注
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

2. 新增 `user_registrations` 表：
   ```sql
   CREATE TABLE user_registrations (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     calendar_id INTEGER NOT NULL,
     ticket_number TEXT DEFAULT '',      -- 准考证号
     exam_location TEXT DEFAULT '',      -- 考场地址
     seat_number TEXT DEFAULT '',        -- 座位号
     notes TEXT DEFAULT '',              -- 备注（证件、文具等）
     created_at TEXT DEFAULT CURRENT_TIMESTAMP,
     FOREIGN KEY (calendar_id) REFERENCES exam_calendar (id)
   )
   ```

3. DB version 5 → 6：
   - `_createDB` 同步添加 2 张新表 + 索引
   - `_onUpgrade` 中 `if (oldVersion < 6)` 事务包裹建表迁移

4. 新增索引：
   - `idx_exam_calendar_date ON exam_calendar(exam_date)`
   - `idx_exam_calendar_type ON exam_calendar(exam_type, province)`
   - `idx_user_registrations_calendar ON user_registrations(calendar_id)`

**服务层：**

5. 新增 `CalendarService extends ChangeNotifier`：
   - 无外部 Service 依赖，直接操作 DatabaseHelper
   - `loadMonthEvents(int year, int month)` → `Map<DateTime, List<ExamCalendarEvent>>`（日历标记用）
   - `loadUpcoming({limit: 20})` → 即将到来的考试列表
   - `addExam(ExamCalendarEvent)` / `updateExam` / `deleteExam`
   - `toggleSubscription(int id)` → 关注/取消关注
   - `loadSubscribed()` → 仅关注的考试
   - `getRegistration(int calendarId)` → 报名信息
   - `saveRegistration(UserRegistration)` → 保存报名信息
   - `scheduleReminders(ExamCalendarEvent)` → 设置本地通知
   - `cancelReminders(int calendarId)` → 取消通知

6. 新增 `NotificationService`（单例，非 ChangeNotifier）：
   - 封装 flutter_local_notifications 初始化 + 调度
   - `init()` — 在 main.dart 启动时初始化
   - `scheduleNotification(id, title, body, DateTime scheduledDate)`
   - `cancelNotification(id)` / `cancelAll()`
   - 通知 ID 规则：`calendarId * 100 + reminderType`（避免冲突）
   - 提醒规则：报名截止前 7/3/1 天 + 缴费截止前 3/1 天（共 5 条通知/考试）

**UI 层：**

7. 入口：StatsScreen 顶部增加「考试日历」入口卡片

8. 新增 `lib/screens/exam_calendar_screen.dart`：
   - 顶部：月视图日历（table_calendar），有考试的日期标记圆点
   - 日历下方：选中日期的考试列表 / 默认显示当月所有考试
   - 筛选栏：考试类型 + 省份 + 仅关注
   - FAB：添加考试按钮

9. 新增 `lib/screens/exam_calendar_detail_screen.dart`：
   - 考试详情页：8 个时间节点时间线可视化
   - 关注/取消关注按钮
   - 报名信息区（准考证号、考场地址、备注，可编辑）
   - 倒计时显示（距最近节点天数）

10. 新增 `lib/screens/exam_calendar_edit_screen.dart`：
    - 添加/编辑考试表单（名称、类型、省份、8 个日期选择器、公告链接）

11. 新增模型：
    - `lib/models/exam_calendar_event.dart` — ExamCalendarEvent
    - `lib/models/user_registration.dart` — UserRegistration

12. `CalendarService` Provider 在 `main.dart` 注册（ChangeNotifierProvider，无依赖）

13. 新增依赖：`table_calendar`、`flutter_local_notifications`

14. 预置考试数据 JSON：`assets/data/exam_calendar_sample.json`（2025 年国考 + 主要省考约 10 条）

**范围边界：**
- 做：月视图日历、手动添加/编辑考试、8 个时间节点、关注筛选、报名信息管理、本地通知提醒、预置数据
- 不做：AI 自动抓取公告、报名资格预检、成绩查询跳转、与学习计划联动

**红蓝对抗修正：**

15. Windows 通知降级：NotificationService 用 `Platform.isAndroid` 判断，Android 端用 flutter_local_notifications，Windows 端用应用内 SnackBar 提示（不引入额外包）

16. 通知 ID 公式：`calendarId * 10 + reminderType`（reminderType 0-9，避免 int32 溢出）

17. deleteExam 时同步删除 user_registrations + 取消所有通知

18. `loadMonthEvents` 查询所有 8 个日期字段（不仅 exam_date），任一日期落在月份范围内即纳入

19. exam_calendar 表追加 `updated_at TEXT DEFAULT CURRENT_TIMESTAMP`

20. user_registrations 表 calendar_id 加 `UNIQUE` 约束

21. 预置数据导入：检查表是否为空，非空跳过（幂等）

22. 日期字段解析 try-catch 容错，非法日期忽略

23. 追加索引 `idx_exam_calendar_filter ON exam_calendar(exam_type, province, is_subscribed)`

### 待细化
- flutter_local_notifications 的 Windows 端兼容性处理（方向：Windows 用条件编译或 stub 降级）
- 预置考试数据的具体内容（方向：2025 年国考 + 热门省考时间节点）
- 时间线可视化的 UI 细节（方向：纵向时间轴，节点颜色区分已过/即将/未来）

### 验收标准
- [mechanical] exam_calendar 表存在：判定 `grep -c "exam_calendar" lib/db/database_helper.dart` >= 1
- [mechanical] user_registrations 表存在：判定 `grep -c "user_registrations" lib/db/database_helper.dart` >= 1
- [mechanical] CalendarService 存在：判定 `ls lib/services/calendar_service.dart`
- [mechanical] NotificationService 存在：判定 `ls lib/services/notification_service.dart`
- [mechanical] 日历主页存在：判定 `ls lib/screens/exam_calendar_screen.dart`
- [mechanical] 详情页存在：判定 `ls lib/screens/exam_calendar_detail_screen.dart`
- [mechanical] 编辑页存在：判定 `ls lib/screens/exam_calendar_edit_screen.dart`
- [mechanical] 模型存在：判定 `ls lib/models/exam_calendar_event.dart lib/models/user_registration.dart`
- [mechanical] Provider 注册：判定 `grep "CalendarService" lib/main.dart`
- [mechanical] DB version 6：判定 `grep "version: 6" lib/db/database_helper.dart`
- [mechanical] 入口在 StatsScreen：判定 `grep -c "calendar\|日历" lib/screens/stats_screen.dart` >= 1
- [mechanical] table_calendar 依赖：判定 `grep "table_calendar" pubspec.yaml`
- [test] 全量测试通过：`flutter test`
- [mechanical] 零分析错误：`flutter analyze`
- [manual] 运行 `flutter run -d windows` 验证：统计页顶部出现日历入口，月视图可用，可添加考试，时间线展示正确
