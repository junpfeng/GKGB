import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../models/real_exam_paper.dart';
import '../services/real_exam_service.dart';
import '../services/exam_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'exam_screen.dart';

/// 真题试卷详情页：题目列表按原始题序 + 开始模考按钮
class RealExamPaperScreen extends StatefulWidget {
  final int paperId;

  const RealExamPaperScreen({super.key, required this.paperId});

  @override
  State<RealExamPaperScreen> createState() => _RealExamPaperScreenState();
}

class _RealExamPaperScreenState extends State<RealExamPaperScreen> {
  RealExamPaper? _paper;
  List<Question> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rs = context.read<RealExamService>();
    final paper = await rs.getPaperById(widget.paperId);
    if (paper == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final questions = await rs.loadPaperQuestions(widget.paperId);
    if (mounted) {
      setState(() {
        _paper = paper;
        _questions = questions;
        _loading = false;
      });
    }
  }

  Future<void> _startPaperExam() async {
    if (_paper == null || _questions.isEmpty) return;

    try {
      await context.read<ExamService>().startPaperExam(
        paperId: _paper!.id!,
        subject: _paper!.subject,
        questions: _questions,
        timeLimitSeconds: _paper!.timeLimit,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExamScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动模考失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('试卷详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_paper == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('试卷详情')),
        body: const Center(child: Text('试卷不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_paper!.name)),
      body: Column(
        children: [
          // 试卷信息卡片
          _buildPaperInfo(),
          // 题目列表
          Expanded(
            child: _questions.isEmpty
                ? const Center(child: Text('暂无题目'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
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
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${q.category} · ${_questionTypeLabel(q.type)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // 底部模考按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                onPressed: _questions.isNotEmpty ? _startPaperExam : null,
                label: '开始模考',
                icon: Icons.timer,
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperInfo() {
    return GlassCard(
      borderRadius: 0,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.infoGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_paper!.examType} · ${_paper!.region} · ${_paper!.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_questions.length}题 · ${_paper!.timeLimit ~/ 60}分钟 · 总分${_paper!.totalScore.round()}分',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'single':
        return '单选';
      case 'multiple':
        return '多选';
      case 'judge':
        return '判断';
      case 'subjective':
        return '主观';
      default:
        return type;
    }
  }
}
