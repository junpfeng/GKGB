import 'package:flutter/material.dart';

/// 应用主题常量（渐变色、圆角、颜色等）
class AppTheme {
  AppTheme._();

  // ---- 品牌渐变 ----

  /// 主渐变：蓝紫渐变（按钮、强调）
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 辅助渐变：青蓝（信息、统计）
  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 暖色渐变：橙粉（警告、错题标记）
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 成功渐变：绿
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 警告渐变：橙
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---- 颜色 ----

  /// 亮色模式背景
  static const Color bgLight = Color(0xFFF0F4F8);

  /// 暗色模式背景
  static const Color bgDark = Color(0xFF0D1B2A);

  /// 主文字色（亮色模式）
  static const Color textDark = Color(0xFF1B2838);

  /// 卡片背景（亮色模式，轻量版不用 BackdropFilter）
  static const Color cardLight = Color(0xFFFAFCFF);

  /// 卡片背景（暗色模式）
  static const Color cardDark = Color(0xFF162236);

  /// 分隔线颜色
  static const Color dividerLight = Color(0xFFE0E8F0);
  static const Color dividerDark = Color(0xFF1E2F42);

  // ---- 圆角 ----
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXL = 28.0;

  // ---- 阴影 ----

  /// 轻量卡片阴影（轻量版玻璃效果用）
  static List<BoxShadow> cardShadow({bool dark = false}) => [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF667eea).withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  /// 按钮阴影
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: const Color(0xFF667eea).withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
  ];

  // ---- 科目颜色映射 ----
  static const Map<String, Color> subjectColors = {
    '言语理解': Color(0xFF667eea),
    '数量关系': Color(0xFFf5576c),
    '判断推理': Color(0xFF764ba2),
    '资料分析': Color(0xFF0ED2F7),
    '常识判断': Color(0xFFF7971E),
    '申论写作': Color(0xFF43E97B),
    '公共基础': Color(0xFF09A6C3),
  };

  // ---- 科目渐变映射 ----
  static const Map<String, List<Color>> subjectGradients = {
    '言语理解': [Color(0xFF667eea), Color(0xFF764ba2)],
    '数量关系': [Color(0xFFf093fb), Color(0xFFf5576c)],
    '判断推理': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    '资料分析': [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    '常识判断': [Color(0xFFF7971E), Color(0xFFFFD200)],
    '申论写作': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    '公共基础': [Color(0xFF09A6C3), Color(0xFF0ED2F7)],
  };

  // ---- 亮色主题 ----
  static ThemeData get lightTheme {
    const primary = Color(0xFF667eea);
    const secondary = Color(0xFF764ba2);
    const background = bgLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: dividerLight,
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return IconThemeData(color: Colors.grey[500], size: 22);
        }),
      ),
      // Card
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: dividerLight, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primary),
          side: WidgetStateProperty.all(
            BorderSide(color: primary.withValues(alpha: 0.5)),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F8FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      ),
      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: primary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F4FF),
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }

  // ---- 暗色主题 ----
  static ThemeData get darkTheme {
    const primary = Color(0xFF8B9FF8);
    const background = bgDark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      surface: const Color(0xFF162236),
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: dividerDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F1E2E).withValues(alpha: 0.9),
        elevation: 0,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return const TextStyle(fontSize: 11, color: Colors.grey);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: Colors.grey, size: 22);
        }),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: dividerDark, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          foregroundColor: WidgetStateProperty.all(const Color(0xFF0D1B2A)),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2D42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1A2D42),
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }
}
