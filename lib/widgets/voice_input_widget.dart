import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';

/// 语音输入组件：封装 STT 交互（麦克风按钮 + 状态动画 + 识别文本回调）
/// Platform 判断：不支持时显示提示
class VoiceInputWidget extends StatefulWidget {
  /// STT 识别结果回调（最终结果）
  final ValueChanged<String> onResult;
  /// 实时识别文本回调
  final ValueChanged<String>? onPartialResult;
  /// 是否禁用
  final bool enabled;

  const VoiceInputWidget({
    super.key,
    required this.onResult,
    this.onPartialResult,
    this.enabled = true,
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    final voiceService = context.read<VoiceService>();
    if (voiceService.isListening) {
      voiceService.stopListening();
      _pulseController.stop();
      _pulseController.reset();
    } else {
      voiceService.startListening(
        onResult: (text) {
          widget.onResult(text);
        },
      );
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Windows 端 STT 可能不可用
    if (Platform.isWindows) {
      return Consumer<VoiceService>(
        builder: (context, voiceService, _) {
          if (!voiceService.isAvailable) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前平台不支持语音输入，请使用文字模式',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildVoiceButton(voiceService);
        },
      );
    }

    return Consumer<VoiceService>(
      builder: (context, voiceService, _) {
        if (!voiceService.isAvailable) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic_off, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '语音识别不可用，请检查麦克风权限',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildVoiceButton(voiceService);
      },
    );
  }

  Widget _buildVoiceButton(VoiceService voiceService) {
    final isListening = voiceService.isListening;

    // 实时识别文本回调
    if (isListening && widget.onPartialResult != null) {
      widget.onPartialResult!(voiceService.recognizedText);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大号麦克风按钮 + 脉冲动画
        GestureDetector(
          onTap: widget.enabled ? _toggleListening : null,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? Colors.red.withValues(alpha: 0.15)
                      : const Color(0xFF667eea).withValues(alpha: 0.1),
                  boxShadow: isListening
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.2),
                            blurRadius: 20 * _pulseAnimation.value,
                            spreadRadius: 5 * (_pulseAnimation.value - 1.0),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  size: 40,
                  color: isListening
                      ? Colors.red
                      : widget.enabled
                          ? const Color(0xFF667eea)
                          : Colors.grey,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // 状态文字
        Text(
          isListening ? '正在聆听...' : '点击开始语音输入',
          style: TextStyle(
            fontSize: 13,
            color: isListening ? Colors.red : Colors.grey[600],
            fontWeight: isListening ? FontWeight.w500 : FontWeight.normal,
          ),
        ),

        // 波形指示
        if (isListening) ...[
          const SizedBox(height: 12),
          _WaveformIndicator(),
        ],

        // 实时识别文本
        if (isListening && voiceService.recognizedText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              voiceService.recognizedText,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // 错误信息
        if (voiceService.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            '识别出错: ${voiceService.errorMessage}',
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ],
      ],
    );
  }
}

/// 简易波形动画指示器
class _WaveformIndicator extends StatefulWidget {
  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            final phase = (_controller.value + i * 0.15) % 1.0;
            final height = 8.0 + 16.0 * sin(phase * pi);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
