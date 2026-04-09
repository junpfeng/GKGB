# 图形推理立体拼合可视化 设计方案

## 1. 背景

图形推理中的立体拼合题要求空间想象力，是考生公认最难的题型之一。用户参考了粉笔 PC 端的"立体图形切割"功能和抖音"画解图推"博主的动态讲解。

**核心诉求**：动态展示拼合/折叠过程，配合解题思路点拨。

**现有基础**：判断推理题库完备，但无任何空间可视化能力。

## 2. 数据模型

### 2.1 新表：`spatial_visualizations`（空间可视化配置）

```sql
CREATE TABLE spatial_visualizations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id INTEGER NOT NULL,
  viz_type TEXT NOT NULL,           -- 可视化类型（见下方枚举）
  config_json TEXT NOT NULL,        -- 可视化配置
  solving_approach TEXT DEFAULT '', -- 解题思路文字说明
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (question_id) REFERENCES questions (id),
  UNIQUE(question_id)
);
```

**viz_type 枚举**：
| 类型 | 说明 | v1 支持 |
|------|------|---------|
| `cube_fold` | 展开图折叠成正方体 | Yes |
| `cube_rotate` | 正方体旋转判断 | v2 |
| `cut_section` | 截面判断 | v2 |
| `assembly` | 多体拼合 | v2 |

### 2.2 config_json 结构

**cube_fold 展开折叠**：
```json
{
  "type": "cube_fold",
  "faces": [
    {"position": "front", "pattern": "circle", "color": "#E53935"},
    {"position": "top", "pattern": "triangle", "color": "#43A047"},
    {"position": "right", "pattern": "arrow_up", "color": "#1E88E5"},
    {"position": "back", "pattern": "cross", "color": "#FB8C00"},
    {"position": "bottom", "pattern": "star", "color": "#8E24AA"},
    {"position": "left", "pattern": "diamond", "color": "#00ACC1"}
  ],
  "fold_sequence": [0, 1, 2, 3, 4, 5],
  "answer_rotation": {"x": 30, "y": 45, "z": 0}
}
```

**face position 枚举**：`front`、`back`、`top`、`bottom`、`left`、`right`

**pattern 枚举**（v1 预定义 6 种）：`circle`、`triangle`、`arrow_up`、`cross`、`star`、`diamond`

### 2.3 新模型文件

- `lib/models/spatial_visualization.dart`

### 2.4 数据来源

> **不使用 LLM 自动生成**：立体可视化的 config_json 高度依赖对题目图片的精确理解，AI 无法可靠地从文字题目描述中推断正方体面的图案和位置。**所有可视化数据需人工标注**。

v1 目标：10-20 道手工标注的真题。

## 3. 技术方案

### 3.1 关键决策：2.5D 等轴测投影

**不使用完整 3D 引擎**。理由：
- Flutter 原生 3D 支持有限，引入 3D 引擎（如 `flutter_3d_controller`）增加包体积和复杂度
- 考试中的立体题以正方体为主，等轴测投影已足够表达
- `CustomPainter` + `Matrix4` 可实现伪 3D 旋转效果

### 3.2 动画流程（cube_fold）

1. 显示平面展开图（十字形排列的 6 个面）
2. 逐步折叠：底面固定，前后左右面依次竖起（`Transform.rotate` 动画）
3. 顶面最后盖上
4. 折叠完成后，旋转到答案选项的观察角度
5. 每步配有文字解说，如："注意：圆形面与十字面相对，不可能同时看到"

## 4. Service 设计

**新文件：`lib/services/spatial_viz_service.dart`**

```dart
class SpatialVizService extends ChangeNotifier {
  // 获取可视化配置
  Future<SpatialVisualization?> getVisualization(int questionId);

  // 导入预置可视化数据
  Future<void> importPresetData();

  // 检查某题是否有可视化数据
  Future<bool> hasVisualization(int questionId);
}
```

依赖：仅 `DatabaseHelper`（不需要 LLM）

## 5. UI 设计

### 5.1 新组件

```
lib/widgets/spatial/
├── isometric_cube_painter.dart    # 等轴测正方体绘制，支持各面图案
├── fold_animation_widget.dart     # 展开图→折叠动画（Transform + Matrix4）
├── face_pattern_painter.dart      # 面图案库：圆/三角/箭头/十字/星/菱形
└── spatial_player_widget.dart     # 播放控制器
```

### 5.2 全屏可视化播放器

- 深色背景，聚焦动画区域
- 顶部：题目文本（可折叠）
- 中部：CustomPainter 画布（占屏幕 60%）
- 下方：步骤控制栏（上一步 / 播放暂停 / 下一步）+ 当前步骤的解题思路文字

### 5.3 入口点

`QuestionCard` 中，对判断推理—图形推理类题目，当该题存在 `spatial_visualization` 数据时显示"立体演示"按钮。

## 6. 集成

### 6.1 DB 迁移

在 `database_helper.dart` 的 `onUpgrade` 中新增 1 张表。

### 6.2 Provider 注册

```dart
// main.dart — 不依赖 LLM
final spatialVizService = SpatialVizService(db);
await spatialVizService.importPresetData();

ChangeNotifierProvider.value(value: spatialVizService),
```

### 6.3 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | 新增 1 张表 |
| `lib/main.dart` | 注册 SpatialVizService |
| `lib/widgets/question_card.dart` | 图形推理题目新增"立体演示"按钮 |

## 7. 复杂度与范围控制

**极高复杂度**。CustomPainter 3D 投影和折叠动画是全新领域。

### v1 严格限定范围

- 仅支持正方体折叠（`cube_fold`）一种类型
- 6 种预定义面图案
- 10-20 道手工标注的真题
- 不支持手势旋转（固定视角 + 预设旋转角度）

### v2 扩展方向

- 正方体旋转判断（`cube_rotate`）
- 截面判断（`cut_section`）
- 手势自由旋转（双指缩放、单指拖动）
- 考虑引入 `flutter_3d_controller` 或 WebGL 方案
