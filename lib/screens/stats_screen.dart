import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/question_service.dart';
import '../widgets/progress_ring.dart';

/// 学习统计页
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _todayStats = {'total': 0, 'correct': 0};
  Map<String, dynamic> _totalStats = {'total': 0, 'correct': 0, 'favorites': 0};
  List<Map<String, dynamic>> _subjectStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final service = context.read<QuestionService>();
    final today = await service.getTodayStats();
    await service.refreshStats();
    final total = {
      'total': service.answeredCount,
      'correct': service.correctCount,
      'favorites': 0,
    };
    final subjectAccuracy = await service.getAccuracyBySubject();
    if (mounted) {
      setState(() {
        _todayStats = today;
        _totalStats = total;
        _subjectStats = subjectAccuracy;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 今日统计卡片
                _TodayStatsCard(stats: _todayStats),
                const SizedBox(height: 16),
                // 累计统计卡片
                _TotalStatsCard(
                  total: _totalStats['total'] as int,
                  correct: _totalStats['correct'] as int,
                  favorites: _totalStats['favorites'] as int,
                ),
                const SizedBox(height: 16),
                // 各科目正确率
                if (_subjectStats.isNotEmpty) ...[
                  Text('各科目正确率', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._subjectStats.map((stat) => _SubjectAccuracyCard(stat: stat)),
                ],
              ],
            ),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _TodayStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = (stats['total'] as int?) ?? 0;
    final correct = (stats['correct'] as int?) ?? 0;
    final accuracy = total == 0 ? 0.0 : correct / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日学习', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ProgressRing(
                  progress: accuracy,
                  size: 80,
                  child: Text(
                    '${(accuracy * 100).round()}%',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatItem(label: '做题数', value: '$total'),
                _StatItem(label: '正确数', value: '$correct'),
                _StatItem(label: '错误数', value: '${total - correct}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalStatsCard extends StatelessWidget {
  final int total;
  final int correct;
  final int favorites;
  const _TotalStatsCard({
    required this.total,
    required this.correct,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('累计数据', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: '总做题', value: '$total'),
                _StatItem(
                  label: '总正确率',
                  value: total == 0 ? '0%' : '${(correct / total * 100).round()}%',
                ),
                _StatItem(label: '错题数', value: '${total - correct}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _SubjectAccuracyCard extends StatelessWidget {
  final Map<String, dynamic> stat;
  const _SubjectAccuracyCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final subject = stat['subject'] as String? ?? '未知';
    final total = (stat['total'] as int?) ?? 0;
    final correct = (stat['correct'] as int?) ?? 0;
    final accuracy = total == 0 ? 0.0 : correct / total;

    final color = accuracy >= 0.8
        ? Colors.green
        : accuracy >= 0.6
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: accuracy,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$correct / $total 题正确',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(accuracy * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
