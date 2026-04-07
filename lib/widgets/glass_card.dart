import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 通用玻璃拟态卡片组件（轻量版）
///
/// 说明：在 ListView item 等滚动场景中，使用轻量版实现
/// （半透明背景 + 圆角 + 阴影），不使用 BackdropFilter 避免性能问题。
/// 真正的 BackdropFilter 仅用于 AppBar、BottomNavigationBar、Dialog 等固定位置。
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final LinearGradient? gradient;        // 渐变边框或背景（可选）
  final bool useGradientBorder;          // 是否用渐变边框
  final Color? backgroundColor;         // 自定义背景色
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.radiusLarge,
    this.padding,
    this.margin,
    this.gradient,
    this.useGradientBorder = false,
    this.backgroundColor,
    this.width,
    this.height,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.85);
    final bg = backgroundColor ?? defaultBg;

    // 渐变边框效果：外层容器套渐变，内层容器留白边作为边框
    if (useGradientBorder && gradient != null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows ?? AppTheme.cardShadow(dark: isDark),
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5), // 边框厚度
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius - 1.5),
          ),
          child: _buildContent(),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.7),
            width: 0.5,
          ),
          boxShadow: shadows ?? AppTheme.cardShadow(dark: isDark),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (onTap != null && !useGradientBorder) {
      // onTap 在外层 GestureDetector 处理
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// 渐变背景卡片（数值展示类）
class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.borderRadius = AppTheme.radiusLarge,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// 带左侧渐变色条的列表卡片（用于科目卡片等）
class AccentCard extends StatelessWidget {
  final Widget child;
  final LinearGradient accentGradient;
  final double accentWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AccentCard({
    super.key,
    required this.child,
    required this.accentGradient,
    this.accentWidth = 4,
    this.borderRadius = AppTheme.radiusMedium,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.cardDark : AppTheme.cardLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
            width: 0.5,
          ),
          boxShadow: AppTheme.cardShadow(dark: isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 左侧渐变色条
                Container(
                  width: accentWidth,
                  decoration: BoxDecoration(gradient: accentGradient),
                ),
                // 内容
                Expanded(
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(12),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
