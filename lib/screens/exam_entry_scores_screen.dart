import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_entry_score.dart';
import '../services/exam_entry_score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// 进面分数线分析页面
class ExamEntryScoresScreen extends StatefulWidget {
  const ExamEntryScoresScreen({super.key});

  @override
  State<ExamEntryScoresScreen> createState() => _ExamEntryScoresScreenState();
}

class _ExamEntryScoresScreenState extends State<ExamEntryScoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 首次导入预置数据并加载
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<ExamEntryScoreService>();
      await service.loadFromAssets();
      await service.initFilters();
      await service.loadScores();
      service.getHeatRanking();
    });

    // 分页加载
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      context.read<ExamEntryScoreService>().getHeatRanking();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final service = context.read<ExamEntryScoreService>();
      if (!service.isLoading && service.scores.length < service.totalCount) {
        service.loadScores(offset: service.scores.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('进面分数线'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '分数线列表'),
            Tab(text: '热度排行'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 筛选栏
          _buildFilterBar(context),
          // 主体内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScoreList(context),
                _buildHeatRanking(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 筛选栏 =====

  Widget _buildFilterBar(BuildContext context) {
    return Consumer<ExamEntryScoreService>(
      builder: (context, service, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 考试类型
              _FilterChipDropdown(
                label: service.selectedExamType ?? '考试类型',
                items: ExamEntryScoreService.examTypes,
                selected: service.selectedExamType,
                onSelected: (v) => service.setExamType(v),
              ),
              // 省份
              _FilterChipDropdown(
                label: service.selectedProvince ?? '省份',
                items: ExamEntryScoreService.provinces,
                selected: service.selectedProvince,
                onSelected: (v) => service.setProvince(v),
              ),
              // 年份
              if (service.availableYears.isNotEmpty)
                _FilterChipDropdown(
                  label: service.selectedYear?.toString() ?? '年份',
                  items: service.availableYears.map((y) => y.toString()).toList(),
                  selected: service.selectedYear?.toString(),
                  onSelected: (v) => service.setYear(v != null ? int.tryParse(v) : null),
                ),
              // 城市
              if (service.availableCities.isNotEmpty)
                _FilterChipDropdown(
                  label: service.selectedCity ?? '城市',
                  items: service.availableCities,
                  selected: service.selectedCity,
                  onSelected: (v) => service.setCity(v),
                ),
              // 单位
              if (service.availableDepartments.isNotEmpty)
                _FilterChipDropdown(
                  label: service.selectedDepartment ?? '单位',
                  items: service.availableDepartments,
                  selected: service.selectedDepartment,
                  onSelected: (v) => service.setDepartment(v),
                ),
            ],
          ),
        );
      },
    );
  }

  // ===== 分数线列表 =====

  Widget _buildScoreList(BuildContext context) {
    return Consumer<ExamEntryScoreService>(
      builder: (context, service, _) {
        if (service.isLoading && service.scores.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (service.scores.isEmpty) {
          return _buildEmptyState('暂无分数线数据', '请选择筛选条件查看数据');
        }
        return Column(
          children: [
            // 结果计数
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '共 ${service.totalCount} 条记录',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: service.scores.length + (service.scores.length < service.totalCount ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= service.scores.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildScoreCard(context, service.scores[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreCard(BuildContext context, ExamEntryScore score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _showScoreDetail(context, score),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 岗位名称 + 部门
            Row(
              children: [
                Expanded(
                  child: Text(
                    score.positionName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 分数区间标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    score.scoreRangeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 部门
            Text(
              score.department,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 标签行
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildTag('${score.province} ${score.city}', Icons.location_on_outlined),
                _buildTag('${score.year}年', Icons.calendar_today_outlined),
                _buildTag(score.examType, Icons.school_outlined),
                if (score.recruitCount != null)
                  _buildTag('招${score.recruitCount}人', Icons.people_outline),
                if (score.educationReq != null)
                  _buildTag(score.educationReq!, Icons.book_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFF667eea).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 热度排行 =====

  Widget _buildHeatRanking(BuildContext context) {
    return Consumer<ExamEntryScoreService>(
      builder: (context, service, _) {
        if (service.isLoading && service.heatRanking.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (service.heatRanking.isEmpty) {
          return _buildEmptyState('暂无热度数据', '请先加载分数线数据');
        }
        // 取前 15 条做柱状图
        final chartData = service.heatRanking.take(15).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 柱状图
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '进面分数 TOP 15',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildBarChart(chartData),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 完整排行列表
            ...service.heatRanking.asMap().entries.map((entry) {
              final idx = entry.key;
              final score = entry.value;
              return _buildRankingItem(context, idx + 1, score);
            }),
          ],
        );
      },
    );
  }

  Widget _buildBarChart(List<ExamEntryScore> data) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isEmpty
            ? 100
            : (data.first.avgEntryScore ?? 0) * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final score = data[group.x];
              return BarTooltipItem(
                '${score.positionName}\n${score.avgEntryScore?.toStringAsFixed(1) ?? "-"}分',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= data.length) return const SizedBox.shrink();
                final name = data[idx].positionName;
                return SideTitleWidget(
                  meta: meta,
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Text(
                      name.length > 5 ? '${name.substring(0, 5)}...' : name,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final idx = entry.key;
          final score = entry.value;
          final avg = score.avgEntryScore ?? 0;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: avg,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingItem(BuildContext context, int rank, ExamEntryScore score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 前三名高亮
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = isDark ? Colors.grey[500]! : Colors.grey[400]!;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => _showScoreDetail(context, score),
        child: Row(
          children: [
            // 排名
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: rank <= 3 ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 岗位信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.positionName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${score.department} | ${score.city}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 平均分
            Text(
              '${score.avgEntryScore?.toStringAsFixed(1) ?? "-"}分',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 详情弹窗 =====

  void _showScoreDetail(BuildContext context, ExamEntryScore score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScoreDetailSheet(score: score),
    );
  }

  // ===== 空状态 =====

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}

// ===== 筛选下拉组件 =====

class _FilterChipDropdown extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterChipDropdown({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selected != null;
    final primaryColor = const Color(0xFF667eea);

    return PopupMenuButton<String?>(
      initialValue: selected,
      onSelected: onSelected,
      constraints: const BoxConstraints(maxHeight: 400),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: null, child: Text('全部')),
        ...items.map((item) => PopupMenuItem(value: item, child: Text(item))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey[300]!,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected ?? label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? primaryColor : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              GestureDetector(
                onTap: () => onSelected(null),
                child: Icon(Icons.close, size: 14, color: primaryColor),
              )
            else
              Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

// ===== 详情底部弹窗 =====

class _ScoreDetailSheet extends StatefulWidget {
  final ExamEntryScore score;

  const _ScoreDetailSheet({required this.score});

  @override
  State<_ScoreDetailSheet> createState() => _ScoreDetailSheetState();
}

class _ScoreDetailSheetState extends State<_ScoreDetailSheet> {
  List<ExamEntryScore>? _trendData;
  bool _loadingTrend = false;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() => _loadingTrend = true);
    final service = context.read<ExamEntryScoreService>();
    _trendData = await service.getScoreTrend(
      positionName: widget.score.positionName,
      province: widget.score.province,
      department: widget.score.department,
    );
    if (mounted) setState(() => _loadingTrend = false);
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 岗位名称
              Text(
                score.positionName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                score.department,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),

              // 分数区间卡片
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildScoreStat('最低进面', score.minEntryScore),
                    Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildScoreStat('最高进面', score.maxEntryScore),
                    Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildScoreStat('进面人数', score.entryCount?.toDouble()),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 岗位条件
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('岗位条件', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _buildConditionRow('地区', '${score.province} ${score.city}'),
                    _buildConditionRow('年份', '${score.year}年 ${score.examType}'),
                    if (score.positionCode != null)
                      _buildConditionRow('岗位代码', score.positionCode!),
                    if (score.recruitCount != null)
                      _buildConditionRow('招录人数', '${score.recruitCount}人'),
                    if (score.educationReq != null)
                      _buildConditionRow('学历要求', score.educationReq!),
                    if (score.degreeReq != null)
                      _buildConditionRow('学位要求', score.degreeReq!),
                    if (score.majorReq != null)
                      _buildConditionRow('专业要求', score.majorReq!),
                    if (score.politicalReq != null)
                      _buildConditionRow('政治面貌', score.politicalReq!),
                    if (score.workExpReq != null)
                      _buildConditionRow('工作经验', score.workExpReq!),
                    if (score.otherReq != null)
                      _buildConditionRow('其他条件', score.otherReq!),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 历年趋势图
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('历年分数趋势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_loadingTrend)
                      const Center(child: CircularProgressIndicator())
                    else if (_trendData == null || _trendData!.length < 2)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '暂无多年数据，无法绘制趋势图',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: _buildTrendChart(_trendData!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreStat(String label, double? value) {
    return Column(
      children: [
        Text(
          value != null
              ? (label.contains('人数') ? value.toInt().toString() : value.toStringAsFixed(1))
              : '-',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildConditionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<ExamEntryScore> data) {
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];
    double globalMin = double.infinity;
    double globalMax = 0;

    for (final s in data) {
      final x = s.year.toDouble();
      if (s.minEntryScore != null) {
        minSpots.add(FlSpot(x, s.minEntryScore!));
        if (s.minEntryScore! < globalMin) globalMin = s.minEntryScore!;
        if (s.minEntryScore! > globalMax) globalMax = s.minEntryScore!;
      }
      if (s.maxEntryScore != null) {
        maxSpots.add(FlSpot(x, s.maxEntryScore!));
        if (s.maxEntryScore! < globalMin) globalMin = s.maxEntryScore!;
        if (s.maxEntryScore! > globalMax) globalMax = s.maxEntryScore!;
      }
    }

    if (globalMin == double.infinity) globalMin = 0;
    final yMin = (globalMin - 10).clamp(0.0, double.infinity);
    final yMax = globalMax + 10;

    return LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          if (minSpots.length >= 2)
            LineChartBarData(
              spots: minSpots,
              isCurved: true,
              color: const Color(0xFF667eea),
              barWidth: 2,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF667eea).withValues(alpha: 0.1),
              ),
            ),
          if (maxSpots.length >= 2)
            LineChartBarData(
              spots: maxSpots,
              isCurved: true,
              color: const Color(0xFFf5576c),
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((spot) {
              final color = spot.barIndex == 0 ? '最低' : '最高';
              return LineTooltipItem(
                '$color: ${spot.y.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
