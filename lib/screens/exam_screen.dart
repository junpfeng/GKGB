import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exam_service.dart';
import '../services/question_service.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';
import '../widgets/ai_chat_dialog.dart';

/// 模拟考试页：配置 → 答题 → 评分报告
class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExamService>(
      builder: (context, examService, _) {
        if (examService.currentExam != null &&
            examService.currentExam!.status == 'ongoing') {
          return _ExamingView(examService: examService);
        }
        return _ExamHomeView(examService: examService);
      },
    );
  }
}

/// 考试主界面（配置 + 历史）
class _ExamHomeView extends StatelessWidget {
  final ExamService examService;
  const _ExamHomeView({required this.examService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模拟考试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 快速开始卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快速模考', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('按真实考试时间和题量进行模拟', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ExamTypeCard(
                          title: '行测模考',
                          subtitle: '130题 · 120分钟',
                          color: Colors.blue,
                          onTap: () => _startExam(context, '行测', 30, 120 * 60),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExamTypeCard(
                          title: '自定义模考',
                          subtitle: '选择科目和题量',
                          color: Colors.purple,
                          onTap: () => _showCustomExamDialog(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 历史记录
          Text('历史成绩', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (examService.history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('暂无历史成绩，开始第一次模考吧', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ...examService.history.map((exam) => _ExamHistoryCard(exam: exam)),
        ],
      ),
    );
  }

  Future<void> _startExam(
    BuildContext context,
    String subject,
    int count,
    int timeLimitSeconds,
  ) async {
    final qs = context.read<QuestionService>();
    final totalCount = await qs.countQuestions(subject: subject);
    if (!context.mounted) return;

    if (totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$subject 题库为空，请先导入题目')),
      );
      return;
    }

    final actualCount = count > totalCount ? totalCount : count;
    try {
      await context.read<ExamService>().startExam(
        subject: subject,
        totalQuestions: actualCount,
        timeLimitSeconds: timeLimitSeconds,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始考试失败：$e')),
        );
      }
    }
  }

  Future<void> _showCustomExamDialog(BuildContext context) async {
    String selectedSubject = '行测';
    int questionCount = 20;
    int timeMinutes = 30;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('自定义模考'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedSubject,
                decoration: const InputDecoration(labelText: '科目'),
                items: const [
                  DropdownMenuItem(value: '行测', child: Text('行测')),
                  DropdownMenuItem(value: '申论', child: Text('申论')),
                  DropdownMenuItem(value: '公基', child: Text('公基')),
                ],
                onChanged: (v) => setDialogState(() => selectedSubject = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('题量：'),
                  Expanded(
                    child: Slider(
                      value: questionCount.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: '$questionCount 题',
                      onChanged: (v) => setDialogState(() => questionCount = v.round()),
                    ),
                  ),
                  Text('$questionCount'),
                ],
              ),
              Row(
                children: [
                  const Text('时长：'),
                  Expanded(
                    child: Slider(
                      value: timeMinutes.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '$timeMinutes 分钟',
                      onChanged: (v) => setDialogState(() => timeMinutes = v.round()),
                    ),
                  ),
                  Text('$timeMinutes 分'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startExam(context, selectedSubject, questionCount, timeMinutes * 60);
              },
              child: const Text('开始'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExamTypeCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timer, color: color),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _ExamHistoryCard extends StatelessWidget {
  final Exam exam;
  const _ExamHistoryCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final scoreColor = exam.score >= 80
        ? Colors.green
        : exam.score >= 60
            ? Colors.orange
            : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scoreColor.withValues(alpha: 0.1),
          child: Text(
            '${exam.score.round()}',
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text('${exam.subject} · ${exam.totalQuestions}题'),
        subtitle: Text(exam.startedAt?.substring(0, 16) ?? ''),
        trailing: Text('${exam.score.toStringAsFixed(1)}分',
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// 答题界面
class _ExamingView extends StatelessWidget {
  final ExamService examService;
  const _ExamingView({required this.examService});

  @override
  Widget build(BuildContext context) {
    final questions = examService.examQuestions;
    if (questions.isEmpty) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(examService.currentExam?.subject ?? '模考'),
            const Spacer(),
            // 倒计时
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: examService.remainingSeconds < 300
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: examService.remainingSeconds < 300 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    examService.formatRemainingTime(),
                    style: TextStyle(
                      color: examService.remainingSeconds < 300 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showAbandonDialog(context),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _ExamQuestionPager(
        questions: questions,
        examService: examService,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => _submitExam(context),
            child: const Text('交卷'),
          ),
        ),
      ),
    );
  }

  Future<void> _submitExam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认交卷'),
        content: Text(
            '已作答 ${examService.userAnswers.length}/${examService.examQuestions.length} 题，确认提交吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续答题')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认交卷')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final exam = await context.read<ExamService>().submitExam();
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ExamReportScreen(exam: exam),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('交卷失败：$e')),
          );
        }
      }
    }
  }

  void _showAbandonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('放弃考试'),
        content: const Text('确定放弃本次考试吗？进度将不被保存。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('继续考试')),
          TextButton(
            onPressed: () {
              context.read<ExamService>().cancelExam();
              Navigator.pop(context);
            },
            child: const Text('放弃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ExamQuestionPager extends StatefulWidget {
  final List<Question> questions;
  final ExamService examService;

  const _ExamQuestionPager({required this.questions, required this.examService});

  @override
  State<_ExamQuestionPager> createState() => _ExamQuestionPagerState();
}

class _ExamQuestionPagerState extends State<_ExamQuestionPager> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 进度指示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / widget.questions.length,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: widget.questions.length,
            itemBuilder: (_, i) {
              final q = widget.questions[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: QuestionCard(
                  question: q,
                  index: i + 1,
                  userAnswer: widget.examService.userAnswers[q.id],
                  onAnswerChanged: (ans) =>
                      widget.examService.recordAnswer(q.id!, ans),
                ),
              );
            },
          ),
        ),
        // 翻页按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.outlined(
                onPressed: _currentIndex > 0
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut)
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton.outlined(
                onPressed: _currentIndex < widget.questions.length - 1
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut)
                    : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 考试报告页
class ExamReportScreen extends StatelessWidget {
  final Exam exam;

  const ExamReportScreen({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    final scoreColor = exam.score >= 80
        ? Colors.green
        : exam.score >= 60
            ? Colors.orange
            : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('考试报告'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 分数卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${exam.score.toStringAsFixed(1)}分',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      exam.score >= 80
                          ? '优秀！'
                          : exam.score >= 60
                              ? '良好'
                              : '继续加油',
                      style: TextStyle(color: scoreColor, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ReportItem(label: '科目', value: exam.subject),
                        _ReportItem(label: '题量', value: '${exam.totalQuestions}题'),
                        _ReportItem(
                          label: '用时',
                          value: _formatDuration(exam.startedAt, exam.finishedAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // AI 分析按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AiChatDialog.show(
                  context,
                  initialPrompt: '我刚完成了一次${exam.subject}模拟考试，'
                      '共${exam.totalQuestions}题，得分${exam.score.toStringAsFixed(1)}分。'
                      '请分析我的薄弱点并给出针对性复习建议。',
                  title: 'AI 分析报告',
                ),
                icon: const Icon(Icons.smart_toy),
                label: const Text('AI 分析薄弱点'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(String? start, String? end) {
    if (start == null || end == null) return '-';
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return '-';
    final diff = e.difference(s);
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '$minutes分$seconds秒';
  }
}

class _ReportItem extends StatelessWidget {
  final String label;
  final String value;
  const _ReportItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
