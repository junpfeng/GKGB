# 开发日志：图形推理立体拼合可视化

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/spatial_visualization.dart` | 空间可视化数据模型 |
| `lib/services/spatial_viz_service.dart` | 空间可视化服务（查询+预置导入） |
| `lib/widgets/spatial/face_pattern_painter.dart` | 面图案绘制器（6种预定义图案） |
| `lib/widgets/spatial/isometric_cube_painter.dart` | 等轴测正方体绘制器（CustomPainter + 3D投影） |
| `lib/widgets/spatial/fold_animation_widget.dart` | 展开图→折叠动画组件 |
| `lib/widgets/spatial/spatial_player_widget.dart` | 播放控制器（步骤导航+解题思路） |
| `lib/screens/spatial_viz_screen.dart` | 全屏可视化播放器页面 |
| `assets/data/spatial_visualizations.json` | 3道示例预置数据 |

## 修改文件

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | v14→v15，新增 spatial_visualizations 表+索引 |
| `lib/main.dart` | 注册 SpatialVizService (#21)，启动时导入预置数据 |
| `lib/widgets/question_card.dart` | 新增 _SpatialVizButton 异步检查并显示"立体演示"按钮 |
| `pubspec.yaml` | 声明 spatial_visualizations.json asset |

## 关键决策

1. **2.5D 等轴测投影**：不引入 3D 引擎，用 CustomPainter + Matrix4 正交投影实现伪 3D 效果
2. **背面剔除**：通过叉积 z 分量判断面朝向，只绘制朝向观察者的面
3. **折叠动画**：用 Canvas scale 变换模拟透视折叠效果，而非真 3D 旋转
4. **异步按钮显示**：_SpatialVizButton 通过 FutureBuilder 模式异步检查数据库，无数据时返回 SizedBox.shrink()
5. **预置数据幂等导入**：通过 COUNT 检查实现幂等性，与 IdiomService 模式一致
