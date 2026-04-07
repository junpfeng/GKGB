import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/error_analysis.dart';
import '../services/wrong_analysis_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'knowledge_map_screen.dart';

/// 错题深度分析主页
class WrongAnalysisScreen extends StatefulWidget {
  const WrongAnalysisScreen({super.key});

  @override
  State<WrongAnalysisScreen> createState() => _WrongAnalysisScreenState();
}

class _WrongAnalysisScreenState extends State<WrongAnalysisScreen> {
  Map<String, int> _errorDistribution = {};
  List<Map<String, dynamic>> _topCategories = [];
  bool _loading = true;
  bool _reportLoading = false;
  String _reportText = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = context.read<WrongAnalysisService>();
    final distribution = await service.getErrorTypeDistribution();
    final topCategories = await service.getTopWrongCategories();
    if (mounted) {
      setState(() {
        _errorDistribution = distribution;
        _topCategories = topCategories;
        _loading = false;
      });
    }
  }

  void _generateReport() {
    setState(() {
      _reportLoading = true;
      _reportText = '';
    });
    final service = context.read<WrongAnalysisService>();
    service.generateDiagnosisReport().listen(
      (chunk) {
        if (mounted) setState(() => _reportText += chunk);
      },
      onDone: () {
        if (mounted) setState(() => _reportLoading = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _reportText += '\n生成失败: $e';
            _reportLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错题深度分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: '知识图谱',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KnowledgeMapScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildErrorPieChart(),
                  const SizedBox(height: 20),
                  _buildTopWrongCategories(),
                  const SizedBox(height: 20),
                  _buildDiagnosisReport(),
                ],
              ),
            ),
    );
  }

  /// 错因分布饼图
  Widget _buildErrorPieChart() {
    final total = _errorDistribution.values.fold(0, (a, b) => a + b);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '错因分布',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (total == 0)
            const SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('暂无错因数据，答错题目后 AI 将自动分析', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: _buildPieSections(total),
                  centerSpaceRadius: 36,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: _errorDistribution.entries.map((e) {
                final color = Color(ErrorAnalysis.errorTypeColors[e.key] ?? 0xFF999999);
                final label = ErrorAnalysis.errorTypeLabels[e.key] ?? e.key;
                final pct = (e.value / total * 100).toStringAsFixed(0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('$label $pct%', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(int total) {
    return _errorDistribution.entries.map((e) {
      final color = Color(ErrorAnalysis.errorTypeColors[e.key] ?? 0xFF999999);
      final pct = e.value / total * 100;
      return PieChartSectionData(
        color: color,
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 50,
      );
    }).toList();
  }

  /// 高频错误知识点 TOP 10
  Widget _buildTopWrongCategories() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '高频错误知识点 TOP 10',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_topCategories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无错题数据', style: TextStyle(color: Colors.grey))),
            )
          else
            ...List.generate(_topCategories.length, (i) {
              final item = _topCategories[i];
              final category = item['category'] as String;
              final subject = item['subject'] as String;
              final count = item['wrong_count'] as int;
              final maxCount = (_topCategories.first['wrong_count'] as int).toDouble();
              final ratio = count / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: i < 3 ? const Color(0xFFE74C3C) : Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(subject, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            i < 3 ? const Color(0xFFE74C3C) : const Color(0xFF3498DB),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count题', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// AI 诊断报告
  Widget _buildDiagnosisReport() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI 诊断报告',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (!_reportLoading)
                GradientButton(
                  onPressed: _generateReport,
                  label: _reportText.isEmpty ? '生成报告' : '重新生成',
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  borderRadius: 8,
                  gradient: AppTheme.primaryGradient,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_reportLoading && _reportText.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reportText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _reportText,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('点击「生成报告」获取 AI 诊断分析', style: TextStyle(color: Colors.grey)),
              ),
            ),
          if (_reportLoading && _reportText.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
