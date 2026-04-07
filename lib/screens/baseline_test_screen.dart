import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/baseline_service.dart';
import '../services/study_plan_service.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

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

/// 选科页面（渐变勾选卡片）
class _SubjectSelectView extends StatefulWidget {
  const _SubjectSelectView();

  @override
  State<_SubjectSelectView> createState() => _SubjectSelectViewState();
}

class _SubjectSelectViewState extends State<_SubjectSelectView> {
  final Set<String> _selectedSubjects = {'行测', '申论'};

  // 科目渐变配置
  static const _subjectConfig = [
    {
      'name': '行测',
      'icon': Icons.assignment,
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
    },
    {
      'name': '申论',
      'icon': Icons.article,
      'gradient': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    },
    {
      'name': '公基',
      'icon': Icons.menu_book,
      'gradient': [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('摸底测试')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标区域
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.quiz, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '开始摸底测试',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              '每个科目随机抽取 10 道题，快速评估你的基础水平，帮助生成个性化学习计划。',
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 28),
            Text(
              '选择测试科目：',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            // 渐变勾选卡片
            Row(
              children: _subjectConfig.map((config) {
                final name = config['name'] as String;
                final icon = config['icon'] as IconData;
                final gradColors = config['gradient'] as List<Color>;
                final isSelected = _selectedSubjects.contains(name);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSubjects.remove(name);
                        } else {
                          _selectedSubjects.add(name);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: gradColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey[300]!),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      gradColors.first.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 28,
                            color: isSelected ? Colors.white : Colors.grey[500],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 16, color: Colors.white)
                          else
                            const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedSubjects.isNotEmpty)
              Text(
                '共约 ${_selectedSubjects.length * 10} 题，预计 ${_selectedSubjects.length * 5} 分钟',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            const Spacer(),
            GradientButton(
              onPressed: _selectedSubjects.isEmpty
                  ? null
                  : () => _startBaseline(context),
              label: '开始测试',
              icon: Icons.play_arrow,
              width: double.infinity,
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
          // 渐变进度条
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_currentIndex + 1) / questions.length,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
              ),
            ),
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
                    onAnswerChanged: (ans) => _onAnswer(q, ans),
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
                    GradientButton(
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
                      label: '下一题',
                    )
                  else
                    GradientButton(
                      onPressed: () => _submitBaseline(context),
                      label: '提交测试',
                      gradient: AppTheme.warmGradient,
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

/// 基线报告页：各科渐变柱状图 + 生成学习计划按钮
class _BaselineReportView extends StatelessWidget {
  final BaselineService service;
  const _BaselineReportView({required this.service});

  @override
  Widget build(BuildContext context) {
    final report = service.baselineReport;
    final total = service.baselineQuestions.length;
    final correct = service.userAnswers.keys.where((id) {
      final q = service.baselineQuestions.firstWhere((q) => q.id == id);
      final userAns = service.userAnswers[id] ?? '';
      return userAns.trim().toUpperCase() == q.answer.trim().toUpperCase();
    }).length;
    final overallAccuracy = total == 0 ? 0.0 : correct / total;

    final resultGradient = overallAccuracy >= 0.8
        ? AppTheme.successGradient
        : overallAccuracy >= 0.6
            ? AppTheme.warningGradient
            : AppTheme.warmGradient;

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 总体成绩渐变卡片
          GradientCard(
            gradient: resultGradient,
            borderRadius: AppTheme.radiusLarge,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                Text(
                  '${(overallAccuracy * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _accuracyLabel(overallAccuracy),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '总计 $total 题，答对 $correct 题',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '各科成绩',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          ...report.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubjectReportCard(
                subject: entry.key,
                accuracy: entry.value,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            onPressed: () => _generatePlan(context),
            label: '基于摸底结果生成学习计划',
            icon: Icons.smart_toy,
            width: double.infinity,
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
    final baselineScores = report.map((k, v) => MapEntry(k, v * 100));

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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('学习计划已生成')),
        );
        service.reset();
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e')),
        );
      }
    }
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
          // 渐变科目标签
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
                fontSize: 13,
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
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accuracy < 0.6 ? '薄弱科目，建议重点强化' : '继续保持',
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
              fontSize: 16,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
