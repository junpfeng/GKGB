# 考试日历与报名管家 - 开发日志

## 实现概要

基于 `idea.md` 确认方案（23 条锁定决策 + 3 项待细化），完整实现考试日历与报名管家功能。

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/exam_calendar_event.dart` | 考试日历事件模型（含 8 个日期字段、tryParseDate 容错、nextMilestone 计算） |
| `lib/models/user_registration.dart` | 用户报名信息模型 |
| `lib/services/notification_service.dart` | 通知服务单例（Android 系统通知 / Windows SnackBar 降级） |
| `lib/services/calendar_service.dart` | 日历业务服务（CRUD + 通知调度 + 月事件查询 + 预置数据导入） |
| `lib/screens/exam_calendar_screen.dart` | 日历主页（table_calendar 月视图 + 列表 + 考试类型/省份/关注筛选） |
| `lib/screens/exam_calendar_detail_screen.dart` | 详情页（倒计时 + 纵向时间线 + 报名信息编辑 + 删除） |
| `lib/screens/exam_calendar_edit_screen.dart` | 添加/编辑表单（名称、类型、省份、8 个日期选择器、公告链接） |
| `assets/data/exam_calendar_sample.json` | 预置考试数据（2025 国考 + 7 省考 + 选调 + 事业编联考，共 10 条） |

## 修改文件

| 文件 | 变更 |
|------|------|
| `pubspec.yaml` | 新增 table_calendar、flutter_local_notifications、timezone 依赖 + asset 引用 |
| `lib/db/database_helper.dart` | DB v5→v6，新增 exam_calendar + user_registrations 表 + 4 个索引 |
| `lib/main.dart` | 注册 CalendarService Provider + NotificationService 初始化 + 预置数据导入 |
| `lib/screens/stats_screen.dart` | 概览 Tab 顶部新增考试日历入口卡片 |

## 锁定决策落实

### 数据层（决策 1-4, 19-20, 23）
- exam_calendar 表含 16 个字段，含 updated_at（决策 19）
- user_registrations 表 calendar_id 加 UNIQUE 约束（决策 20）
- DB version 6，_createDB 和 _onUpgrade 同步更新
- 4 个索引：idx_exam_calendar_date、idx_exam_calendar_type、idx_exam_calendar_filter（决策 23）、idx_user_registrations_calendar

### 服务层（决策 5-6, 15-18, 21-22）
- CalendarService extends ChangeNotifier，无外部 Service 依赖（决策 5）
- NotificationService 单例，Platform.isAndroid 判断，Windows SnackBar 降级（决策 6, 15）
- 通知 ID = calendarId * 10 + reminderType（0-9）（决策 16）
- deleteExam 事务内删除 registrations + 取消通知（决策 17）
- loadMonthEvents 查询所有 8 个日期字段（决策 18）
- 预置数据幂等导入，表非空跳过（决策 21）
- 日期解析 tryParseDate try-catch 容错（决策 22）

### UI 层（决策 7-12）
- StatsScreen 概览 Tab 顶部渐变入口卡片（决策 7）
- 月视图 + 筛选栏（类型/省份/关注）+ FAB 添加（决策 8）
- 详情页：倒计时 + 纵向时间线（绿=已过/橙=即将/蓝=未来/灰=未设置）+ 报名信息编辑（决策 9）
- 添加/编辑表单，8 个日期选择器（决策 10）
- CalendarService Provider 在 main.dart 注册（决策 12）

### 待细化补充
- Windows 通知降级：NotificationService 内 Platform.isAndroid 判断，Windows 端不调度系统通知，提供 showInAppNotification 方法
- 预置数据：10 条样本（2025 国考、山东/广东/江苏/浙江/四川/河南省考、中央选调、上下半年事业编联考）
- 时间线 UI：纵向时间轴，4 种状态颜色（绿=past、橙=upcoming 7天内、蓝=future、灰=unset）

## 验证结果

- `flutter analyze` — No issues found
- `flutter test` — All 37 tests passed
- 所有验收标准均满足
