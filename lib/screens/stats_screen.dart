import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/question_service.dart';
import '../services/exam_service.dart';
import '../widgets/progress_ring.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';

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
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
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

/// 概览 Tab
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
    final total = (todayStats['total'] as int?) ?? 0;
    final correct = (todayStats['correct'] as int?) ?? 0;
    final accuracy = total == 0 ? 0.0 : correct / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 今日数据三栏渐变卡片
        Row(
          children: [
            Expanded(
              child: _GradientStatCard(
                label: '今日做题',
                value: '$total',
                gradient: AppTheme.primaryGradient,
                icon: Icons.edit_note,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GradientStatCard(
                label: '正确数',
                value: '$correct',
                gradient: AppTheme.successGradient,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GradientStatCard(
                label: '正确率',
                value: '${(accuracy * 100).round()}%',
                gradient: AppTheme.infoGradient,
                icon: Icons.percent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 今日学习详细卡片（进度环）
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日学习',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 渐变进度环
                  ProgressRing(
                    progress: accuracy,
                    size: 80,
                    color: const Color(0xFF667eea),
                    child: Text(
                      '${(accuracy * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 16),
        // 累计数据三栏
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '累计数据',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: '总做题',
                    value: '${totalStats['total'] as int? ?? 0}',
                  ),
                  _StatItem(
                    label: '总正确率',
                    value: (totalStats['total'] as int? ?? 0) == 0
                        ? '0%'
                        : '${((totalStats['correct'] as int? ?? 0) / (totalStats['total'] as int? ?? 1) * 100).round()}%',
                  ),
                  _StatItem(
                    label: '错题数',
                    value:
                        '${((totalStats['total'] as int? ?? 0) - (totalStats['correct'] as int? ?? 0))}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (subjectStats.isNotEmpty) ...[
          Text(
            '各科目正确率',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          ...subjectStats.map((stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SubjectAccuracyCard(stat: stat),
              )),
        ],
      ],
    );
  }
}

/// 渐变数值统计小卡片
class _GradientStatCard extends StatelessWidget {
  final String label;
  final String value;
  final LinearGradient gradient;
  final IconData icon;

  const _GradientStatCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: gradient,
      borderRadius: AppTheme.radiusMedium,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
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
  int _limit = 10;
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
              _RangeChip(
                  label: '7次', selected: _limit == 7, onTap: () => _setLimit(7)),
              const SizedBox(width: 6),
              _RangeChip(
                  label: '10次',
                  selected: _limit == 10,
                  onTap: () => _setLimit(10)),
              const SizedBox(width: 6),
              _RangeChip(
                  label: '30次',
                  selected: _limit == 30,
                  onTap: () => _setLimit(30)),
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
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: _TrendChart(trendData: _trendData),
                      ),
                    ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF667eea).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

/// 成绩趋势折线图（渐变填充）
class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  const _TrendChart({required this.trendData});

  @override
  Widget build(BuildContext context) {
    final subjectGroups = <String, List<Map<String, dynamic>>>{};
    for (final item in trendData) {
      final subject = item['subject'] as String;
      subjectGroups.putIfAbsent(subject, () => []).add(item);
    }

    // 使用渐变主题色
    const lineColors = [
      Color(0xFF667eea),
      Color(0xFF0ED2F7),
      Color(0xFF43E97B),
      Color(0xFFf093fb),
      Color(0xFFF7971E),
    ];

    final subjects = subjectGroups.keys.toList();

    final lineBarsData = <LineChartBarData>[];
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final items = subjectGroups[subject]!;
      final color = lineColors[i % lineColors.length];

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
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          // 渐变填充面积
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图例
        Wrap(
          spacing: 16,
          children: subjects.asMap().entries.map((entry) {
            final color = lineColors[entry.key % lineColors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 3, color: color),
                const SizedBox(width: 4),
                Text(entry.value, style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
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
                      final allItems = trendData
                          .where((d) =>
                              (d['subject'] as String) == subjects.first)
                          .toList();
                      if (index < 0 || index >= allItems.length) {
                        return const SizedBox.shrink();
                      }
                      final date = allItems[index]['date'] as String;
                      final shortDate =
                          date.length >= 10 ? date.substring(5, 10) : date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(shortDate,
                            style: const TextStyle(fontSize: 9)),
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
                      return Text('${value.toInt()}',
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.2)),
                  left: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.2)),
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
                          color: lineColors[subjectIndex % lineColors.length],
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
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF667eea),
              ),
        ),
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

    final gradient = accuracy >= 0.8
        ? AppTheme.successGradient
        : accuracy >= 0.6
            ? AppTheme.warningGradient
            : AppTheme.warmGradient;
    final barColor = accuracy >= 0.8
        ? const Color(0xFF43E97B)
        : accuracy >= 0.6
            ? const Color(0xFFF7971E)
            : const Color(0xFFf5576c);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // 科目标签（渐变背景）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subject,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: accuracy,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(barColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$correct / $total 题正确',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(accuracy * 100).round()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: barColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
