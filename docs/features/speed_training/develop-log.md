# 速算训练功能 — 实现日志

## 实现日期
2026-04-08

## 新增/修改文件列表

### 新增文件
| 文件 | 说明 |
|------|------|
| `lib/models/speed_calc_exercise.dart` | 速算练习题数据模型（json_serializable + 手写 fromDb/toDb） |
| `lib/models/speed_calc_exercise.g.dart` | json_serializable 生成代码 |
| `lib/models/speed_training_session.dart` | 训练会话数据模型（json_serializable + 手写 fromDb/toDb） |
| `lib/models/speed_training_session.g.dart` | json_serializable 生成代码 |
| `lib/services/speed_training_service.dart` | 速算训练服务（ChangeNotifier） |
| `lib/screens/speed_training_screen.dart` | 速算训练页面（首页/训练中/训练结束 3 视图） |
| `assets/data/speed_calc_preset.json` | 预置速算练习题 210 题 |
| `docs/features/speed_training/develop-log.md` | 本文件 |

### 修改文件
| 文件 | 说明 |
|------|------|
| `lib/db/database_helper.dart` | 新增 3 张表（speed_calc_exercises / speed_training_sessions / speed_training_answers）+ 4 个索引 |
| `lib/main.dart` | 注册 SpeedTrainingService Provider + 启动时导入预置数据 |
| `lib/screens/practice_screen.dart` | 添加速算训练入口卡片 |
| `lib/screens/dashboard_screen.dart` | 添加每日速算挑战提示卡片 |
| `pubspec.yaml` | 注册 `assets/data/speed_calc_preset.json` |
| `docs/app-architecture.md` | 同步更新模型清单、数据库表、预置数据、功能模块总览 |

## 关键决策说明

### 1. 数据库版本
idea.md 记录的"v14→v15"已过时，实际 DB 版本在本功能实现前已升至 v19（其他功能的迁移）。速算训练的 3 张表在 v18→v19 迁移中已建立（与 visual_explanations 表同批次），无需额外版本升级。

### 2. 数据模型双轨序列化
模型同时提供 `@JsonSerializable` 生成的 `fromJson/toJson` 和手写的 `fromDb/toDb`。前者用于 JSON 导入导出，后者用于 SQLite 字段映射（snake_case 列名）。保持与 idea.md 锁定决策一致。

### 3. 自定义计算器键盘（内联实现）
未创建独立的 `calculator_keyboard.dart` widget，而是在 `SpeedTrainingScreen` 内部实现 `_buildCalculatorKeyboard()` 方法。原因：
- 键盘仅在速算训练中使用，无复用场景
- 键盘需要直接访问 `_onKeyInput` 回调和当前题目类型状态
- 避免不必要的抽象层（遵循宪法：不为单次使用创建组件）

### 4. 增长率比较题键盘
`growth_rate_compare` 类型的题目仅显示 A/B 两个大按钮，而非完整数字键盘。自动检测当前题目类型切换键盘模式。

### 5. Windows 物理键盘支持
通过 `Focus + onKeyEvent` 监听物理键盘事件（数字键 0-9、小数点、退格、回车、A/B），仅在 `Platform.isWindows || Platform.isLinux` 时启用。Android 端仅显示自定义虚拟键盘。

### 6. Dashboard 集成方式
遵循锁定决策"不修改 DashboardService 依赖链"，在 DashboardScreen UI 层通过 `context.read<SpeedTrainingService>().hasTodayChallenge()` 直接查询，使用 FutureBuilder 异步渲染。今日挑战已完成则隐藏提示卡片。

### 7. 预置数据 210 题分布
5 种 calc_type × 3 种难度 × 14 题 = 210 题。每种类型均匀分配，确保各难度级别有足够练习量。导入使用 `INSERT OR IGNORE` 依赖 `UNIQUE(calc_type, expression)` 约束实现幂等。

### 8. 算法生成引擎
Service 提供 `generateExercise(calcType, difficulty)` 方法，可在预置题用尽后动态生成新题。每日挑战混合使用预置题（从 DB 随机取）和算法生成题，自选练习同理。

### 9. 单题限时
按难度分级：简单 45s / 中等 60s / 困难 90s。超时自动提交空答案并标记为错误。使用 Timer.periodic + dispose() 清理模式。

### 10. accuracy 字段语义
Session 的 accuracy 字段存储为小数（0~1），如 0.8 表示 80%。finishSession() 是唯一写入点，从 answers 表重新计算。

## 遇到的问题及解决

### 问题 1：数据库版本不一致
idea.md 记载 DB 版本为 v14，实际已升至 v19。在实现前通过 `Grep version:` 发现版本不一致，确认速算相关表已在先前的迁移中创建完成。

### 问题 2：json_serializable 与 DB 列名映射
`@JsonSerializable(fieldRename: FieldRename.snake)` 可以自动处理 camelCase→snake_case 转换，但 SQLite 查询返回的 Map 键为 snake_case，需确保 fromJson 能正确解析。最终采用双轨方案（fromJson + fromDb）确保两种场景都能正常工作。

## 验收清单

- [x] 3 张新表存在（speed_calc_exercises / speed_training_sessions / speed_training_answers）
- [x] 核心文件存在：service / screen / 2 个 model
- [x] Provider 注册在 main.dart
- [x] `flutter analyze` 零错误
- [x] `flutter test` 全部通过（54 tests）
- [x] PracticeScreen 速算训练入口卡片
- [x] DashboardScreen 每日挑战提示卡片
- [x] 预置数据 210 题，5 种类型均匀分配
- [x] 自定义计算器键盘 + Windows 物理键盘支持
- [x] 单题限时（45s/60s/90s 按难度分级）
