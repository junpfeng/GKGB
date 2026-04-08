import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exam_category_service.dart';
import '../services/exam_service.dart';
import '../services/question_service.dart';
import '../services/real_exam_service.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../models/real_exam_paper.dart';
import '../widgets/question_card.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // 快速开始卡片
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timer, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '快速模考',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '按真实考试时间和题量进行模拟',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final ecService = context.watch<ExamCategoryService>();
                    final subjects = ecService.activeSubjects;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final subject in subjects)
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 72) / 2,
                            child: Builder(builder: (ctx) {
                              final config = ecService.getExamConfig(subject.subject);
                              return _ExamTypeCard(
                                title: '${subject.label}模考',
                                subtitle: '${config['questionCount']}题 · ${(config['timeLimit'] as int) ~/ 60}分钟',
                                gradient: AppTheme.primaryGradient,
                                icon: Icons.timer,
                                onTap: () => _startExam(context, subject.subject, config['questionCount'] as int, config['timeLimit'] as int),
                              );
                            }),
                          ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 72) / 2,
                          child: _ExamTypeCard(
                            title: '自定义模考',
                            subtitle: '选择科目和题量',
                            gradient: AppTheme.warmGradient,
                            icon: Icons.tune,
                            onTap: () => _showCustomExamDialog(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 真题模考区域
          const _RealExamSection(),
          const SizedBox(height: 20),
          // 历史记录标题
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '历史成绩',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (examService.history.isEmpty)
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Center(
                child: Text(
                  '暂无历史成绩，开始第一次模考吧',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ...examService.history.map((exam) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExamHistoryCard(exam: exam),
                )),
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
                      onChanged: (v) =>
                          setDialogState(() => questionCount = v.round()),
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
                      onChanged: (v) =>
                          setDialogState(() => timeMinutes = v.round()),
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
                _startExam(
                    context, selectedSubject, questionCount, timeMinutes * 60);
              },
              child: const Text('开始'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模考类型卡片（渐变背景）
class _ExamTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;
  final VoidCallback onTap;

  const _ExamTypeCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: gradient,
      borderRadius: AppTheme.radiusMedium,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// 历史记录卡片
class _ExamHistoryCard extends StatelessWidget {
  final Exam exam;
  const _ExamHistoryCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    // 根据分数选择渐变
    final gradient = exam.score >= 80
        ? AppTheme.successGradient
        : exam.score >= 60
            ? AppTheme.warningGradient
            : AppTheme.warmGradient;
    final scoreColor = exam.score >= 80
        ? const Color(0xFF38F9D7)
        : exam.score >= 60
            ? const Color(0xFFFFD200)
            : const Color(0xFFf5576c);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // 渐变分数圆形
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${exam.score.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exam.subject} · ${exam.totalQuestions}题',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  exam.startedAt?.substring(0, 16) ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '${exam.score.toStringAsFixed(1)}分',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// 真题模考区域：按考试类型分组展示真题试卷
class _RealExamSection extends StatefulWidget {
  const _RealExamSection();

  @override
  State<_RealExamSection> createState() => _RealExamSectionState();
}

class _RealExamSectionState extends State<_RealExamSection> {
  Map<String, List<RealExamPaper>> _groupedPapers = {};
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _loadPapers();
    }
  }

  Future<void> _loadPapers() async {
    final rs = context.read<RealExamService>();
    final grouped = await rs.loadPapersGroupedByExamType();
    if (mounted) {
      setState(() {
        _groupedPapers = grouped;
        _loading = false;
      });
    }
  }

  /// 点击试卷卡片，加载题目后开始模考
  Future<void> _startPaperExam(
    BuildContext context,
    RealExamPaper paper,
  ) async {
    final rs = context.read<RealExamService>();
    final es = context.read<ExamService>();

    // 加载试卷题目
    final questions = await rs.loadPaperQuestions(paper.id!);
    if (!context.mounted) return;

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该试卷暂无题目')),
      );
      return;
    }

    try {
      await es.startPaperExam(
        paperId: paper.id!,
        subject: paper.subject,
        questions: questions,
        timeLimitSeconds: paper.timeLimit,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始模考失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.warmGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_edu,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '真题模考',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '选择一套完整真题开始模拟考试',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_groupedPapers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '暂无真题试卷，请先导入真题数据',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            )
          else
            // 按考试类型分组展示
            ...(_groupedPapers.entries.map((entry) {
              return _buildExamTypeGroup(context, entry.key, entry.value);
            })),
        ],
      ),
    );
  }

  /// 构建单个考试类型分组
  Widget _buildExamTypeGroup(
    BuildContext context,
    String examType,
    List<RealExamPaper> papers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                examType,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF667eea),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${papers.length}套',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        // 试卷列表（最多显示5套，避免过长）
        ...papers.take(5).map((paper) => _PaperExamCard(
              paper: paper,
              onTap: () => _startPaperExam(context, paper),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 试卷模考卡片
class _PaperExamCard extends StatelessWidget {
  final RealExamPaper paper;
  final VoidCallback onTap;

  const _PaperExamCard({
    required this.paper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeMinutes = paper.timeLimit ~/ 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF667eea).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // 年份标识
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${paper.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
                      paper.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${paper.questionIds.length}题',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$timeMinutes分钟',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          paper.subject,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '开始',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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

    // 倒计时颜色
    final isUrgent = examService.remainingSeconds < 300;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(examService.currentExam?.subject ?? '模考'),
            const Spacer(),
            // 渐变倒计时标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isUrgent ? AppTheme.warmGradient : AppTheme.successGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isUrgent
                            ? const Color(0xFFf5576c)
                            : const Color(0xFF43E97B))
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    examService.formatRemainingTime(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
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
          child: GradientButton(
            onPressed: () => _submitExam(context),
            label: '交卷',
            width: double.infinity,
            gradient: AppTheme.warmGradient,
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续答题'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认交卷'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续考试'),
          ),
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
        // 进度条
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.questions.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF667eea)),
                    minHeight: 6,
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

/// 考试报告页（含行测细分柱状图）
class ExamReportScreen extends StatefulWidget {
  final Exam exam;

  const ExamReportScreen({super.key, required this.exam});

  @override
  State<ExamReportScreen> createState() => _ExamReportScreenState();
}

class _ExamReportScreenState extends State<ExamReportScreen> {
  Map<String, Map<String, int>> _categoryStats = {};
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    if (widget.exam.id != null) {
      _loadCategoryStats();
    }
  }

  Future<void> _loadCategoryStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats =
          await context.read<ExamService>().getCategoryStats(widget.exam.id!);
      if (mounted) {
        setState(() {
          _categoryStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final gradient = exam.score >= 80
        ? AppTheme.successGradient
        : exam.score >= 60
            ? AppTheme.warningGradient
            : AppTheme.warmGradient;
    final label = exam.score >= 80
        ? '优秀！'
        : exam.score >= 60
            ? '良好'
            : '继续加油';

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          children: [
            // 渐变分数卡片
            GradientCard(
              gradient: gradient,
              borderRadius: AppTheme.radiusLarge,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              child: Column(
                children: [
                  Text(
                    '${exam.score.toStringAsFixed(1)}分',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            // 行测细分柱状图
            if (exam.subject == '行测' && !_loadingStats) ...[
              if (_categoryStats.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '分类得分细分',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: _CategoryBarChart(categoryStats: _categoryStats),
                ),
                const SizedBox(height: 20),
              ],
            ] else if (_loadingStats) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
            ],
            // AI 分析按钮
            GradientButton(
              onPressed: () => AiChatDialog.show(
                context,
                initialPrompt: '我刚完成了一次${exam.subject}模拟考试，'
                    '共${exam.totalQuestions}题，得分${exam.score.toStringAsFixed(1)}分。'
                    '${_categoryStats.isNotEmpty ? "各分类得分：${_categoryStats.entries.map((e) => "${e.key}：${e.value['correct']}/${e.value['total']}").join("，")}。" : ""}'
                    '请分析我的薄弱点并给出针对性复习建议。',
                title: 'AI 分析报告',
              ),
              label: 'AI 分析薄弱点',
              icon: Icons.smart_toy,
              width: double.infinity,
              gradient: AppTheme.infoGradient,
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

/// 行测分类柱状图（渐变颜色）
class _CategoryBarChart extends StatelessWidget {
  final Map<String, Map<String, int>> categoryStats;
  const _CategoryBarChart({required this.categoryStats});

  @override
  Widget build(BuildContext context) {
    final categories = categoryStats.keys.toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    // 渐变颜色列表
    const barColors = [
      Color(0xFF667eea),
      Color(0xFF0ED2F7),
      Color(0xFF43E97B),
      Color(0xFFF7971E),
      Color(0xFFf093fb),
    ];

    final barGroups = categories.asMap().entries.map((entry) {
      final i = entry.key;
      final cat = entry.value;
      final stats = categoryStats[cat]!;
      final total = (stats['total'] ?? 0).toDouble();
      final correct = (stats['correct'] ?? 0).toDouble();
      final accuracy = total == 0 ? 0.0 : correct / total;
      final color = barColors[i % barColors.length];

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: accuracy * 100,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.grey.withValues(alpha: 0.08),
            ),
          ),
        ],
      );
    }).toList();

    String shortCat(String cat) => cat.length > 4 ? cat.substring(0, 4) : cat;

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: 100,
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= categories.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        shortCat(categories[i]),
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    if (value % 25 != 0) return const SizedBox.shrink();
                    return Text(
                      '${value.toInt()}%',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withValues(alpha: 0.15),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final cat = categories[group.x.toInt()];
                  final stats = categoryStats[cat]!;
                  return BarTooltipItem(
                    '$cat\n${stats['correct']}/${stats['total']}题',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
