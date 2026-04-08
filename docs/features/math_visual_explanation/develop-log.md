# 数量关系可视化解题 - 开发日志

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/visual_explanation.dart` | 数据模型：VisualExplanation + VisualStep + VisualType |
| `lib/services/visual_explanation_service.dart` | 服务层：DB CRUD、AI 生成、预置数据导入、内存缓存 |
| `lib/screens/visual_explanation_screen.dart` | 播放器页面：TickerProviderStateMixin + AnimationController |
| `lib/widgets/visual/equation_painter.dart` | 方程推导 CustomPainter：4 种 visual_type 绘制 |
| `lib/widgets/visual/visual_player_widget.dart` | 播放控制组件：步骤导航 + 速度调节 + 进度指示器 |
| `assets/data/visual_explanations.json` | 预置数据：5 道数量关系题的可视化步骤 |

## 修改文件

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | version 15→16，新增 `visual_explanations` 表 + 索引（_createDB + onUpgrade v16 + _createIndexes） |
| `lib/main.dart` | 新增 import + 启动时导入预置数据 + Provider.value 位置 22 |
| `lib/widgets/question_card.dart` | 数量关系题答案揭示后显示"可视化解题"按钮 |
| `pubspec.yaml` | 新增 `assets/data/visual_explanations.json` 资产声明 |

## 关键决策说明

### 1. DB 版本适配
v15 已被 political_theory 功能占用，visual_explanations 使用 v16。

### 2. Provider 位置适配
idea.md 假设位置 21，实际因其他功能已注册更多 Provider，最终注册在位置 22。

### 3. 模型序列化选择
遵循锁定决策，手写 `fromDb()`/`toDb()`（与 SpatialVisualization 模式一致），不使用 json_serializable。VisualStep 使用 `fromJson()` 解析 steps_json 内部 JSON。

### 4. Service 初始化模式
遵循 HotTopicService 模式：构造函数注入 LlmManager，`main()` 中 `await importPresetData()`，`ChangeNotifierProvider.value` 注册。

### 5. EquationPainter 绘制策略
- TextPainter 逐步绘制方程文本，支持颜色高亮（active/past/dim 三态）
- 当前步骤应用 animationProgress 透明度渐入效果
- 非一期 visual_type 降级为纯文本叙述显示（不崩溃）
- shouldRepaint 仅在 currentStep 或 animationProgress 变化时返回 true

### 6. 动画生命周期管理
Screen（StatefulWidget）持有 AnimationController，VisualPlayerWidget（StatelessWidget）接收动画值。dispose 时自动清理 Timer 和 Controller。

### 7. AI 生成流程
streamChat + join + timeout(30s)，返回后去除 markdown 包裹 → 提取 JSON 数组 → 校验必需字段 → visual_type 白名单过滤（非支持类型降级为 equation_setup）→ 存 DB + 更新内存缓存。

### 8. QuestionCard 入口策略
遵循锁定决策："所有数量关系题始终显示可视化解题按钮"。仅在 `showAnswer` 为 true 时显示（答案揭示后）。若无缓存且无 AI 模型配置，提示用户先配置。

## 遇到的问题及解决

### Flutter 命令不在 PATH 中
Windows 环境下 flutter 安装在 `C:\flutter\bin\`，bash shell 未自动加载。通过 `export PATH="/c/flutter/bin:$PATH"` 解决。

### 预置数据 question_id 映射
预置数据的 question_id 依赖于题目导入顺序。使用 `INSERT OR IGNORE` + `UNIQUE(question_id)` 约束保证幂等，即使 ID 不匹配也不会崩溃。

## 验收检查

- [x] `grep -r "class VisualExplanation" lib/models/` — 存在
- [x] `grep -r "class VisualExplanationService" lib/services/` — 存在
- [x] `grep -r "class VisualExplanationScreen" lib/screens/` — 存在
- [x] DB v19 迁移存在（`visual_explanations` 表）
- [x] Provider 已注册（`VisualExplanationService` in `main.dart`）
- [x] QuestionCard 入口存在（`可视化解题` 按钮）
- [x] `flutter test` — 54 tests passed
- [x] `flutter analyze` — 无新增 error（pre-existing `practice_screen.dart` 问题与本功能无关）
