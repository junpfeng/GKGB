import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/baseline_service.dart';
import '../services/study_plan_service.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';

/// 摸底测试主页：选科 → 快速10题测试 → 基线报告 → 自动生成学习计划
class BaselineTestScreen extends StatelessWidget {
  const BaselineTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BaselineService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (service.isSubmitted) {
          return _BaselineReportView(service: service);
        }

        if (service.hasQuestions) {
          return _BaselineTestingView(service: service);
        }

        return const _SubjectSelectView();
      },
    );
  }
}

/// 选科页面
class _SubjectSelectView extends StatefulWidget {
  const _SubjectSelectView();

  @override
  State<_SubjectSelectView> createState() => _SubjectSelectViewState();
}

class _SubjectSelectViewState extends State<_SubjectSelectView> {
  final Set<String> _selectedSubjects = {'行测', '申论'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('摸底测试')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.quiz, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('开始摸底测试', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              '每个科目随机抽取 10 道题，快速评估你的基础水平，帮助生成个性化学习计划。',
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 32),
            Text('选择测试科目：', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // 科目选择
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: ['行测', '申论', '公基'].map((subject) {
                final selected = _selectedSubjects.contains(subject);
                return FilterChip(
                  label: Text(subject),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedSubjects.add(subject);
                      } else {
                        _selectedSubjects.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedSubjects.isNotEmpty)
              Text(
                '共约 ${_selectedSubjects.length * 10} 题，预计 ${_selectedSubjects.length * 5} 分钟',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedSubjects.isEmpty
                    ? null
                    : () => _startBaseline(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始测试'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBaseline(BuildContext context) async {
    final service = context.read<BaselineService>();
    try {
      await service.startBaseline(_selectedSubjects.toList());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始测试失败：$e')),
        );
      }
    }
  }
}

/// 答题页面：PageView 逐题作答
class _BaselineTestingView extends StatefulWidget {
  final BaselineService service;
  const _BaselineTestingView({required this.service});

  @override
  State<_BaselineTestingView> createState() => _BaselineTestingViewState();
}

class _BaselineTestingViewState extends State<_BaselineTestingView> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.service.baselineQuestions;
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('摸底测试 ${_currentIndex + 1}/${questions.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 进度条
          LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
            backgroundColor: Colors.grey[200],
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (_, i) {
                final q = questions[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: QuestionCard(
                    question: q,
                    index: i + 1,
                    userAnswer: widget.service.userAnswers[q.id],
                    onAnswerChanged: (ans) =>
                        _onAnswer(q, ans),
                  ),
                );
              },
            ),
          ),
          // 底部导航
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _currentIndex--);
                      },
                      child: const Text('上一题'),
                    ),
                  const Spacer(),
                  if (_currentIndex < questions.length - 1)
                    FilledButton(
                      onPressed: widget.service.userAnswers
                              .containsKey(questions[_currentIndex].id)
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                              setState(() => _currentIndex++);
                            }
                          : null,
                      child: const Text('下一题'),
                    )
                  else
                    FilledButton(
                      onPressed: () => _submitBaseline(context),
                      child: const Text('提交测试'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAnswer(Question question, String answer) {
    // 判断是否正确（主观题不自动判断）
    bool isCorrect = false;
    if (question.type != 'subjective') {
      isCorrect = answer.trim().toUpperCase() ==
          question.answer.trim().toUpperCase();
    }
    widget.service.recordAnswer(question.id!, answer, isCorrect);
  }

  Future<void> _submitBaseline(BuildContext context) async {
    final answered = widget.service.userAnswers.length;
    final total = widget.service.baselineQuestions.length;

    if (answered < total) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('确认提交'),
          content: Text('还有 ${total - answered} 题未作答，确认提交吗？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续答题')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('提交')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    try {
      await context.read<BaselineService>().submitBaseline();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败：$e')),
        );
      }
    }
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出测试'),
        content: const Text('退出将丢失当前进度，确认退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('继续测试')),
          TextButton(
            onPressed: () {
              context.read<BaselineService>().reset();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 基线报告页：各科柱状图 + 生成学习计划按钮
class _BaselineReportView extends StatelessWidget {
  final BaselineService service;
  const _BaselineReportView({required this.service});

  @override
  Widget build(BuildContext context) {
    final report = service.baselineReport;
    final total = service.baselineQuestions.length;
    final correct = service.userAnswers.keys
        .where((id) {
          final q =
              service.baselineQuestions.firstWhere((q) => q.id == id);
          final userAns = service.userAnswers[id] ?? '';
          return userAns.trim().toUpperCase() ==
              q.answer.trim().toUpperCase();
        })
        .length;
    final overallAccuracy = total == 0 ? 0.0 : correct / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('摸底测试报告'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            service.reset();
            Navigator.pop(context);
          },
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总体成绩卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${(overallAccuracy * 100).round()}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _accuracyColor(overallAccuracy),
                    ),
                  ),
                  Text(
                    _accuracyLabel(overallAccuracy),
                    style: TextStyle(
                        color: _accuracyColor(overallAccuracy), fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '总计 $total 题，答对 $correct 题',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 各科详情
          Text('各科成绩', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...report.entries.map(
            (entry) => _SubjectReportCard(
              subject: entry.key,
              accuracy: entry.value,
            ),
          ),
          const SizedBox(height: 24),
          // 操作按钮
          FilledButton.icon(
            onPressed: () => _generatePlan(context),
            icon: const Icon(Icons.smart_toy),
            label: const Text('基于摸底结果生成学习计划'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              service.reset();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新测试'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePlan(BuildContext context) async {
    final report = service.baselineReport;
    final subjects = report.keys.toList();
    final baselineScores =
        report.map((k, v) => MapEntry(k, v * 100));

    final planService = context.read<StudyPlanService>();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('AI 正在生成学习计划...'),
            ],
          ),
        ),
      );

      await planService.generatePlan(
        subjects: subjects,
        baselineScores: baselineScores,
      );

      if (context.mounted) {
        Navigator.pop(context); // 关闭 loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('学习计划已生成')),
        );
        service.reset();
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭 loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e')),
        );
      }
    }
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _accuracyLabel(double accuracy) {
    if (accuracy >= 0.8) return '基础扎实';
    if (accuracy >= 0.6) return '有所欠缺';
    if (accuracy >= 0.4) return '需要加强';
    return '基础薄弱';
  }
}

class _SubjectReportCard extends StatelessWidget {
  final String subject;
  final double accuracy;
  const _SubjectReportCard({required this.subject, required this.accuracy});

  @override
  Widget build(BuildContext context) {
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
              width: 60,
              child: Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: accuracy,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accuracy < 0.6 ? '薄弱科目，建议重点强化' : '继续保持',
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
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
