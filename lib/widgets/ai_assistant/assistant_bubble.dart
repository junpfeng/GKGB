import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/assistant_service.dart';

/// 可拖拽悬浮球（56x56 渐变圆形）
/// - 点击展开助手
/// - 长按快捷菜单（新对话/隐藏）
/// - 拖拽位置 clamp 到 SafeArea [设计文档]
class AssistantBubble extends StatefulWidget {
  const AssistantBubble({super.key});

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 悬浮球呼吸动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantService = context.watch<AssistantService>();
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    // 计算悬浮球位置（默认右下角）
    Offset pos = assistantService.bubblePosition;
    if (pos.dx < 0 || pos.dy < 0) {
      // 默认位置：右下角
      pos = Offset(
        screenSize.width - 56 - 16,
        screenSize.height - 56 - kBottomNavigationBarHeight - 16 - padding.bottom,
      );
    }

    // clamp 到 SafeArea 边界
    final clampedX = pos.dx.clamp(
      padding.left + 8,
      screenSize.width - 56 - padding.right - 8,
    );
    final clampedY = pos.dy.clamp(
      padding.top + 8,
      screenSize.height - 56 - padding.bottom - 8,
    );

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onTap: () => assistantService.expand(),
        onLongPress: () => _showQuickMenu(context, assistantService),
        onPanUpdate: (details) {
          final newPos = Offset(
            (pos.dx + details.delta.dx).clamp(
              padding.left + 8,
              screenSize.width - 56 - padding.right - 8,
            ),
            (pos.dy + details.delta.dy).clamp(
              padding.top + 8,
              screenSize.height - 56 - padding.bottom - 8,
            ),
          );
          assistantService.updateBubblePosition(newPos);
          // 强制 setState 更新位置（不通过 notifyListeners）
          setState(() {});
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickMenu(BuildContext context, AssistantService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickMenu(service: service),
    );
  }
}

/// 快捷菜单（长按悬浮球触发）
class _QuickMenu extends StatelessWidget {
  final AssistantService service;

  const _QuickMenu({required this.service});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2D42) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 18, color: Colors.white),
            ),
            title: const Text('打开助手'),
            onTap: () {
              Navigator.pop(context);
              service.expand();
            },
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            title: const Text('新对话'),
            onTap: () {
              Navigator.pop(context);
              service.clearMessages();
            },
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
            title: const Text('隐藏助手'),
            onTap: () {
              Navigator.pop(context);
              service.hide();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
