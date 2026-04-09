import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'practice_screen.dart';
import 'exam_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'policy_match_screen.dart';
import '../services/assistant_service.dart';
import '../services/exam_category_service.dart';
import '../widgets/exam_type_badge.dart';

/// 首页（底部导航 5 个 Tab）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 页面名称列表（与 screenTabIndex 映射对应）
const _screenNames = ['practice', 'exam', 'match', 'dashboard', 'profile'];

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final _pages = const [
    PracticeScreen(),
    ExamScreen(),
    PolicyMatchScreen(),
    DashboardScreen(),
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
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '看板',
    ),
    _NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 注册导航回调到 AssistantService [C-1]
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final assistantService = context.read<AssistantService>();
      assistantService.registerNavigationCallback((tabIndex) {
        if (tabIndex >= 0 && tabIndex < _screenNames.length) {
          setState(() => _currentIndex = tabIndex);
          assistantService.updateContext(_screenNames[tabIndex]);
        }
      });

      // 检查是否有待跳转 Tab（如选择人才引进后自动跳转岗位匹配）
      final ecService = context.read<ExamCategoryService>();
      final pendingTab = ecService.consumePendingTabIndex();
      if (pendingTab != null && pendingTab >= 0 && pendingTab < _screenNames.length) {
        setState(() => _currentIndex = pendingTab);
      }

      // 初始化上下文
      assistantService.updateContext(_screenNames[_currentIndex]);
    });
  }

  /// 切换 tab 时同步更新 AssistantService 上下文
  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    context.read<AssistantService>().updateContext(_screenNames[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<ExamCategoryService>(
        builder: (context, ecService, child) {
          return Column(
            children: [
              const ExamTypeBadge(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          );
        },
      ),
      // 毛玻璃底部导航栏
      bottomNavigationBar: _GlassNavigationBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        items: _navItems,
        onTap: _onTabTap,
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

