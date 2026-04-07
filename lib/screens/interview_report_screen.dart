import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/interview_session.dart';
import '../models/interview_score.dart';
import '../services/interview_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';

/// 面试报告页：综合得分 + 维度分析 + 逐题回顾 + AI 综合建议
class InterviewReportScreen extends StatefulWidget {
  final int sessionId;
  /// 是否为面试结束后直接进入（需生成综合报告）
  final bool isLive;

  const InterviewReportScreen({
    super.key,
    required this.sessionId,
    this.isLive = false,
  });

  @override
  State<InterviewReportScreen> createState() => _InterviewReportScreenState();
}

class _InterviewReportScreenState extends State<InterviewReportScreen> {
  InterviewSession? _session;
  List<InterviewScore> _scores = [];
  bool _loading = true;
  String _summary = '';
  StreamSubscription<String>? _summarySubscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<InterviewService>();
    final session = await service.getSession(widget.sessionId);
    final scores = await service.getSessionScores(widget.sessionId);

    if (mounted) {
      setState(() {
        _session = session;
        _scores = scores;
        _loading = false;
        _summary = session?.summary ?? '';
      });
    }

    // 面试刚结束，流式生成综合报告
    if (widget.isLive && (session?.summary == null || session!.summary!.isEmpty)) {
      final stream = service.finishInterview();
      _summarySubscription = stream.listen(
        (chunk) {
          if (mounted) setState(() => _summary += chunk);
        },
        onDone: () async {
          // 重新加载以获取更新后的 session
          final updated = await service.getSession(widget.sessionId);
          if (mounted) {
            setState(() => _session = updated);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('面试报告')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('面试报告')),
        body: const Center(child: Text('未找到面试记录')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('面试报告')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 综合得分卡片
          _buildScoreCard(),
          const SizedBox(height: 16),

          // 维度平均分
          _buildDimensionBars(),
          const SizedBox(height: 20),

          // 逐题回顾
          const Text(
            '逐题回顾',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._scores.asMap().entries.map((e) => _buildScoreDetail(e.key, e.value)),

          // AI 综合建议
          const SizedBox(height: 20),
          const Text(
            'AI 综合建议',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _session!.totalScore;
    final scoreColor = score >= 7
        ? const Color(0xFF43E97B)
        : score >= 5
            ? const Color(0xFFF7971E)
            : const Color(0xFFf5576c);

    final gradient = LinearGradient(
      colors: [scoreColor, scoreColor.withValues(alpha: 0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '综合得分',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '${_session!.category} · ${_session!.totalQuestions} 题',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionBars() {
    if (_scores.isEmpty) return const SizedBox.shrink();

    final avgContent =
        _scores.fold(0.0, (s, e) => s + e.contentScore) / _scores.length;
    final avgExpression =
        _scores.fold(0.0, (s, e) => s + e.expressionScore) / _scores.length;
    final avgTime =
        _scores.fold(0.0, (s, e) => s + e.timeScore) / _scores.length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '各维度分析',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildBar('内容', avgContent, const Color(0xFF667eea)),
          const SizedBox(height: 10),
          _buildBar('表达', avgExpression, const Color(0xFF43E97B)),
          const SizedBox(height: 10),
          _buildBar('时间', avgTime, const Color(0xFFF7971E)),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (value / 10).clamp(0.0, 1.0),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDetail(int index, InterviewScore score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '综合 ${score.totalScore.toStringAsFixed(1)} 分',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              '${score.timeSpent}s',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        children: [
          // 三维度分
          Row(
            children: [
              _buildMiniScore('内容', score.contentScore),
              _buildMiniScore('表达', score.expressionScore),
              _buildMiniScore('时间', score.timeScore),
            ],
          ),
          const Divider(height: 16),

          // 用户答案
          _buildSection('我的回答', score.userAnswer),
          if (score.aiComment != null && score.aiComment!.isNotEmpty) ...[
            const Divider(height: 16),
            const Text('AI 点评', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            MarkdownBody(data: score.aiComment!),
          ],
          if (score.followUpQuestion != null &&
              score.followUpQuestion!.isNotEmpty) ...[
            const Divider(height: 16),
            _buildSection('追问', score.followUpQuestion!),
            if (score.followUpAnswer != null)
              _buildSection('追问回答', score.followUpAnswer!),
            if (score.followUpComment != null &&
                score.followUpComment!.isNotEmpty) ...[
              const Text('追问点评', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              MarkdownBody(data: score.followUpComment!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMiniScore(String label, double value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildSection(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_summary.isEmpty) {
      return const GlassCard(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('正在生成综合评价...'),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(data: _summary),
    );
  }
}
