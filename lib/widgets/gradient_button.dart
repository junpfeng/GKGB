import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 渐变按钮组件
/// 圆角胶囊形，蓝紫渐变背景，白色文字
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final LinearGradient? gradient;
  final double borderRadius;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.gradient,
    this.borderRadius = 12,
    this.width,
    this.padding,
    this.textStyle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AppTheme.primaryGradient;
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: isDisabled || isLoading ? null : onPressed,
      child: Container(
        width: width,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? const LinearGradient(
                  colors: [Color(0xFFB0B8CC), Color(0xFF9AA3B5)],
                )
              : grad,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: grad.colors.first.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: textStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 渐变图标按钮（圆形）
class GradientIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final LinearGradient? gradient;
  final double size;
  final String? tooltip;

  const GradientIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.gradient,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AppTheme.primaryGradient;

    Widget btn = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: grad,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: grad.colors.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// 渐变 FAB（FloatingActionButton 替代）
class GradientFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final LinearGradient? gradient;

  const GradientFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AppTheme.primaryGradient;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 20 : 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: grad.colors.first.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
