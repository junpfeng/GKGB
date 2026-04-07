import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wrong_analysis_service.dart';
import '../widgets/glass_card.dart';
import 'practice_screen.dart';

/// 知识图谱页：按科目分组，各 category 卡片展示正确率
class KnowledgeMapScreen extends StatefulWidget {
  const KnowledgeMapScreen({super.key});

  @override
  State<KnowledgeMapScreen> createState() => _KnowledgeMapScreenState();
}

class _KnowledgeMapScreenState extends State<KnowledgeMapScreen> {
  // 科目 → [ {category, total, correct, accuracy} ]
  Map<String, List<Map<String, dynamic>>> _subjectMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = context.read<WrongAnalysisService>();
    final rows = await service.getCategoryAccuracy();
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final subject = row['subject'] as String;
      final category = row['category'] as String;
      final total = (row['total'] as int?) ?? 0;
      final correct = (row['correct'] as int?) ?? 0;
      final accuracy = total > 0 ? correct / total : -1.0; // -1 表示无数据
      map.putIfAbsent(subject, () => []).add({
        'category': category,
        'total': total,
        'correct': correct,
        'accuracy': accuracy,
      });
    }
    if (mounted) {
      setState(() {
        _subjectMap = map;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知识图谱')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjectMap.isEmpty
              ? const Center(child: Text('暂无题目数据'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: _subjectMap.entries.map((entry) {
                      return _buildSubjectSection(entry.key, entry.value);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildSubjectSection(String subject, List<Map<String, dynamic>> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: _subjectGradient(subject),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subject,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((cat) => _buildCategoryCard(subject, cat)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryCard(String subject, Map<String, dynamic> cat) {
    final category = cat['category'] as String;
    final total = cat['total'] as int;
    final correct = cat['correct'] as int;
    final accuracy = cat['accuracy'] as double;

    // 颜色渐变：>= 80% 绿色、60-80% 黄色、< 60% 红色、无数据灰色
    Color cardColor;
    String accuracyText;
    if (accuracy < 0) {
      cardColor = Colors.grey[300]!;
      accuracyText = '暂无数据';
    } else {
      final pct = (accuracy * 100).toStringAsFixed(0);
      accuracyText = '正确率 $pct%';
      if (accuracy >= 0.8) {
        cardColor = const Color(0xFF43E97B);
      } else if (accuracy >= 0.6) {
        cardColor = const Color(0xFFF7971E);
      } else {
        cardColor = const Color(0xFFE74C3C);
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionListScreen(
            subject: subject,
            category: category,
            title: category,
          ),
        ),
      ),
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (accuracy >= 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: accuracy,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(cardColor),
                    minHeight: 6,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                accuracyText,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (total > 0)
                Text(
                  '$correct/$total 题',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _subjectGradient(String subject) {
    switch (subject) {
      case '行测':
        return const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]);
      case '申论':
        return const LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]);
      case '公基':
        return const LinearGradient(colors: [Color(0xFF09A6C3), Color(0xFF0ED2F7)]);
      default:
        return const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]);
    }
  }
}
