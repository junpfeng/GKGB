import 'dart:math';
import 'package:flutter/material.dart';
import 'face_pattern_painter.dart';
import 'isometric_cube_painter.dart';

/// 展开图→折叠动画组件
/// 控制正方体展开图的逐步折叠动画
class FoldAnimationWidget extends StatefulWidget {
  final List<CubeFace> faces;
  final List<int> foldSequence;
  final Map<String, double> answerRotation;
  final int currentStep; // -1: 初始展开图, 0~5: 折叠步骤, 6: 旋转到答案视角
  final VoidCallback? onStepComplete;

  const FoldAnimationWidget({
    super.key,
    required this.faces,
    required this.foldSequence,
    required this.answerRotation,
    required this.currentStep,
    this.onStepComplete,
  });

  @override
  State<FoldAnimationWidget> createState() => _FoldAnimationWidgetState();
}

class _FoldAnimationWidgetState extends State<FoldAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onStepComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(FoldAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStep != oldWidget.currentStep) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 计算总步骤数（展开图 + 折叠面数 + 旋转）
  int get totalFoldSteps => widget.faces.length;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final step = widget.currentStep;
        final progress = _animation.value;

        if (step < 0) {
          // 展开图状态
          return _buildUnfoldedView();
        } else if (step < totalFoldSteps) {
          // 折叠过程中：渐变到正方体视图
          return _buildFoldingView(step, progress);
        } else {
          // 折叠完成，旋转到答案视角
          return _buildRotatingView(progress);
        }
      },
    );
  }

  /// 绘制平面展开图（十字形排列）
  Widget _buildUnfoldedView() {
    return CustomPaint(
      size: const Size(300, 400),
      painter: _UnfoldedCubePainter(faces: widget.faces),
    );
  }

  /// 折叠过程中的中间状态
  Widget _buildFoldingView(int step, double progress) {
    // 计算已折叠面的折叠角度
    final foldAngles = <int, double>{};
    for (int i = 0; i < totalFoldSteps; i++) {
      if (i < step) {
        foldAngles[i] = pi / 2; // 已完全折叠
      } else if (i == step) {
        foldAngles[i] = progress * pi / 2; // 正在折叠
      }
      // 未折叠的面不加入
    }

    return CustomPaint(
      size: const Size(300, 400),
      painter: _FoldingCubePainter(
        faces: widget.faces,
        foldAngles: foldAngles,
        foldSequence: widget.foldSequence,
      ),
    );
  }

  /// 折叠完成后旋转到答案视角
  Widget _buildRotatingView(double progress) {
    // 默认视角
    const defaultRotX = 0.5; // ~30度
    const defaultRotY = 0.78; // ~45度

    final targetRotX = (widget.answerRotation['x'] ?? 30) * pi / 180;
    final targetRotY = (widget.answerRotation['y'] ?? 45) * pi / 180;

    final rotX = defaultRotX + (targetRotX - defaultRotX) * progress;
    final rotY = defaultRotY + (targetRotY - defaultRotY) * progress;

    return CustomPaint(
      size: const Size(300, 400),
      painter: IsometricCubePainter(
        faces: widget.faces,
        rotationX: rotX,
        rotationY: rotY,
        cubeSize: 120,
      ),
    );
  }
}

/// 展开图绘制器（十字形排列 6 个面）
class _UnfoldedCubePainter extends CustomPainter {
  final List<CubeFace> faces;

  const _UnfoldedCubePainter({required this.faces});

  @override
  void paint(Canvas canvas, Size size) {
    final faceSize = min(size.width / 4, size.height / 5) * 0.9;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final gap = 3.0;

    // 十字形排列：
    //     [top]
    // [left][bottom][right]
    //     [front]
    //     [back]
    // bottom 在中心
    final positions = <String, Offset>{
      'top':    Offset(centerX, centerY - (faceSize + gap)),
      'left':   Offset(centerX - (faceSize + gap), centerY),
      'bottom': Offset(centerX, centerY),
      'right':  Offset(centerX + (faceSize + gap), centerY),
      'front':  Offset(centerX, centerY + (faceSize + gap)),
      'back':   Offset(centerX, centerY + 2 * (faceSize + gap)),
    };

    for (final face in faces) {
      final pos = positions[face.position];
      if (pos == null) continue;

      final rect = Rect.fromCenter(
        center: pos,
        width: faceSize,
        height: faceSize,
      );

      // 面底色
      final fillPaint = Paint()
        ..color = face.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // 边框
      final borderPaint = Paint()
        ..color = face.color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, borderPaint);

      // 图案
      FacePatternPainter.drawPattern(canvas, face.pattern, rect, face.color);

      // 面名称标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: _positionLabel(face.position),
          style: TextStyle(
            color: face.color.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(rect.right - textPainter.width - 2, rect.bottom - textPainter.height - 2),
      );
    }
  }

  String _positionLabel(String pos) {
    return switch (pos) {
      'front' => '前',
      'back' => '后',
      'top' => '顶',
      'bottom' => '底',
      'left' => '左',
      'right' => '右',
      _ => pos,
    };
  }

  @override
  bool shouldRepaint(_UnfoldedCubePainter oldDelegate) => false;
}

/// 折叠过程绘制器
/// 展示从展开图到正方体的中间状态
class _FoldingCubePainter extends CustomPainter {
  final List<CubeFace> faces;
  final Map<int, double> foldAngles; // 面索引 → 折叠角度（0~π/2）
  final List<int> foldSequence;

  const _FoldingCubePainter({
    required this.faces,
    required this.foldAngles,
    required this.foldSequence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final faceSize = min(size.width / 4, size.height / 5) * 0.9;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final gap = 3.0;

    // 底面始终保持平面绘制
    final bottomFace = faces.firstWhere(
      (f) => f.position == 'bottom',
      orElse: () => faces.first,
    );

    // 绘制底面
    final bottomRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: faceSize,
      height: faceSize,
    );
    _drawFlatFace(canvas, bottomFace, bottomRect);

    // 根据折叠角度绘制其他面
    // 折叠顺序对应 faces 中非 bottom 的面
    final otherFaces = faces.where((f) => f.position != 'bottom').toList();

    for (int i = 0; i < otherFaces.length; i++) {
      final face = otherFaces[i];
      final angle = foldAngles[i]; // 当前折叠角度

      if (angle == null) {
        // 尚未开始折叠，在展开位置绘制
        final pos = _unfoldedPosition(face.position, centerX, centerY, faceSize, gap);
        final rect = Rect.fromCenter(center: pos, width: faceSize, height: faceSize);
        _drawFlatFace(canvas, face, rect);
      } else {
        // 正在折叠或已完成折叠
        _drawFoldingFace(canvas, face, angle, centerX, centerY, faceSize, gap);
      }
    }
  }

  /// 展开位置
  Offset _unfoldedPosition(String position, double cx, double cy, double faceSize, double gap) {
    return switch (position) {
      'top'   => Offset(cx, cy - (faceSize + gap)),
      'left'  => Offset(cx - (faceSize + gap), cy),
      'right' => Offset(cx + (faceSize + gap), cy),
      'front' => Offset(cx, cy + (faceSize + gap)),
      'back'  => Offset(cx, cy + 2 * (faceSize + gap)),
      _       => Offset(cx, cy),
    };
  }

  /// 绘制折叠中的面（使用透视变换模拟）
  void _drawFoldingFace(Canvas canvas, CubeFace face, double angle,
      double cx, double cy, double faceSize, double gap) {
    canvas.save();

    // 根据面的位置确定折叠轴和方向
    final foldRatio = angle / (pi / 2); // 0~1

    switch (face.position) {
      case 'front':
        // 从底面下方向上折
        final baseY = cy + faceSize / 2;
        canvas.translate(cx, baseY);
        // 用缩放模拟透视效果
        final scaleY = cos(angle);
        final translateY = -sin(angle) * faceSize * 0.3;
        canvas.translate(0, translateY);
        canvas.scale(1.0, max(0.05, scaleY));
        final rect = Rect.fromCenter(
          center: Offset(0, -faceSize / 2),
          width: faceSize,
          height: faceSize,
        );
        _drawFlatFace(canvas, face, rect, opacity: 1.0 - foldRatio * 0.3);

      case 'top':
        // 从底面上方向下折
        final baseY = cy - faceSize / 2;
        canvas.translate(cx, baseY);
        final scaleY = cos(angle);
        final translateY = sin(angle) * faceSize * 0.3;
        canvas.translate(0, translateY);
        canvas.scale(1.0, max(0.05, scaleY));
        final rect = Rect.fromCenter(
          center: Offset(0, faceSize / 2),
          width: faceSize,
          height: faceSize,
        );
        _drawFlatFace(canvas, face, rect, opacity: 1.0 - foldRatio * 0.3);

      case 'right':
        // 从底面右侧向左折
        final baseX = cx + faceSize / 2;
        canvas.translate(baseX, cy);
        final scaleX = cos(angle);
        final translateX = -sin(angle) * faceSize * 0.3;
        canvas.translate(translateX, 0);
        canvas.scale(max(0.05, scaleX), 1.0);
        final rect = Rect.fromCenter(
          center: Offset(-faceSize / 2, 0),
          width: faceSize,
          height: faceSize,
        );
        _drawFlatFace(canvas, face, rect, opacity: 1.0 - foldRatio * 0.3);

      case 'left':
        // 从底面左侧向右折
        final baseX = cx - faceSize / 2;
        canvas.translate(baseX, cy);
        final scaleX = cos(angle);
        final translateX = sin(angle) * faceSize * 0.3;
        canvas.translate(translateX, 0);
        canvas.scale(max(0.05, scaleX), 1.0);
        final rect = Rect.fromCenter(
          center: Offset(faceSize / 2, 0),
          width: faceSize,
          height: faceSize,
        );
        _drawFlatFace(canvas, face, rect, opacity: 1.0 - foldRatio * 0.3);

      case 'back':
        // 后面：先移到 front 之后的位置，然后折
        final baseY = cy + faceSize / 2;
        canvas.translate(cx, baseY);
        final scaleY = cos(angle);
        final translateY = -sin(angle) * faceSize * 0.5;
        canvas.translate(0, translateY);
        canvas.scale(1.0, max(0.05, scaleY));
        final rect = Rect.fromCenter(
          center: Offset(0, -faceSize / 2),
          width: faceSize,
          height: faceSize,
        );
        _drawFlatFace(canvas, face, rect, opacity: 1.0 - foldRatio * 0.3);
    }

    canvas.restore();
  }

  /// 绘制平面状态的面
  void _drawFlatFace(Canvas canvas, CubeFace face, Rect rect, {double opacity = 1.0}) {
    final fillPaint = Paint()
      ..color = face.color.withValues(alpha: 0.25 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    final borderPaint = Paint()
      ..color = face.color.withValues(alpha: 0.7 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);

    FacePatternPainter.drawPattern(
      canvas,
      face.pattern,
      rect,
      face.color.withValues(alpha: 0.9 * opacity),
    );
  }

  @override
  bool shouldRepaint(_FoldingCubePainter oldDelegate) {
    return oldDelegate.foldAngles != foldAngles;
  }
}
