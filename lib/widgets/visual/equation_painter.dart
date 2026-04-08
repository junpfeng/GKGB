import 'package:flutter/material.dart';
import '../../models/visual_explanation.dart';

/// 方程推导 CustomPainter
/// 根据当前步骤和动画进度绘制方程推导过程
/// shouldRepaint 仅在 currentStep 或 animationProgress 变化时返回 true
class EquationPainter extends CustomPainter {
  final List<VisualStep> steps;
  final int currentStep;
  final double animationProgress; // 0.0 ~ 1.0，当前步骤的动画进度

  // 样式常量
  static const _titleFontSize = 14.0;
  static const _equationFontSize = 18.0;
  static const _lineSpacing = 36.0;
  static const _stepSpacing = 20.0;
  static const _horizontalPadding = 24.0;

  // 颜色定义
  static const _activeColor = Color(0xFF667eea);
  static const _highlightColor = Color(0xFFF7971E);
  static const _resultColor = Color(0xFF43E97B);
  static const _dimColor = Color(0xFF9E9E9E);
  static const _textColor = Color(0xFFE0E0E0);

  EquationPainter({
    required this.steps,
    required this.currentStep,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    double yOffset = 30;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isActive = i == currentStep;
      final isPast = i < currentStep;
      final isFuture = i > currentStep;

      // 未来步骤不绘制
      if (isFuture) break;

      // 当前步骤应用动画进度的透明度
      final opacity = isActive ? animationProgress.clamp(0.0, 1.0) : 1.0;

      // 根据 visual_type 选择绘制方式
      yOffset = _paintStep(canvas, size, step, yOffset, isActive, isPast, opacity);
      yOffset += _stepSpacing;
    }
  }

  double _paintStep(
    Canvas canvas,
    Size size,
    VisualStep step,
    double yOffset,
    bool isActive,
    bool isPast,
    double opacity,
  ) {
    // 步骤标号和叙述
    final narrationColor = isActive
        ? _activeColor.withValues(alpha: opacity)
        : isPast
            ? _textColor
            : _dimColor;

    yOffset = _drawText(
      canvas,
      '${step.step}. ${step.narration}',
      Offset(_horizontalPadding, yOffset),
      _titleFontSize,
      narrationColor,
      FontWeight.w600,
      maxWidth: size.width - _horizontalPadding * 2,
    );

    yOffset += 8;

    // 根据 visual_type 绘制不同内容
    switch (step.visualType) {
      case VisualType.equationSetup:
        yOffset = _paintEquationSetup(canvas, size, step, yOffset, isActive, opacity);
      case VisualType.equationSubstitute:
        yOffset = _paintEquationSubstitute(canvas, size, step, yOffset, isActive, opacity);
      case VisualType.equationSolve:
        yOffset = _paintEquationSolve(canvas, size, step, yOffset, isActive, opacity);
      case VisualType.highlightResult:
        yOffset = _paintHighlightResult(canvas, size, step, yOffset, isActive, opacity);
      default:
        // 非一期类型降级为纯文本叙述显示
        yOffset = _paintFallbackText(canvas, size, step, yOffset, opacity);
    }

    return yOffset;
  }

  /// 绘制方程设置（列方程）
  double _paintEquationSetup(
    Canvas canvas, Size size, VisualStep step,
    double yOffset, bool isActive, double opacity,
  ) {
    final equations = step.params['equations'] as List<dynamic>? ?? [];
    final color = isActive
        ? _activeColor.withValues(alpha: opacity)
        : _textColor;

    for (final eq in equations) {
      yOffset = _drawText(
        canvas,
        eq.toString(),
        Offset(_horizontalPadding + 16, yOffset),
        _equationFontSize,
        color,
        FontWeight.w500,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
      yOffset += _lineSpacing * 0.6;
    }

    // 步骤间连接箭头
    if (isActive && opacity > 0.5) {
      _drawArrow(canvas, size, yOffset);
      yOffset += 16;
    }

    return yOffset;
  }

  /// 绘制代入消元
  double _paintEquationSubstitute(
    Canvas canvas, Size size, VisualStep step,
    double yOffset, bool isActive, double opacity,
  ) {
    final from = step.params['from']?.toString() ?? '';
    final into = step.params['into']?.toString() ?? '';
    final result = step.params['result']?.toString() ?? '';

    final baseColor = isActive
        ? _activeColor.withValues(alpha: opacity)
        : _textColor;
    final highlightColorWithOpacity = isActive
        ? _highlightColor.withValues(alpha: opacity)
        : _highlightColor.withValues(alpha: 0.7);

    // "将 from 代入 into"
    if (from.isNotEmpty && into.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        '将 $from 代入 $into',
        Offset(_horizontalPadding + 16, yOffset),
        _titleFontSize,
        baseColor.withValues(alpha: 0.8),
        FontWeight.normal,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
      yOffset += _lineSpacing * 0.5;
    }

    // 结果方程高亮显示
    if (result.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        result,
        Offset(_horizontalPadding + 16, yOffset),
        _equationFontSize,
        highlightColorWithOpacity,
        FontWeight.bold,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
      yOffset += _lineSpacing * 0.6;
    }

    if (isActive && opacity > 0.5) {
      _drawArrow(canvas, size, yOffset);
      yOffset += 16;
    }

    return yOffset;
  }

  /// 绘制求解结果
  double _paintEquationSolve(
    Canvas canvas, Size size, VisualStep step,
    double yOffset, bool isActive, double opacity,
  ) {
    final result = step.params['result']?.toString() ?? '';
    final meaning = step.params['meaning']?.toString() ?? '';

    final resultColor = isActive
        ? _resultColor.withValues(alpha: opacity)
        : _resultColor.withValues(alpha: 0.8);

    // 求解结果
    if (result.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        result,
        Offset(_horizontalPadding + 16, yOffset),
        _equationFontSize + 2,
        resultColor,
        FontWeight.bold,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
      yOffset += _lineSpacing * 0.5;
    }

    // 含义说明
    if (meaning.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        meaning,
        Offset(_horizontalPadding + 16, yOffset),
        _titleFontSize,
        _textColor.withValues(alpha: isActive ? opacity * 0.9 : 0.7),
        FontWeight.normal,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
      yOffset += _lineSpacing * 0.4;
    }

    return yOffset;
  }

  /// 绘制最终结果高亮
  double _paintHighlightResult(
    Canvas canvas, Size size, VisualStep step,
    double yOffset, bool isActive, double opacity,
  ) {
    final answer = step.params['answer']?.toString() ?? '';
    final summary = step.params['summary']?.toString() ?? '';

    // 高亮背景框
    if (answer.isNotEmpty) {
      final boxPaint = Paint()
        ..color = _resultColor.withValues(alpha: isActive ? opacity * 0.15 : 0.1)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = _resultColor.withValues(alpha: isActive ? opacity * 0.6 : 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final boxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          _horizontalPadding,
          yOffset,
          size.width - _horizontalPadding * 2,
          60,
        ),
        const Radius.circular(12),
      );

      canvas.drawRRect(boxRect, boxPaint);
      canvas.drawRRect(boxRect, borderPaint);

      // 答案文字居中
      _drawTextCentered(
        canvas,
        answer,
        Offset(size.width / 2, yOffset + 18),
        _equationFontSize + 4,
        _resultColor.withValues(alpha: isActive ? opacity : 0.9),
        FontWeight.bold,
      );

      yOffset += 65;
    }

    // 总结文字
    if (summary.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        summary,
        Offset(_horizontalPadding + 8, yOffset),
        _titleFontSize,
        _textColor.withValues(alpha: isActive ? opacity * 0.9 : 0.7),
        FontWeight.normal,
        maxWidth: size.width - _horizontalPadding * 2 - 8,
      );
    }

    return yOffset;
  }

  /// 非一期类型降级为纯文本
  double _paintFallbackText(
    Canvas canvas, Size size, VisualStep step,
    double yOffset, double opacity,
  ) {
    final paramsText = step.params.entries
        .map((e) => '${e.value}')
        .join('  ');
    if (paramsText.isNotEmpty) {
      yOffset = _drawText(
        canvas,
        paramsText,
        Offset(_horizontalPadding + 16, yOffset),
        _equationFontSize,
        _textColor.withValues(alpha: opacity),
        FontWeight.normal,
        maxWidth: size.width - _horizontalPadding * 2 - 16,
      );
    }
    return yOffset;
  }

  /// 绘制文本，返回绘制后的 y 偏移
  double _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
    FontWeight fontWeight, {
    double maxWidth = double.infinity,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, offset);
    return offset.dy + textPainter.height;
  }

  /// 绘制居中文本
  void _drawTextCentered(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
    FontWeight fontWeight,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy),
    );
  }

  /// 绘制步骤间连接箭头
  void _drawArrow(Canvas canvas, Size size, double yOffset) {
    final paint = Paint()
      ..color = _activeColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, yOffset - 4),
      Offset(centerX, yOffset + 8),
      paint,
    );
    // 箭头
    final path = Path()
      ..moveTo(centerX - 4, yOffset + 4)
      ..lineTo(centerX, yOffset + 10)
      ..lineTo(centerX + 4, yOffset + 4);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(EquationPainter oldDelegate) {
    return currentStep != oldDelegate.currentStep ||
        animationProgress != oldDelegate.animationProgress;
  }
}
