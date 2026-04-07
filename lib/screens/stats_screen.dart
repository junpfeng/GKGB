import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/question_service.dart';
import '../services/exam_service.dart';
import '../widgets/progress_ring.dart';

/// 学习统计页（含趋势 Tab）
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _todayStats = {'total': 0, 'correct': 0};
  Map<String, dynamic> _totalStats = {'total': 0, 'correct': 0, 'favorites': 0};
  List<Map<String, dynamic>> _subjectStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '趋势'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  todayStats: _todayStats,
                  totalStats: _totalStats,
                  subjectStats: _subjectStats,
                ),
                const _TrendTab(),
              ],
            ),
    );
  }
}

/// 概览 Tab（原有内容）
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> todayStats;
  final Map<String, dynamic> totalStats;
  final List<Map<String, dynamic>> subjectStats;

  const _OverviewTab({
    required this.todayStats,
    required this.totalStats,
    required this.subjectStats,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TodayStatsCard(stats: todayStats),
        const SizedBox(height: 16),
        _TotalStatsCard(
          total: totalStats['total'] as int,
          correct: totalStats['correct'] as int,
          favorites: totalStats['favorites'] as int,
        ),
        const SizedBox(height: 16),
        if (subjectStats.isNotEmpty) ...[
          Text('各科目正确率', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...subjectStats.map((stat) => _SubjectAccuracyCard(stat: stat)),
        ],
      ],
    );
  }
}

/// 趋势 Tab（fl_chart 折线图）
class _TrendTab extends StatefulWidget {
  const _TrendTab();

  @override
  State<_TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<_TrendTab> {
  int _limit = 10; // 近10次
  List<Map<String, dynamic>> _trendData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() => _loading = true);
    try {
      final examService = context.read<ExamService>();
      final data = await examService.getScoreTrend(limit: _limit);
      if (mounted) {
        setState(() {
          _trendData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 时间范围切换
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('显示近：', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              _RangeChip(label: '7次', selected: _limit == 7, onTap: () => _setLimit(7)),
              const SizedBox(width: 6),
              _RangeChip(label: '10次', selected: _limit == 10, onTap: () => _setLimit(10)),
              const SizedBox(width: 6),
              _RangeChip(label: '30次', selected: _limit == 30, onTap: () => _setLimit(30)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _trendData.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无考试记录', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 8),
                          Text(
                            '完成几次模拟考试后，\n这里会展示你的成绩趋势',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _TrendChart(trendData: _trendData),
        ),
      ],
    );
  }

  void _setLimit(int limit) {
    _limit = limit;
    _loadTrend();
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : null,
          ),
        ),
      ),
    );
  }
}

/// 成绩趋势折线图
class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  const _TrendChart({required this.trendData});

  @override
  Widget build(BuildContext context) {
    // 按科目分组
    final subjectGroups = <String, List<Map<String, dynamic>>>{};
    for (final item in trendData) {
      final subject = item['subject'] as String;
      subjectGroups.putIfAbsent(subject, () => []).add(item);
    }

    // 颜色列表
    const colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
    ];

    final subjects = subjectGroups.keys.toList();

    // 生成各科折线数据
    final lineBarsData = <LineChartBarData>[];
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final items = subjectGroups[subject]!;
      final color = colors[i % colors.length];

      final spots = items.asMap().entries.map((entry) {
        return FlSpot(
          entry.key.toDouble(),
          (entry.value['score'] as double).clamp(0, 100),
        );
      }).toList();

      lineBarsData.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.08),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图例
          Wrap(
            spacing: 16,
            children: subjects.asMap().entries.map((entry) {
              final color = colors[entry.key % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(entry.value, style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: lineBarsData,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // 取所有数据的日期（以第一个科目为准）
                        final allItems = trendData
                            .where((d) =>
                                (d['subject'] as String) == subjects.first)
                            .toList();
                        if (index < 0 || index >= allItems.length) {
                          return const SizedBox.shrink();
                        }
                        final date = allItems[index]['date'] as String;
                        // 只显示月/日
                        final shortDate = date.length >= 10
                            ? date.substring(5, 10)
                            : date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            shortDate,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value % 20 != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    left: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.surface,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final subjectIndex = lineBarsData.indexOf(spot.bar);
                        final subject = subjectIndex >= 0 &&
                                subjectIndex < subjects.length
                            ? subjects[subjectIndex]
                            : '';
                        return LineTooltipItem(
                          '$subject\n${spot.y.toStringAsFixed(1)}分',
                          TextStyle(
                            color: colors[subjectIndex % colors.length],
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
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
