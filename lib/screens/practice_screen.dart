import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/question_service.dart';
import '../services/wrong_analysis_service.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'real_exam_screen.dart';
import 'interview_home_screen.dart';
import 'wrong_analysis_screen.dart';
import 'adaptive_quiz_screen.dart';

/// 刷题页：科目选择 → 题目列表 → 答题界面
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  // 科目配置（增加渐变色映射）
  static const List<Map<String, dynamic>> _subjects = [
    {
      'subject': '行测',
      'category': '言语理解',
      'label': '言语理解',
      'icon': Icons.text_fields,
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
    },
    {
      'subject': '行测',
      'category': '数量关系',
      'label': '数量关系',
      'icon': Icons.calculate,
      'gradient': [Color(0xFFf093fb), Color(0xFFf5576c)],
    },
    {
      'subject': '行测',
      'category': '判断推理',
      'label': '判断推理',
      'icon': Icons.psychology,
      'gradient': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    },
    {
      'subject': '行测',
      'category': '资料分析',
      'label': '资料分析',
      'icon': Icons.analytics,
      'gradient': [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    },
    {
      'subject': '行测',
      'category': '常识判断',
      'label': '常识判断',
      'icon': Icons.lightbulb,
      'gradient': [Color(0xFFF7971E), Color(0xFFFFD200)],
    },
    {
      'subject': '申论',
      'category': '申论',
      'label': '申论写作',
      'icon': Icons.article,
      'gradient': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    },
    {
      'subject': '公基',
      'category': '公共基础知识',
      'label': '公共基础',
      'icon': Icons.menu_book,
      'gradient': [Color(0xFF09A6C3), Color(0xFF0ED2F7)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('刷题练习'),
          bottom: TabBar(
            tabs: const [
              Tab(text: '科目练习'),
              Tab(text: '错题本'),
              Tab(text: '真题'),
            ],
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            indicatorColor: const Color(0xFF667eea),
            dividerColor: Colors.transparent,
          ),
        ),
        body: TabBarView(
          children: [
            _SubjectList(subjects: _subjects),
            const _WrongQuestionList(),
            const RealExamScreen(),
          ],
        ),
      ),
    );
  }
}

class _SubjectList extends StatelessWidget {
  final List<Map<String, dynamic>> subjects;
  const _SubjectList({required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionService>(
      builder: (context, service, _) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: subjects.length + 3,
          itemBuilder: (context, index) {
            // 面试入口横幅卡片
            if (index == 0) {
              return _buildInterviewEntryCard(context);
            }
            // 智能练习入口卡片（面试入口下方）
            if (index == 1) {
              return _buildAdaptiveQuizCard(context);
            }
            if (index == subjects.length + 2) {
              return _buildFavoritesCard(context);
            }
            final subject = subjects[index - 2];
            final gradientColors = subject['gradient'] as List<Color>;
            final gradient = LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AccentCard(
                accentGradient: gradient,
                accentWidth: 5,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionListScreen(
                      subject: subject['subject'] as String,
                      category: subject['category'] as String,
                      title: subject['label'] as String,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 渐变图标容器
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors
                              .map((c) => c.withValues(alpha: 0.15))
                              .toList(),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        subject['icon'] as IconData,
                        color: gradientColors.first,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['label'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '点击开始练习',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInterviewEntryCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InterviewHomeScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.record_voice_over, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '面试模拟练习',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI 考官 · 结构化面试 · 即时评分',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveQuizCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdaptiveQuizScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF43E97B).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '智能练习',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '薄弱优先 · 遗忘曲线 · AI 自适应出题',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AccentCard(
        accentGradient: const LinearGradient(
          colors: [Color(0xFF9B59B6), Color(0xFF6C3483)],
        ),
        accentWidth: 5,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoriteListScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x1A9B59B6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bookmark, color: Color(0xFF9B59B6), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的收藏',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '查看收藏的题目',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

class _WrongQuestionList extends StatefulWidget {
  const _WrongQuestionList();

  @override
  State<_WrongQuestionList> createState() => _WrongQuestionListState();
}

class _WrongQuestionListState extends State<_WrongQuestionList> {
  List<Question> _questions = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final questions = await context.read<QuestionService>().loadWrongQuestions();
    if (mounted) setState(() => _questions = questions);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF43E97B)),
            SizedBox(height: 16),
            Text('暂无错题，继续加油！'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _questions.length + 1,
      itemBuilder: (context, index) {
        // 顶部：错题深度分析入口
        if (index == 0) {
          return _buildAnalysisEntryCard(context);
        }
        final q = _questions[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AccentCard(
            // 错题使用暖色渐变标记
            accentGradient: AppTheme.warmGradient,
            accentWidth: 4,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    QuestionDetailScreen(question: q, showAnswerImmediately: true),
              ),
            ),
            child: Row(
              children: [
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
                      const SizedBox(height: 4),
                      Text(
                        '${q.subject} · ${q.category}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisEntryCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WrongAnalysisScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFf5576c).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '错题深度分析',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '错因分布 · 知识图谱 · AI 诊断报告',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 题目列表页
class QuestionListScreen extends StatefulWidget {
  final String subject;
  final String category;
  final String title;

  const QuestionListScreen({
    super.key,
    required this.subject,
    required this.category,
    required this.title,
  });

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  List<Question> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await context.read<QuestionService>().loadQuestions(
      subject: widget.subject,
      category: widget.category,
      limit: 50,
    );
    if (mounted) {
      setState(() {
        _questions = questions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GradientButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeSessionScreen(
                      questions: _questions,
                      title: widget.title,
                    ),
                  ),
                ),
                label: '开始练习',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: 10,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(child: Text('暂无题目，请检查题库'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionDetailScreen(question: q),
                          ),
                        ),
                        child: Row(
                          children: [
                            // 题号圆形
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
                              child: Text(
                                q.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey[400], size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 练习模式（顺序答题）
class PracticeSessionScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;

  const PracticeSessionScreen({
    super.key,
    required this.questions,
    required this.title,
  });

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  int _currentIndex = 0;
  final Map<int, String> _answers = {};
  final Map<int, bool> _submitted = {};
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _submitAnswer(int questionId, String answer) {
    setState(() {
      _answers[questionId] = answer;
    });
  }

  Future<void> _confirmAnswer() async {
    final q = widget.questions[_currentIndex];
    final userAns = _answers[q.id] ?? '';
    if (userAns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择答案')),
      );
      return;
    }
    final isCorrect = userAns.trim().toUpperCase() == q.answer.trim().toUpperCase();
    await context.read<QuestionService>().submitAnswer(
      questionId: q.id!,
      userAnswer: userAns,
      isCorrect: isCorrect,
    );
    setState(() => _submitted[q.id!] = true);

    // 答错后异步调用 AI 错因分析（不阻塞 UI）
    if (!isCorrect && mounted) {
      context.read<WrongAnalysisService>().analyzeAndSave(q, userAns, q.answer);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentIndex++);
    } else {
      _showFinishDialog();
    }
  }

  void _showFinishDialog() {
    final total = widget.questions.length;
    final correct = _submitted.values.where((v) => v).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('练习完成'),
        content: Text('本次练习 $total 题，回答 ${_submitted.length} 题，正确 $correct 题'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];
    final isSubmitted = _submitted[q.id] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} ${_currentIndex + 1}/${widget.questions.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI 讲解',
            onPressed: () => AiChatDialog.show(
              context,
              initialPrompt:
                  '请讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
              title: 'AI 题目讲解',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.questions.length,
              itemBuilder: (_, i) {
                final question = widget.questions[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: QuestionCard(
                    question: question,
                    index: i + 1,
                    userAnswer: _answers[question.id],
                    showAnswer: _submitted[question.id] == true,
                    onAnswerChanged: (ans) => _submitAnswer(question.id!, ans),
                  ),
                );
              },
            ),
          ),
          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!isSubmitted)
                    Expanded(
                      child: GradientButton(
                        onPressed: _confirmAnswer,
                        label: '确认答案',
                        width: double.infinity,
                      ),
                    )
                  else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => AiChatDialog.show(
                          context,
                          initialPrompt:
                              '请详细讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
                          title: 'AI 题目讲解',
                        ),
                        icon: const Icon(Icons.smart_toy, size: 16),
                        label: const Text('AI 讲解'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        onPressed: _nextQuestion,
                        label: _currentIndex < widget.questions.length - 1
                            ? '下一题'
                            : '完成',
                        width: double.infinity,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 题目详情页（查看解析、AI 追问）
class QuestionDetailScreen extends StatefulWidget {
  final Question question;
  final bool showAnswerImmediately;

  const QuestionDetailScreen({
    super.key,
    required this.question,
    this.showAnswerImmediately = false,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  String? _userAnswer;
  bool _showAnswer = false;
  bool? _isFavorite;

  @override
  void initState() {
    super.initState();
    _showAnswer = widget.showAnswerImmediately;
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    if (widget.question.id != null) {
      final isFav = await context.read<QuestionService>().isFavorite(widget.question.id!);
      if (mounted) setState(() => _isFavorite = isFav);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Scaffold(
      appBar: AppBar(
        title: const Text('题目详情'),
        actions: [
          if (_isFavorite != null)
            IconButton(
              icon: Icon(_isFavorite! ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: () async {
                await context.read<QuestionService>().toggleFavorite(q.id!);
                setState(() => _isFavorite = !_isFavorite!);
              },
            ),
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI 讲解',
            onPressed: () => AiChatDialog.show(
              context,
              initialPrompt:
                  '请讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
              title: 'AI 题目讲解',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            QuestionCard(
              question: q,
              index: 1,
              userAnswer: _userAnswer,
              showAnswer: _showAnswer,
              onAnswerChanged: (ans) => setState(() => _userAnswer = ans),
            ),
            if (!_showAnswer)
              GradientButton(
                onPressed: _userAnswer == null || _userAnswer!.isEmpty
                    ? null
                    : () async {
                        final isCorrect = _userAnswer!.trim().toUpperCase() ==
                            q.answer.trim().toUpperCase();
                        final qs = context.read<QuestionService>();
                        final wa = context.read<WrongAnalysisService>();
                        await qs.submitAnswer(
                          questionId: q.id!,
                          userAnswer: _userAnswer!,
                          isCorrect: isCorrect,
                        );
                        if (!isCorrect) {
                          wa.analyzeAndSave(q, _userAnswer!, q.answer);
                        }
                        if (mounted) setState(() => _showAnswer = true);
                      },
                label: '确认答案',
                width: double.infinity,
              ),
          ],
        ),
      ),
    );
  }
}

/// 收藏题目列表页
class FavoriteListScreen extends StatefulWidget {
  const FavoriteListScreen({super.key});

  @override
  State<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<Question> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await context.read<QuestionService>().loadFavorites();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(child: Text('还没有收藏的题目'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final q = _favorites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionDetailScreen(
                              question: q,
                              showAnswerImmediately: true,
                            ),
                          ),
                        ).then((_) => _load()),
                        child: Row(
                          children: [
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
                                  const SizedBox(height: 4),
                                  Text(
                                    '${q.subject} · ${q.category}',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey[400], size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
