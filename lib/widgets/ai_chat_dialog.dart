import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/llm/llm_manager.dart';
import '../services/llm/llm_provider.dart';

/// AI 对话弹窗
/// 用于题目讲解、追问、申论批改等场景
class AiChatDialog extends StatefulWidget {
  final String initialPrompt; // 初始系统提示或问题
  final String title;

  const AiChatDialog({
    super.key,
    required this.initialPrompt,
    this.title = 'AI 讲解',
  });

  /// 打开 AI 对话弹窗
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
    // 自动发送初始问题
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
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 消息区域
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_isLoading || _streamingResponse.isNotEmpty ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index < _messages.length) {
                      return _MessageBubble(message: _messages[index]);
                    }
                    // 流式响应气泡
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
              // 输入框
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        decoration: InputDecoration(
                          hintText: '继续追问...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (text) => _sendMessage(text),
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(_inputController.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.smart_toy, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      message.content,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(width: 4),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              child: Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
