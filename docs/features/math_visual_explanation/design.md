# 数量关系可视化解题 设计方案

## 1. 背景

数量关系是行测中最难的模块，抽象的数学推导让很多考生望而却步。用户参考了抖音"秒懂数理"——通过动画将数学问题变得直观易懂。

**现有基础**：`MasterQuestionService` 已支持母题标记和分类，`PracticeScreen` 有母题 Tab。但缺少可视化解题能力。

## 2. 数据模型

### 2.1 新表：`visual_explanations`（可视化解题步骤）

```sql
CREATE TABLE visual_explanations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id INTEGER NOT NULL,
  explanation_type TEXT NOT NULL,  -- 'equation_walkthrough' / 'bar_animation' / 'number_line' / 'diagram'
  steps_json TEXT NOT NULL,        -- JSON 数组：逐步可视化配置
  template_id TEXT DEFAULT '',     -- 可视化模板标识
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (question_id) REFERENCES questions (id),
  UNIQUE(question_id)
);
```

### 2.2 steps_json 结构

每个步骤包含叙述文字、视觉类型和参数：

```json
[
  {
    "step": 1,
    "narration": "设甲的效率为 x，乙的效率为 y",
    "visual_type": "equation_setup",
    "params": {"equations": ["x + y = 1/10", "x = 2y"]},
    "highlight": "variable_intro"
  },
  {
    "step": 2,
    "narration": "将 x = 2y 代入第一个方程",
    "visual_type": "equation_substitute",
    "params": {"from": "x = 2y", "into": "x + y = 1/10", "result": "3y = 1/10"}
  },
  {
    "step": 3,
    "narration": "解得 y = 1/30，即乙每天完成 1/30",
    "visual_type": "equation_solve",
    "params": {"result": "y = 1/30", "meaning": "乙每天完成全部工作的 1/30"}
  }
]
```

**visual_type 枚举**：
- `equation_setup` — 列方程/设未知数
- `equation_substitute` — 代入消元
- `equation_solve` — 求解
- `bar_fill` — 进度条填充（工程问题）
- `bar_compare` — 进度条对比
- `number_line_move` — 数轴移动（行程问题）
- `number_line_meet` — 数轴相遇
- `pie_split` — 饼图分割（比例问题）
- `highlight_result` — 最终结果高亮

## 3. Service 设计

**新文件：`lib/services/visual_explanation_service.dart`**

```dart
class VisualExplanationService extends ChangeNotifier {
  // 获取已有的可视化解题
  Future<VisualExplanation?> getExplanation(int questionId);

  // AI 生成：将题目和答案发给 LLM，要求输出结构化 steps_json
  Future<VisualExplanation> generateExplanation(int questionId);

  // 导入预置可视化数据
  Future<void> importPresetData();

  // 获取可用模板列表（按母题类型）
  List<String> getTemplatesForType(String masterQuestionType);
}
```

依赖：`DatabaseHelper`、`LlmManager`

### 3.1 AI 生成策略

发送题目 + 正确答案给 LLM，要求按固定 `visual_type` 枚举输出结构化 JSON。LLM 负责内容生成，CustomPainter 负责渲染。

**LLM Prompt 要点**：
- 提供 visual_type 枚举及每种类型的 params 格式
- 要求叙述文字简洁，每步不超过 20 字
- 要求步骤数控制在 3-8 步

## 4. UI 设计

### 4.1 可视化播放器组件

```
lib/widgets/visual/
├── visual_player_widget.dart     # 播放控制器（上一步/播放暂停/下一步）
├── equation_painter.dart         # 方程推导：高亮代入、消元过程
├── bar_progress_painter.dart     # 工程问题：进度条填充动画
├── number_line_painter.dart      # 行程问题：数轴上的相遇/追及
└── pie_painter.dart              # 比例问题：饼图分割动画
```

### 4.2 播放器 UI 布局

- 顶部：题目文本（可折叠）
- 中部：`CustomPainter` 画布区域，通过 `AnimationController` 控制步骤切换动画
- 底部：步骤说明文字 + 播放控制栏（上一步 / 播放暂停 / 下一步）+ 速度调节

### 4.3 入口点

`QuestionCard` 答案揭示区域，对数量关系题目显示"可视化解题"按钮（仅当该题有 visual_explanation 数据时）。

## 5. 技术方案

**关键决策**：使用 Flutter `CustomPainter` + `AnimationController` 实现逐步动画，**不使用 3D 渲染引擎**。

- 每种 `visual_type` 对应一个 Painter 实现
- 步骤间通过 Tween 动画平滑过渡
- v1 支持 3 种模板：
  - **方程推导**（覆盖大部分题型，约 60% 母题）
  - **进度条**（工程问题）
  - **数轴**（行程问题）
- 预置 10-20 道母题的可视化数据，其余可通过 AI 按需生成

## 6. 集成

### 6.1 DB 迁移

在 `database_helper.dart` 的 `onUpgrade` 中新增 1 张表。

### 6.2 Provider 注册

```dart
// main.dart — 需要 LlmManager，使用 ProxyProvider
ChangeNotifierProxyProvider<LlmManager, VisualExplanationService>(
  create: (_) => VisualExplanationService(db),
  update: (_, llm, service) => service!..updateLlm(llm),
),
```

### 6.3 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | 新增 1 张表 |
| `lib/main.dart` | 注册 VisualExplanationService |
| `lib/widgets/question_card.dart` | 数量关系题目新增"可视化解题"按钮 |

## 7. 复杂度与分期

**复杂度：高**

CustomPainter 动画框架是全新开发，需要：
- 设计通用的步骤播放引擎
- 为每种模板实现 Painter + 动画逻辑
- LLM prompt 工程确保输出格式正确

**建议拆分为两期**：
- **一期**：方程推导模板 + 播放器框架（覆盖 60% 母题）
- **二期**：进度条 + 数轴 + 饼图 + 更多模板
