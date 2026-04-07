import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/assistant_service.dart';
import '../../services/voice_service.dart';

/// 消息气泡组件
/// 支持 ACTION 按钮显示和 TTS 播放
class AssistantMessageBubble extends StatelessWidget {
  final AssistantMessage message;

  /// 是否为当前正在流式输出的消息
  final bool isStreamingMessage;

  /// 流式内容（仅 isStreamingMessage=true 时有效）
  final ValueNotifier<String>? streamingNotifier;

  const AssistantMessageBubble({
    super.key,
    required this.message,
    this.isStreamingMessage = false,
    this.streamingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isUser) {
      return _UserBubble(message: message, isDark: isDark);
    }

    if (message.role == 'system') {
      return _SystemNotice(message: message, isDark: isDark);
    }

    // assistant role
    return _AssistantBubble(
      message: message,
      isDark: isDark,
      isStreamingMessage: isStreamingMessage,
      streamingNotifier: streamingNotifier,
    );
  }
}

// ===== 用户气泡 =====
class _UserBubble extends StatelessWidget {
  final AssistantMessage message;
  final bool isDark;

  const _UserBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.displayText,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
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
      ),
    );
  }
}

// ===== 系统通知气泡 =====
class _SystemNotice extends StatelessWidget {
  final AssistantMessage message;
  final bool isDark;

  const _SystemNotice({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.displayText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ===== AI 助手气泡 =====
class _AssistantBubble extends StatelessWidget {
  final AssistantMessage message;
  final bool isDark;
  final bool isStreamingMessage;
  final ValueNotifier<String>? streamingNotifier;

  const _AssistantBubble({
    required this.message,
    required this.isDark,
    required this.isStreamingMessage,
    this.streamingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // AI 头像
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 消息内容气泡
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFF667eea).withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _buildTextContent(context),
                      ),
                      if (message.status == MessageStatus.streaming) ...[
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF667eea),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ACTION 按钮行（仅完成状态且有 actions 时显示）
                if (message.status == MessageStatus.completed &&
                    message.actions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ActionChips(actions: message.actions),
                ],
                // 错误状态提示
                if (message.status == MessageStatus.error) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 12, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        '回复失败，请重试',
                        style: TextStyle(fontSize: 11, color: Colors.red[400]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // TTS 播放按钮（仅完成状态）
          if (message.status == MessageStatus.completed &&
              message.displayText.isNotEmpty) ...[
            const SizedBox(width: 4),
            _TtsButton(text: message.displayText),
          ],
        ],
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    // 流式消息：使用 ValueListenableBuilder 精准重建 [C-3]
    if (isStreamingMessage && streamingNotifier != null) {
      return ValueListenableBuilder<String>(
        valueListenable: streamingNotifier!,
        builder: (context, value, child) {
          final display = value.isEmpty ? '思考中...' : value;
          return Text(
            display,
            style: const TextStyle(fontSize: 14, height: 1.5),
          );
        },
      );
    }

    final text = message.status == MessageStatus.error
        ? (message.errorMessage ?? message.displayText)
        : message.displayText;

    return Text(
      text.isEmpty ? '思考中...' : text,
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
  }
}

// ===== ACTION 可点击 Chip =====
class _ActionChips extends StatelessWidget {
  final List<ToolCommand> actions;

  const _ActionChips({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: actions.map((action) {
        return InkWell(
          onTap: () => _executeAction(context, action),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _actionDisplayName(action),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _actionDisplayName(ToolCommand action) {
    switch (action.name) {
      case 'navigate':
        final screen = action.params['screen'] ?? '';
        final names = {
          'practice': '去刷题',
          'exam': '去模考',
          'match': '去岗位匹配',
          'stats': '去统计',
          'profile': '去个人信息',
        };
        return names[screen] ?? '导航';
      case 'start_practice':
        return '开始练习${action.params['subject'] ?? ''}';
      case 'load_wrong_questions':
        return '查看错题';
      case 'start_exam':
        return '开始模考';
      case 'show_exam_history':
        return '考试历史';
      case 'generate_plan':
        return '生成学习计划';
      case 'adjust_plan':
        return '调整学习计划';
      case 'start_baseline':
        return '开始摸底测试';
      case 'run_match':
        return '执行岗位匹配';
      case 'show_stats':
        return '查看统计';
      default:
        return action.name;
    }
  }

  void _executeAction(BuildContext context, ToolCommand action) {
    final assistantService = context.read<AssistantService>();
    // 用 sendMessage 触发该工具的执行语义，或直接调用内部方法
    // 这里通过一个简化指令发送让 AI 再次执行
    assistantService.sendMessage('执行：${action.name}');
  }
}

// ===== TTS 播放按钮 =====
class _TtsButton extends StatelessWidget {
  final String text;

  const _TtsButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final voiceService = context.watch<VoiceService>();

    if (!voiceService.ttsAvailable) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (voiceService.isSpeaking) {
          voiceService.stopSpeaking();
        } else {
          voiceService.speak(text);
        }
      },
      child: Icon(
        voiceService.isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
        size: 16,
        color: const Color(0xFF667eea).withValues(alpha: 0.7),
      ),
    );
  }
}
