import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/assistant_service.dart';
import '../../services/voice_service.dart';

/// 助手输入栏：文字输入 + 麦克风按钮 + 发送按钮
class AssistantInputBar extends StatefulWidget {
  const AssistantInputBar({super.key});

  @override
  State<AssistantInputBar> createState() => _AssistantInputBarState();
}

class _AssistantInputBarState extends State<AssistantInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<AssistantService>().sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assistantService = context.watch<AssistantService>();
    final voiceService = context.watch<VoiceService>();
    final isLoading = assistantService.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          // 麦克风按钮（VoiceService.isAvailable 控制显隐）
          if (voiceService.isAvailable) ...[
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () => _toggleVoice(context, voiceService),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: voiceService.isListening
                      ? Colors.red.withValues(alpha: 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFF667eea).withValues(alpha: 0.08)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  voiceService.isListening ? Icons.mic : Icons.mic_none,
                  size: 20,
                  color: voiceService.isListening
                      ? Colors.red
                      : (isDark
                          ? Colors.white54
                          : const Color(0xFF667eea).withValues(alpha: 0.7)),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 文字输入框
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: voiceService.isListening ? '正在聆听...' : '问点什么...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onSubmitted: isLoading ? null : (_) => _send(context),
              textInputAction: TextInputAction.send,
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          GestureDetector(
            onTap: isLoading ? null : () => _send(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isLoading
                    ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                    : AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF667eea).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleVoice(BuildContext context, VoiceService voiceService) {
    if (voiceService.isListening) {
      voiceService.stopListening();
    } else {
      voiceService.startListening(onResult: (text) {
        // 语音识别结果填入输入框
        setState(() {
          _controller.text = text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      });
    }
  }
}
