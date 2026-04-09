# 图形推理立体拼合可视化

## 核心需求
动态展示正方体展开图的折叠过程，配合解题思路点拨，帮助考生理解图形推理立体拼合题。

## 调研上下文
- 设计方案详见 `design.md`
- 参考粉笔 PC 端"立体图形切割"功能和抖音"画解图推"博主动态讲解
- 现有基础：判断推理题库完备，无空间可视化能力
- 代码库仅有 1 个 CustomPainter（progress_ring.dart），无 Matrix4 使用

## 范围边界
- 做：cube_fold 正方体折叠可视化、6 种预定义面图案、3 道示例数据、解题思路文字、全屏播放器
- 不做：cube_rotate/cut_section/assembly（v2）、手势旋转（v2）、LLM 自动生成配置、完整 3D 引擎

## 初步理解
通过 2.5D 等轴测投影 + CustomPainter + Matrix4 实现伪 3D 效果，逐步折叠动画展示展开图到正方体的过程。

## 待确认事项
无（已全部确认）

## 确认方案

方案摘要：图形推理立体拼合可视化

核心思路：CustomPainter + Matrix4 等轴测投影实现正方体折叠动画，配解题思路

### 锁定决策

数据层：
  - 数据模型：SpatialVisualization（简单模型，不用 json_serializable）
  - 数据库变更：新表 spatial_visualizations，v14→v15 迁移
  - 预置数据：assets/data/spatial_visualizations.json，启动时导入

服务层：
  - 新增服务：SpatialVizService（无依赖，仅用 DatabaseHelper）
  - LLM 调用：不涉及
  - 外部依赖：无新增 package

UI 层：
  - 新增页面：SpatialVizScreen（全屏播放器）
  - 状态管理：SpatialVizService 作为 ChangeNotifier 注册 Provider #21
  - 组件：lib/widgets/spatial/ 子目录 4 个组件

主要技术决策：
  - 题目筛选：仅靠 spatial_visualizations 表有记录，不改分类体系
  - Widget 组织：创建 spatial/ 子目录（与 ai_assistant/ 先例一致）
  - 解题思路：v1 包含每步文字说明

### 待细化
无

### 验收标准
  - [mechanical] 表存在：`grep "spatial_visualizations" lib/db/database_helper.dart`
  - [mechanical] 文件结构：`ls lib/widgets/spatial/`
  - [mechanical] Provider 注册：`grep "SpatialVizService" lib/main.dart`
  - [test] `flutter analyze` 零新增错误
  - [manual] 打开有可视化数据的题目，点击"立体演示"按钮，验证折叠动画和解题思路显示
