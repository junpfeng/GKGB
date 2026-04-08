import 'package:flutter/material.dart';
import '../../models/visual_explanation.dart';
import 'equation_painter.dart';

/// 可视化播放控制器
/// 接收动画值 + 渲染控制栏（上一步/播放暂停/下一步/速度调节）
class VisualPlayerWidget extends StatelessWidget {
  final List<VisualStep> steps;
  final int currentStep;
  final double animationProgress;
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const VisualPlayerWidget({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.animationProgress,
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    this.speed = 1.0,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 画布区域
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CustomPaint(
              painter: EquationPainter(
                steps: steps,
                currentStep: currentStep,
                animationProgress: animationProgress,
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // 步骤指示器
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _StepIndicator(
            totalSteps: steps.length,
            currentStep: currentStep,
          ),
        ),

        // 当前步骤叙述文字
        if (currentStep < steps.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              steps[currentStep].narration,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFFE0E0E0),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 12),

        // 播放控制栏
        _PlaybackControls(
          isPlaying: isPlaying,
          canPrevious: currentStep > 0,
          canNext: currentStep < steps.length - 1,
          onPrevious: onPrevious,
          onNext: onNext,
          onPlayPause: onPlayPause,
          speed: speed,
          onSpeedChanged: onSpeedChanged,
          currentStepIndex: currentStep,
          totalSteps: steps.length,
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

/// 步骤进度指示器
class _StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const _StepIndicator({
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isPast = i < currentStep;
        return Container(
          width: isActive ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? const Color(0xFF667eea)
                : isPast
                    ? const Color(0xFF667eea).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }
}

/// 播放控制按钮组
class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final int currentStepIndex;
  final int totalSteps;

  const _PlaybackControls({
    required this.isPlaying,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.speed,
    required this.onSpeedChanged,
    required this.currentStepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 速度调节
          _SpeedChip(speed: speed, onSpeedChanged: onSpeedChanged),

          const SizedBox(width: 16),

          // 上一步
          IconButton(
            onPressed: canPrevious ? onPrevious : null,
            icon: const Icon(Icons.skip_previous_rounded),
            iconSize: 32,
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.2),
          ),

          const SizedBox(width: 8),

          // 播放/暂停
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            child: IconButton(
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              iconSize: 36,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 8),

          // 下一步
          IconButton(
            onPressed: canNext ? onNext : null,
            icon: const Icon(Icons.skip_next_rounded),
            iconSize: 32,
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.2),
          ),

          const SizedBox(width: 16),

          // 步骤计数
          Text(
            '${currentStepIndex + 1}/$totalSteps',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// 速度调节芯片
class _SpeedChip extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedChip({
    required this.speed,
    required this.onSpeedChanged,
  });

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final currentIndex = _speeds.indexOf(speed);
        final nextIndex = (currentIndex + 1) % _speeds.length;
        onSpeedChanged(_speeds[nextIndex]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          '${speed}x',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
