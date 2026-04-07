import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/assistant_service.dart';
import 'assistant_message.dart';
import 'assistant_input_bar.dart';

/// 毛玻璃对话面板（85% 屏幕高度，复用 AiChatDialog 视觉风格）
class AssistantDialog extends StatefulWidget {
  const AssistantDialog({super.key});

  @override
  State<AssistantDialog> createState() => _AssistantDialogState();
}

class _AssistantDialogState extends State<AssistantDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assistantService = context.watch<AssistantService>();

    // 滚动到底部（新消息时）
    if (assistantService.isLoading || assistantService.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1E2E).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              _buildTitleBar(context, isDark, assistantService),
              Divider(
                height: 1,
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              ),
              // 消息列表
              Expanded(
                child: _buildMessageList(context, isDark, assistantService),
              ),
              // 输入栏分隔线
              Divider(
                height: 1,
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              ),
              // 输入栏
              const AssistantInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(
    BuildContext context,
    bool isDark,
    AssistantService service,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          // AI 图标（渐变圆形）
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            '智能助手',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // 清空对话按钮
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            tooltip: '新对话',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('开始新对话'),
                  content: const Text('清空当前对话记录？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        service.clearMessages();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
          // 最小化按钮
          IconButton(
            icon: const Icon(Icons.minimize),
            tooltip: '最小化',
            onPressed: () => service.minimize(),
          ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => service.hide(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    bool isDark,
    AssistantService service,
  ) {
    final messages = service.messages;
    final isLoading = service.isLoading;

    // 计算列表项数
    // 如果正在加载（流式），最后一条是 streaming 状态的 assistant 消息
    final streamingMsg = isLoading && messages.isNotEmpty &&
        messages.last.status == MessageStatus.streaming
        ? messages.last
        : null;

    final displayMessages = messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: displayMessages.length,
      itemBuilder: (_, index) {
        final msg = displayMessages[index];
        final isStreamingMsg = streamingMsg != null && msg.id == streamingMsg.id;

        return AssistantMessageBubble(
          message: msg,
          isStreamingMessage: isStreamingMsg,
          streamingNotifier: isStreamingMsg ? service.streamingResponse : null,
        );
      },
    );
  }
}
