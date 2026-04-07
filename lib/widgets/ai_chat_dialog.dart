import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/llm/llm_manager.dart';
import '../services/llm/llm_provider.dart';
import '../theme/app_theme.dart';

/// AI 对话弹窗（毛玻璃底部弹窗 + 渐变发送按钮）
class AiChatDialog extends StatefulWidget {
  final String initialPrompt;
  final String title;

  const AiChatDialog({
    super.key,
    required this.initialPrompt,
    this.title = 'AI 讲解',
  });

  static Future<void> show(
    BuildContext context, {
    required String initialPrompt,
    String title = 'AI 讲解',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiChatDialog(
        initialPrompt: initialPrompt,
        title: title,
      ),
    );
  }

  @override
  State<AiChatDialog> createState() => _AiChatDialogState();
}

class _AiChatDialogState extends State<AiChatDialog> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String _streamingResponse = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendMessage(widget.initialPrompt, showInChat: false);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {bool showInChat = true}) async {
    if (text.trim().isEmpty) return;

    if (showInChat) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _inputController.clear();
        _streamingResponse = '';
        _isLoading = true;
      });
    } else {
      setState(() {
        _streamingResponse = '';
        _isLoading = true;
      });
    }

    final llmManager = context.read<LlmManager>();
    if (!llmManager.hasProvider) {
      setState(() {
        _isLoading = false;
        _streamingResponse = '未配置 AI 模型，请前往"我的 → AI 模型设置"添加模型。';
      });
      return;
    }

    final messagesToSend = List<ChatMessage>.from(_messages);
    if (!showInChat) {
      messagesToSend.add(ChatMessage(role: 'user', content: text));
    }

    final buffer = StringBuffer();
    try {
      await for (final chunk in llmManager.streamChat(messagesToSend)) {
        buffer.write(chunk);
        setState(() => _streamingResponse = buffer.toString());
        _scrollToBottom();
      }

      final response = buffer.toString();
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: response));
        _streamingResponse = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _streamingResponse = 'AI 响应失败：$e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F1E2E).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        // AI 图标（渐变）
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                  ),
                  // 消息区域
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length +
                          (_isLoading || _streamingResponse.isNotEmpty ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index < _messages.length) {
                          return _MessageBubble(message: _messages[index]);
                        }
                        return _MessageBubble(
                          message: ChatMessage(
                            role: 'assistant',
                            content: _streamingResponse.isEmpty
                                ? (_isLoading ? '思考中...' : '')
                                : _streamingResponse,
                          ),
                          isStreaming: _isLoading,
                        );
                      },
                    ),
                  ),
                  // 输入框区域
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 10,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: InputDecoration(
                              hintText: '继续追问...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppTheme.dividerDark
                                      : AppTheme.dividerLight,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (text) => _sendMessage(text),
                            enabled: !_isLoading,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 渐变发送按钮
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => _sendMessage(_inputController.text),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: _isLoading
                                  ? const LinearGradient(
                                      colors: [Colors.grey, Colors.grey])
                                  : AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: _isLoading
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF667eea)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: const Icon(Icons.send,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;

  const _MessageBubble({required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser ? AppTheme.primaryGradient : null,
                color: isUser
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFF667eea).withValues(alpha: 0.06)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: const Color(0xFF667eea).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isUser ? Colors.white : null,
                      ),
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isUser ? Colors.white : const Color(0xFF667eea),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFF667eea).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 16,
                color: isDark ? Colors.white70 : const Color(0xFF667eea),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
