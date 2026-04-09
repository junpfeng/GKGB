import 'dart:math';
import 'package:flutter/material.dart';

/// 正方体面图案绘制器
/// 在给定矩形区域内绘制预定义的几何图案
class FacePatternPainter {
  /// 在 canvas 上绘制指定图案
  static void drawPattern(
    Canvas canvas,
    String pattern,
    Rect rect,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = rect.center;
    final size = min(rect.width, rect.height) * 0.4;

    switch (pattern) {
      case 'circle':
        canvas.drawCircle(center, size, paint);
      case 'triangle':
        _drawTriangle(canvas, center, size, paint);
      case 'arrow_up':
        _drawArrowUp(canvas, center, size, paint);
      case 'cross':
        _drawCross(canvas, center, size, strokePaint..strokeWidth = size * 0.3);
      case 'star':
        _drawStar(canvas, center, size, paint);
      case 'diamond':
        _drawDiamond(canvas, center, size, paint);
      default:
        canvas.drawCircle(center, size * 0.3, paint);
    }
  }

  static void _drawTriangle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.866, center.dy + size * 0.5)
      ..lineTo(center.dx - size * 0.866, center.dy + size * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawArrowUp(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      // 箭头头部
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.6, center.dy - size * 0.2)
      ..lineTo(center.dx + size * 0.25, center.dy - size * 0.2)
      // 箭头杆
      ..lineTo(center.dx + size * 0.25, center.dy + size)
      ..lineTo(center.dx - size * 0.25, center.dy + size)
      ..lineTo(center.dx - size * 0.25, center.dy - size * 0.2)
      // 回到左翼
      ..lineTo(center.dx - size * 0.6, center.dy - size * 0.2)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawCross(Canvas canvas, Offset center, double size, Paint paint) {
    // 竖线
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
    // 横线
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
  }

  static void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const points = 5;
    final outerRadius = size;
    final innerRadius = size * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / points) - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  static void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size * 0.7, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }
}
