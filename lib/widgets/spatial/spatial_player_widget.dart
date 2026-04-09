import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'isometric_cube_painter.dart';
import 'fold_animation_widget.dart';

/// 空间可视化步骤数据
class VizStep {
  final int faceIndex; // -1: 展开图, -2: 旋转到答案, 0~5: 折叠面
  final String description;

  const VizStep({required this.faceIndex, required this.description});

  factory VizStep.fromJson(Map<String, dynamic> json) {
    return VizStep(
      faceIndex: json['face_index'] as int,
      description: json['description'] as String,
    );
  }
}

/// 空间可视化播放控制器
/// 包含步骤导航（上一步/播放暂停/下一步）和解题思路文字
class SpatialPlayerWidget extends StatefulWidget {
  final String configJson;
  final String solvingApproach;

  const SpatialPlayerWidget({
    super.key,
    required this.configJson,
    this.solvingApproach = '',
  });

  @override
  State<SpatialPlayerWidget> createState() => _SpatialPlayerWidgetState();
}

class _SpatialPlayerWidgetState extends State<SpatialPlayerWidget> {
  late List<CubeFace> _faces;
  late List<int> _foldSequence;
  late Map<String, double> _answerRotation;
  late List<VizStep> _steps;
  int _currentStep = 0;
  bool _isPlaying = false;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    _parseConfig();
  }

  void _parseConfig() {
    final config = jsonDecode(widget.configJson) as Map<String, dynamic>;

    _faces = (config['faces'] as List<dynamic>)
        .map((f) => CubeFace.fromJson(f as Map<String, dynamic>))
        .toList();

    _foldSequence = (config['fold_sequence'] as List<dynamic>)
        .map((e) => e as int)
        .toList();

    final rotation = config['answer_rotation'] as Map<String, dynamic>? ?? {};
    _answerRotation = {
      'x': (rotation['x'] as num?)?.toDouble() ?? 30,
      'y': (rotation['y'] as num?)?.toDouble() ?? 45,
      'z': (rotation['z'] as num?)?.toDouble() ?? 0,
    };

    _steps = (config['steps'] as List<dynamic>?)
        ?.map((s) => VizStep.fromJson(s as Map<String, dynamic>))
        .toList() ?? _generateDefaultSteps();
  }

  /// 无 steps 数据时生成默认步骤
  List<VizStep> _generateDefaultSteps() {
    return [
      const VizStep(faceIndex: -1, description: '展开图'),
      for (int i = 0; i < _faces.length; i++)
        VizStep(faceIndex: i, description: '折叠第${i + 1}面'),
      const VizStep(faceIndex: -2, description: '旋转到答案视角'),
    ];
  }

  int get _totalSteps => _steps.length;

  /// 当前步骤对应的折叠动画 step 值
  int get _foldStep {
    if (_currentStep >= _totalSteps) return _faces.length;
    final vizStep = _steps[_currentStep];
    if (vizStep.faceIndex == -1) return -1; // 展开图
    if (vizStep.faceIndex == -2) return _faces.length; // 旋转
    // 计算已折叠面数
    int foldCount = 0;
    for (int i = 0; i <= _currentStep; i++) {
      if (i < _totalSteps && _steps[i].faceIndex >= 0) foldCount++;
    }
    return foldCount;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _stopPlaying();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlaying();
    } else {
      _startPlaying();
    }
  }

  void _startPlaying() {
    if (_currentStep >= _totalSteps - 1) {
      // 从头开始
      setState(() => _currentStep = 0);
    }
    setState(() => _isPlaying = true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_currentStep < _totalSteps - 1) {
        _nextStep();
      } else {
        _stopPlaying();
      }
    });
  }

  void _stopPlaying() {
    _playTimer?.cancel();
    _playTimer = null;
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVizStep = _currentStep < _totalSteps
        ? _steps[_currentStep]
        : _steps.last;

    return Column(
      children: [
        // 动画区域
        Expanded(
          child: Center(
            child: FoldAnimationWidget(
              faces: _faces,
              foldSequence: _foldSequence,
              answerRotation: _answerRotation,
              currentStep: _foldStep,
            ),
          ),
        ),

        // 步骤说明文字
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '步骤 ${_currentStep + 1}/$_totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentVizStep.description,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 播放控制栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一步
              IconButton.filled(
                onPressed: _currentStep > 0 ? _prevStep : null,
                icon: const Icon(Icons.skip_previous_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              // 播放/暂停
              IconButton.filled(
                onPressed: _togglePlay,
                icon: Icon(_isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(56, 56),
                ),
              ),
              const SizedBox(width: 16),
              // 下一步
              IconButton.filled(
                onPressed: _currentStep < _totalSteps - 1 ? _nextStep : null,
                icon: const Icon(Icons.skip_next_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // 解题思路（展开/折叠）
        if (widget.solvingApproach.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SolvingApproachCard(approach: widget.solvingApproach),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

/// 解题思路卡片（可展开/收起）
class _SolvingApproachCard extends StatefulWidget {
  final String approach;
  const _SolvingApproachCard({required this.approach});

  @override
  State<_SolvingApproachCard> createState() => _SolvingApproachCardState();
}

class _SolvingApproachCardState extends State<_SolvingApproachCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '解题思路',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.approach,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
