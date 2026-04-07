import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/assistant_service.dart';
import 'assistant_bubble.dart';
import 'assistant_dialog.dart';

/// 全局 AI 助手 Overlay
/// 由 MaterialApp.builder 注入，始终位于所有页面之上 [H-5]
/// 根据 AssistantService.state 渲染悬浮球或对话面板
class AiAssistantOverlay extends StatefulWidget {
  const AiAssistantOverlay({super.key});

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay>
    with SingleTickerProviderStateMixin {
  /// AnimationController：300ms easeOutCubic，控制展开/收起动画
  late AnimationController _animController;
  late Animation<double> _animation;

  // 上一个状态，用于判断动画方向
  AssistantState? _lastState;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleStateChange(AssistantState state) {
    if (_lastState == state) return;
    _lastState = state;

    switch (state) {
      case AssistantState.expanded:
        _animController.forward();
        break;
      case AssistantState.minimized:
      case AssistantState.hidden:
        _animController.reverse();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistantService = context.watch<AssistantService>();
    final state = assistantService.state;

    // 触发动画
    _handleStateChange(state);

    // hidden 状态：不渲染任何内容
    if (state == AssistantState.hidden) {
      return const SizedBox.shrink();
    }

    // 监听待执行导航 [C-1]：在 build 结束后执行，避免 build 中触发 setState
    final pending = assistantService.pendingNavigation;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 仅在 service 中执行导航（已通过 _onNavigate 回调处理），清除 pending
        assistantService.consumeNavigation();
      });
    }

    return Stack(
      children: [
        // 悬浮球（minimized 状态 + 动画收起时）
        if (state == AssistantState.minimized)
          const AssistantBubble(),

        // 对话面板（expanded 状态 + 动画展开时）
        if (state == AssistantState.expanded || _animController.value > 0)
          _buildDialogPanel(context, assistantService),
      ],
    );
  }

  Widget _buildDialogPanel(
    BuildContext context,
    AssistantService service,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = screenHeight * 0.85;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        final value = _animation.value;
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: panelHeight * value.clamp(0.0, 1.0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child!,
          ),
        );
      },
      child: const AssistantDialog(),
    );
  }
}

/// 隐私授权弹窗 [H-1]
class PrivacyConsentDialog extends StatelessWidget {
  const PrivacyConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PrivacyConsentDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFF667eea)),
          SizedBox(width: 8),
          Text('隐私授权'),
        ],
      ),
      content: const Text(
        'AI 助手将向大模型发送以下信息以提供个性化服务：\n\n'
        '• 您的学历、专业、工作年限\n'
        '• 当前学习进度（做题数量、正确率）\n'
        '• 当前页面上下文\n\n'
        '注意：不发送身份证号、姓名等敏感信息。\n'
        '如使用本地 Ollama 模型，数据不离开本机。',
        style: TextStyle(height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('同意并继续'),
        ),
      ],
    );
  }
}
