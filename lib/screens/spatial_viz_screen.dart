import 'package:flutter/material.dart';
import '../models/spatial_visualization.dart';
import '../widgets/spatial/spatial_player_widget.dart';

/// 空间可视化全屏播放器
/// 深色背景，聚焦动画区域，配解题思路
class SpatialVizScreen extends StatelessWidget {
  final SpatialVisualization visualization;
  final String? questionText;

  const SpatialVizScreen({
    super.key,
    required this.visualization,
    this.questionText,
  });

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
            '立体演示',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 题目文本（可折叠）
              if (questionText != null && questionText!.isNotEmpty)
                _QuestionTextSection(text: questionText!),

              // 播放器主体
              Expanded(
                child: SpatialPlayerWidget(
                  configJson: visualization.configJson,
                  solvingApproach: visualization.solvingApproach,
                ),
              ),
            ],
          ),
        ),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz_outlined, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                const Text(
                  '题目',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
