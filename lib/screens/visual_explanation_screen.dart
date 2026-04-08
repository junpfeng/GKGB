import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/visual_explanation.dart';
import '../services/visual_explanation_service.dart';
import '../widgets/visual/visual_player_widget.dart';

/// 可视化解题全屏播放器
/// 深色背景，持有 AnimationController 管理动画生命周期
class VisualExplanationScreen extends StatefulWidget {
  final int questionId;
  final String questionContent;
  final String questionAnswer;
  final String? questionExplanation;

  const VisualExplanationScreen({
    super.key,
    required this.questionId,
    required this.questionContent,
    required this.questionAnswer,
    this.questionExplanation,
  });

  @override
  State<VisualExplanationScreen> createState() =>
      _VisualExplanationScreenState();
}

class _VisualExplanationScreenState extends State<VisualExplanationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  List<VisualStep> _steps = [];
  int _currentStep = 0;
  bool _isPlaying = false;
  double _speed = 1.0;
  Timer? _autoPlayTimer;

  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.addListener(() {
      setState(() {});
    });
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isPlaying) {
        _advanceStep();
      }
    });
    _loadExplanation();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExplanation() async {
    final service = context.read<VisualExplanationService>();

    try {
      // 先查 DB 缓存，未命中则 AI 生成
      final explanation = await service.getExplanation(widget.questionId) ??
          await service.generateExplanation(
            widget.questionId,
            questionContent: widget.questionContent,
            questionAnswer: widget.questionAnswer,
            questionExplanation: widget.questionExplanation,
          );

      if (!mounted) return;

      final steps = explanation.steps;
      if (steps.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '解析步骤数据失败';
        });
        return;
      }

      setState(() {
        _steps = steps;
        _isLoading = false;
      });

      // 播放第一步动画
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '生成失败，请重试';
      });
    }
  }

  void _advanceStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      // 播放完毕
      setState(() {
        _isPlaying = false;
      });
      _autoPlayTimer?.cancel();
    }
  }

  void _goToPrevious() {
    if (_currentStep > 0) {
      _autoPlayTimer?.cancel();
      setState(() {
        _currentStep--;
        _isPlaying = false;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _goToNext() {
    if (_currentStep < _steps.length - 1) {
      _autoPlayTimer?.cancel();
      setState(() {
        _currentStep++;
        _isPlaying = false;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      // 暂停
      _autoPlayTimer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // 开始播放
      setState(() {
        _isPlaying = true;
      });
      // 如果当前步骤动画已完成，前进到下一步
      if (_animationController.isCompleted) {
        _advanceStep();
      }
    }
  }

  void _onSpeedChanged(double speed) {
    setState(() {
      _speed = speed;
    });
    _animationController.duration = Duration(
      milliseconds: (800 / _speed).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '可视化解题',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // 题目文本（可折叠）
        _QuestionTextSection(text: widget.questionContent),

        // 播放器主体
        Expanded(
          child: VisualPlayerWidget(
            steps: _steps,
            currentStep: _currentStep,
            animationProgress: _animationController.value,
            isPlaying: _isPlaying,
            onPrevious: _goToPrevious,
            onNext: _goToNext,
            onPlayPause: _togglePlayPause,
            speed: _speed,
            onSpeedChanged: _onSpeedChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Consumer<VisualExplanationService>(
      builder: (context, service, _) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                service.isGenerating ? 'AI 正在生成解题动画...' : '加载中...',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFf5576c)),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadExplanation();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 题目文本折叠区域
class _QuestionTextSection extends StatefulWidget {
  final String text;
  const _QuestionTextSection({required this.text});

  @override
  State<_QuestionTextSection> createState() => _QuestionTextSectionState();
}

class _QuestionTextSectionState extends State<_QuestionTextSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: Color(0xFF667eea)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '题目',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
