import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_service.dart';
import '../services/calendar_service.dart';
import '../services/exam_category_service.dart';
import '../widgets/radar_chart_widget.dart';
import '../widgets/heatmap_widget.dart';
import '../widgets/glass_card.dart';
import '../widgets/progress_ring.dart';
import '../theme/app_theme.dart';
import 'exam_calendar_screen.dart';
import 'exam_entry_scores_screen.dart';

/// 个性化数据看板（替换原 StatsScreen）
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // AI 周报状态
  bool _isGeneratingReport = false;
  String _reportContent = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardService>().refreshDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据看板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DashboardService>().refreshDashboard(force: true);
            },
          ),
        ],
      ),
      body: Consumer<DashboardService>(
        builder: (context, service, _) {
          if (service.isLoading && !service.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!service.hasData) {
            return _buildEmptyState();
          }
          return _buildDashboard(context, service.data!);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无学习数据', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '开始做题后，这里会展示你的学习看板',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardData data) {
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardService>().refreshDashboard(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 备考倒计时（设置了目标考试日期时展示）
          _buildExamCountdown(context),
          // 考试日历入口
          _buildCalendarEntry(context),
          const SizedBox(height: 8),
          // 进面分数线入口
          _buildEntryScoresEntry(context),
          const SizedBox(height: 16),
          // 今日概览
          _buildTodayOverview(context, data),
          const SizedBox(height: 16),
          // 连续打卡 + 备考进度
          _buildStreakAndProgress(context, data),
          const SizedBox(height: 16),
          // 能力雷达图
          _buildRadarSection(context, data),
          const SizedBox(height: 16),
          // 学习热力图
          _buildHeatmapSection(context, data),
          const SizedBox(height: 16),
          // 模考成绩趋势
          _buildScoreTrend(context, data),
          const SizedBox(height: 16),
          // 本周 vs 上周
          _buildWeekComparison(context, data),
          const SizedBox(height: 16),
          // AI 周报
          _buildWeeklyReport(context),
        ],
      ),
    );
  }

  // ===== 备考倒计时 =====

  Widget _buildExamCountdown(BuildContext context) {
    final examService = context.watch<ExamCategoryService>();
    final targetDateStr = examService.primaryTarget?.targetExamDate;
    if (targetDateStr == null || targetDateStr.isEmpty) {
      return const SizedBox.shrink();
    }
    final targetDate = DateTime.tryParse(targetDateStr);
    if (targetDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysLeft = targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    // 选择倒计时渐变色：紧急程度递增
    final gradient = daysLeft <= 7
        ? AppTheme.warmGradient
        : daysLeft <= 30
            ? AppTheme.warningGradient
            : AppTheme.primaryGradient;

    final countdownText = daysLeft < 0
        ? '考试已结束'
        : daysLeft == 0
            ? '今天就是考试日！'
            : '距 ${examService.activeCategory?.label ?? '目标考试'} 还有 $daysLeft 天';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GradientCard(
        gradient: gradient,
        borderRadius: AppTheme.radiusMedium,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countdownText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    targetDateStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (daysLeft >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysLeft',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== 考试日历入口 =====

  Widget _buildCalendarEntry(BuildContext context) {
    return GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF0ED2F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: AppTheme.radiusMedium,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExamCalendarScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '考试日历',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<CalendarService>(
                      builder: (context, service, _) {
                        final upcoming = service.events
                            .where((e) => e.nextMilestone != null)
                            .length;
                        return Text(
                          upcoming > 0
                              ? '$upcoming 场考试即将到来'
                              : '查看考试日程安排',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 进面分数线入口 =====

  Widget _buildEntryScoresEntry(BuildContext context) {
    return GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFf093fb), Color(0xFF764ba2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: AppTheme.radiusMedium,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExamEntryScoresScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '进面分数线',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '查看各岗位进面分数线与热度排行',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 今日概览 =====

  Widget _buildTodayOverview(BuildContext context, DashboardData data) {
    final overview = data.todayOverview;
    final answered = overview['answeredToday'] as int? ?? 0;
    final correct = overview['correctToday'] as int? ?? 0;
    final accuracy = answered == 0 ? 0.0 : correct / answered;

    return Row(
      children: [
        Expanded(
          child: _GradientStatCard(
            label: '今日做题',
            value: '$answered',
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
    );
  }

  // ===== 连续打卡 + 备考进度 =====

  Widget _buildStreakAndProgress(BuildContext context, DashboardData data) {
    return Row(
      children: [
        // 连续打卡徽章
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: data.studyStreak > 0
                        ? AppTheme.warningGradient
                        : null,
                    color: data.studyStreak > 0 ? null : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_fire_department,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.studyStreak}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF7971E),
                            ),
                      ),
                      Text('连续打卡天数',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 备考进度
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ProgressRing(
                  progress: data.overallProgress,
                  size: 44,
                  color: const Color(0xFF667eea),
                  child: Text(
                    '${(data.overallProgress * 100).round()}%',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '备考进度',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        data.overallProgress == 0 ? '暂无计划' : '学习计划完成度',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== 能力雷达图 =====

  Widget _buildRadarSection(BuildContext context, DashboardData data) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '能力雷达图',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '各科目正确率分布',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          data.radarData.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('完成各科练习后展示',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : RadarChartWidget(data: data.radarData),
        ],
      ),
    );
  }

  // ===== 学习热力图 =====

  Widget _buildHeatmapSection(BuildContext context, DashboardData data) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习热力图',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '近 90 天每日学习强度',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          HeatmapWidget(data: data.heatmapData),
        ],
      ),
    );
  }

  // ===== 模考成绩趋势 =====

  Widget _buildScoreTrend(BuildContext context, DashboardData data) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '模考成绩趋势',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '近 10 次模拟考试',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          data.scoreTrend.isEmpty
              ? SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('完成模拟考试后展示趋势',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: _ScoreTrendChart(trendData: data.scoreTrend),
                ),
        ],
      ),
    );
  }

  // ===== 本周 vs 上周 =====

  Widget _buildWeekComparison(BuildContext context, DashboardData data) {
    final thisWeek = data.weekComparison['thisWeek'] ?? {};
    final lastWeek = data.weekComparison['lastWeek'] ?? {};
    final thisTotal = (thisWeek['total'] as int?) ?? 0;
    final lastTotal = (lastWeek['total'] as int?) ?? 0;
    final thisCorrect = (thisWeek['correct'] as int?) ?? 0;
    final lastCorrect = (lastWeek['correct'] as int?) ?? 0;
    final thisAcc = thisTotal == 0 ? 0.0 : thisCorrect / thisTotal * 100;
    final lastAcc = lastTotal == 0 ? 0.0 : lastCorrect / lastTotal * 100;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '周对比',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _ComparisonRow(
            label: '做题量',
            thisWeek: thisTotal.toDouble(),
            lastWeek: lastTotal.toDouble(),
            unit: '题',
          ),
          const SizedBox(height: 12),
          _ComparisonRow(
            label: '正确率',
            thisWeek: thisAcc,
            lastWeek: lastAcc,
            unit: '%',
            isPercentage: true,
          ),
        ],
      ),
    );
  }

  // ===== AI 周报 =====

  Widget _buildWeeklyReport(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI 学习周报',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isGeneratingReport ? null : _generateReport,
                icon: _isGeneratingReport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isGeneratingReport ? '生成中...' : '生成周报'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (_reportContent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _reportContent,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey[800],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _generateReport() {
    final service = context.read<DashboardService>();
    setState(() {
      _isGeneratingReport = true;
      _reportContent = '';
    });

    service.generateWeeklyReport().listen(
      (chunk) {
        if (mounted) {
          setState(() => _reportContent += chunk);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isGeneratingReport = false;
            _reportContent = '生成失败：$e\n请检查是否已配置 AI 模型。';
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isGeneratingReport = false);
        }
      },
    );
  }
}

// ===== 内部组件 =====

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

/// 模考成绩趋势折线图
class _ScoreTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  const _ScoreTrendChart({required this.trendData});

  @override
  Widget build(BuildContext context) {
    // 按科目分组
    final subjectGroups = <String, List<Map<String, dynamic>>>{};
    for (final item in trendData) {
      final subject = item['subject'] as String;
      subjectGroups.putIfAbsent(subject, () => []).add(item);
    }

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
      final items = subjectGroups[subjects[i]]!;
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
            radius: 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
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

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: lineBarsData,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                final allItems = trendData
                    .where((d) => (d['subject'] as String) == subjects.first)
                    .toList();
                if (index < 0 || index >= allItems.length) {
                  return const SizedBox.shrink();
                }
                final date = allItems[index]['date'] as String;
                final shortDate = date.length >= 10 ? date.substring(5, 10) : date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(shortDate, style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text('${value.toInt()}', style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            left: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }
}

/// 周对比行
class _ComparisonRow extends StatelessWidget {
  final String label;
  final double thisWeek;
  final double lastWeek;
  final String unit;
  final bool isPercentage;

  const _ComparisonRow({
    required this.label,
    required this.thisWeek,
    required this.lastWeek,
    required this.unit,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = thisWeek > lastWeek ? thisWeek : lastWeek;
    final thisRatio = maxVal == 0 ? 0.0 : thisWeek / maxVal;
    final lastRatio = maxVal == 0 ? 0.0 : lastWeek / maxVal;
    final diff = thisWeek - lastWeek;
    final diffStr = isPercentage
        ? '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}$unit'
        : '${diff >= 0 ? '+' : ''}${diff.toInt()}$unit';
    final diffColor = diff > 0
        ? const Color(0xFF43E97B)
        : diff < 0
            ? const Color(0xFFf5576c)
            : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(diffStr, style: TextStyle(fontSize: 12, color: diffColor, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        // 本周条
        _BarRow(
          label: '本周',
          value: isPercentage ? '${thisWeek.toStringAsFixed(1)}$unit' : '${thisWeek.toInt()}$unit',
          ratio: thisRatio,
          color: const Color(0xFF667eea),
        ),
        const SizedBox(height: 4),
        // 上周条
        _BarRow(
          label: '上周',
          value: isPercentage ? '${lastWeek.toStringAsFixed(1)}$unit' : '${lastWeek.toInt()}$unit',
          ratio: lastRatio,
          color: Colors.grey[400]!,
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            value,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
