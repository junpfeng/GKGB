import 'dart:ui';
import 'package:flutter/material.dart';
import 'practice_screen.dart';
import 'exam_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'policy_match_screen.dart';

/// 首页（底部导航 5 个 Tab）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final _pages = const [
    PracticeScreen(),
    ExamScreen(),
    PolicyMatchScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  // 导航项配置
  static const _navItems = [
    _NavItem(
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: '刷题',
    ),
    _NavItem(
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
      label: '模考',
    ),
    _NavItem(
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      label: '岗位',
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: '统计',
    ),
    _NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 毛玻璃底部导航栏
      bottomNavigationBar: _GlassNavigationBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        items: _navItems,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

/// 毛玻璃底部导航栏（BackdropFilter 只用于固定组件）
class _GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _GlassNavigationBar({
    required this.currentIndex,
    required this.isDark,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1E2E).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = i == currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 图标容器（选中时显示渐变背景）
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 28,
                            decoration: isSelected
                                ? BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0x26667eea),
                                        Color(0x26764ba2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  )
                                : null,
                            child: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 22,
                              color: isSelected
                                  ? const Color(0xFF667eea)
                                  : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500]),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF667eea)
                                  : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500]),
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 导航项数据类
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

