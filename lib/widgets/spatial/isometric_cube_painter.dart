import 'dart:math';
import 'package:flutter/material.dart';
import 'face_pattern_painter.dart';

/// 正方体面数据
class CubeFace {
  final String position; // front, back, top, bottom, left, right
  final String pattern; // circle, triangle, arrow_up, cross, star, diamond
  final Color color;

  const CubeFace({
    required this.position,
    required this.pattern,
    required this.color,
  });

  factory CubeFace.fromJson(Map<String, dynamic> json) {
    return CubeFace(
      position: json['position'] as String,
      pattern: json['pattern'] as String,
      color: _parseColor(json['color'] as String? ?? '#888888'),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

/// 等轴测正方体绘制器
/// 使用 2.5D 等轴测投影绘制正方体，支持各面图案
class IsometricCubePainter extends CustomPainter {
  final List<CubeFace> faces;
  final double rotationX; // 弧度
  final double rotationY; // 弧度
  final double cubeSize;

  IsometricCubePainter({
    required this.faces,
    this.rotationX = 0.5, // ~30度
    this.rotationY = 0.78, // ~45度
    this.cubeSize = 120,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 计算等轴测投影的三个可见面
    // 根据旋转角度决定哪三个面可见
    final cosX = cos(rotationX);
    final sinX = sin(rotationX);
    final cosY = cos(rotationY);
    final sinY = sin(rotationY);

    final s = cubeSize;

    // 正方体 8 个顶点（以中心为原点）
    final vertices = <List<double>>[
      [-s/2, -s/2, -s/2], // 0: 左上后
      [ s/2, -s/2, -s/2], // 1: 右上后
      [ s/2,  s/2, -s/2], // 2: 右下后
      [-s/2,  s/2, -s/2], // 3: 左下后
      [-s/2, -s/2,  s/2], // 4: 左上前
      [ s/2, -s/2,  s/2], // 5: 右上前
      [ s/2,  s/2,  s/2], // 6: 右下前
      [-s/2,  s/2,  s/2], // 7: 左下前
    ];

    // 旋转并投影到 2D
    List<Offset> projected = vertices.map((v) {
      return _project(v[0], v[1], v[2], cosX, sinX, cosY, sinY);
    }).toList();

    // 6 个面的顶点索引和对应面信息
    final faceDefinitions = <_FaceDef>[
      _FaceDef('front',  [4, 5, 6, 7]), // z+ 前面
      _FaceDef('back',   [1, 0, 3, 2]), // z- 后面
      _FaceDef('top',    [0, 1, 5, 4]), // y- 顶面
      _FaceDef('bottom', [7, 6, 2, 3]), // y+ 底面
      _FaceDef('right',  [5, 1, 2, 6]), // x+ 右面
      _FaceDef('left',   [0, 4, 7, 3]), // x- 左面
    ];

    // 计算每个面的法向量 z 分量（用于背面剔除）
    List<_DrawFace> drawFaces = [];
    for (final def in faceDefinitions) {
      final p0 = projected[def.indices[0]];
      final p1 = projected[def.indices[1]];
      final p2 = projected[def.indices[2]];

      // 叉积 z 分量（正值朝向观察者）
      final cross = (p1.dx - p0.dx) * (p2.dy - p0.dy) -
                     (p1.dy - p0.dy) * (p2.dx - p0.dx);

      if (cross > 0) {
        // 面朝向观察者，可见
        final faceData = _findFace(def.position);
        final pts = def.indices.map((i) => projected[i]).toList();
        drawFaces.add(_DrawFace(
          points: pts,
          face: faceData,
          depth: cross,
          position: def.position,
        ));
      }
    }

    // 按深度排序（先画远的）
    drawFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // 绘制可见面
    for (final df in drawFaces) {
      _drawFace(canvas, df);
    }

    canvas.restore();
  }

  /// 3D 点旋转后投影到 2D
  Offset _project(double x, double y, double z,
      double cosX, double sinX, double cosY, double sinY) {
    // 绕 Y 轴旋转
    final x1 = x * cosY - z * sinY;
    final z1 = x * sinY + z * cosY;
    // 绕 X 轴旋转
    final y1 = y * cosX - z1 * sinX;
    // 正交投影（忽略 z）
    return Offset(x1, y1);
  }

  /// 查找面数据
  CubeFace? _findFace(String position) {
    for (final f in faces) {
      if (f.position == position) return f;
    }
    return null;
  }

  /// 绘制单个面（填色 + 边框 + 图案）
  void _drawFace(Canvas canvas, _DrawFace df) {
    final path = Path()..moveTo(df.points[0].dx, df.points[0].dy);
    for (int i = 1; i < df.points.length; i++) {
      path.lineTo(df.points[i].dx, df.points[i].dy);
    }
    path.close();

    // 面底色（半透明）
    final baseColor = df.face?.color ?? Colors.grey;
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 边框
    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);

    // 图案
    if (df.face != null) {
      canvas.save();
      canvas.clipPath(path);
      final bounds = path.getBounds();
      FacePatternPainter.drawPattern(
        canvas,
        df.face!.pattern,
        bounds,
        baseColor.withValues(alpha: 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(IsometricCubePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.cubeSize != cubeSize ||
        oldDelegate.faces != faces;
  }
}

class _FaceDef {
  final String position;
  final List<int> indices;
  const _FaceDef(this.position, this.indices);
}

class _DrawFace {
  final List<Offset> points;
  final CubeFace? face;
  final double depth;
  final String position;
  const _DrawFace({
    required this.points,
    required this.face,
    required this.depth,
    required this.position,
  });
}
