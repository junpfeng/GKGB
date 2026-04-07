import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/adaptive_quiz_service.dart';
import '../widgets/glass_card.dart';

/// 知识点掌握度总览页
class MasteryOverviewScreen extends StatefulWidget {
  const MasteryOverviewScreen({super.key});

  @override
  State<MasteryOverviewScreen> createState() => _MasteryOverviewScreenState();
}

class _MasteryOverviewScreenState extends State<MasteryOverviewScreen> {
  List<Map<String, dynamic>> _items = [];
  List<String> _subjects = [];
  String? _selectedSubject;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<AdaptiveQuizService>();
    await service.ensureInitialized();
    final subjects = await service.getSubjects();
    final items = await service.getMasteryOverview(subject: _selectedSubject);
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _onSubjectChanged(String? subject) async {
    setState(() {
      _selectedSubject = subject;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掌握度总览'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 科目筛选
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(null, '全部'),
                        ..._subjects.map((s) => _buildFilterChip(s, s)),
                      ],
                    ),
                  ),
                ),
                // 统计摘要
                _buildSummary(),
                // 知识点列表
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('暂无知识点数据，请先做几道题'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _items.length,
                          itemBuilder: (context, index) =>
                              _buildKnowledgePointItem(_items[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final selected = _selectedSubject == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _onSubjectChanged(value),
        selectedColor: const Color(0xFF667eea).withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF667eea) : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_items.isEmpty) return const SizedBox();
    final avgScore = _items.fold<double>(
          0,
          (sum, r) => sum + ((r['score'] as num?)?.toDouble() ?? 50),
        ) /
        _items.length;
    final weakCount =
        _items.where((r) => ((r['score'] as num?)?.toDouble() ?? 50) < 60).length;
    final masteredCount =
        _items.where((r) => ((r['score'] as num?)?.toDouble() ?? 50) >= 80).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('平均掌握度', '${avgScore.toStringAsFixed(0)}%',
                _getScoreColor(avgScore)),
            _buildStatItem('薄弱项', '$weakCount', Colors.red),
            _buildStatItem('已掌握', '$masteredCount', Colors.green),
            _buildStatItem('总知识点', '${_items.length}', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildKnowledgePointItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final subject = item['subject'] as String? ?? '';
    final score = (item['score'] as num?)?.toDouble() ?? 50;
    final totalAttempts = (item['total_attempts'] as int?) ?? 0;
    final nextReview = item['next_review_at'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 科目标签
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${score.toStringAsFixed(0)}分',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(score),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '练习 $totalAttempts 次',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const Spacer(),
                if (nextReview != null)
                  Text(
                    '下次复习：${_formatReviewDate(nextReview)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatReviewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff <= 0) return '今天';
      if (diff == 1) return '明天';
      return '$diff天后';
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }
}
