import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/question_service.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';
import '../widgets/ai_chat_dialog.dart';

/// 刷题页：科目选择 → 题目列表 → 答题界面
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  // 科目配置
  static const List<Map<String, dynamic>> _subjects = [
    {'subject': '行测', 'category': '言语理解', 'label': '言语理解', 'icon': Icons.text_fields, 'color': 0xFF1565C0},
    {'subject': '行测', 'category': '数量关系', 'label': '数量关系', 'icon': Icons.calculate, 'color': 0xFFE65100},
    {'subject': '行测', 'category': '判断推理', 'label': '判断推理', 'icon': Icons.psychology, 'color': 0xFF6A1B9A},
    {'subject': '行测', 'category': '资料分析', 'label': '资料分析', 'icon': Icons.analytics, 'color': 0xFF2E7D32},
    {'subject': '行测', 'category': '常识判断', 'label': '常识判断', 'icon': Icons.lightbulb, 'color': 0xFFF57F17},
    {'subject': '申论', 'category': '申论', 'label': '申论写作', 'icon': Icons.article, 'color': 0xFFC62828},
    {'subject': '公基', 'category': '公共基础知识', 'label': '公共基础', 'icon': Icons.menu_book, 'color': 0xFF00695C},
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('刷题练习'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '科目练习'),
              Tab(text: '错题本'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SubjectList(subjects: _subjects),
            const _WrongQuestionList(),
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
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length + 1, // +1 for favorites
          itemBuilder: (context, index) {
            if (index == subjects.length) {
              return _buildFavoritesCard(context);
            }
            final subject = subjects[index];
            final color = Color(subject['color'] as int);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(subject['icon'] as IconData, color: color),
                ),
                title: Text(subject['label'] as String),
                subtitle: const Text('点击开始练习'),
                trailing: const Icon(Icons.chevron_right),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A9E9E9E),
          child: Icon(Icons.bookmark, color: Colors.grey),
        ),
        title: const Text('我的收藏'),
        subtitle: const Text('查看收藏的题目'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoriteListScreen()),
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
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('暂无错题，继续加油！'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              q.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${q.subject} · ${q.category}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuestionDetailScreen(question: q, showAnswerImmediately: true),
              ),
            ),
          ),
        );
      },
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
            FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PracticeSessionScreen(
                    questions: _questions,
                    title: widget.title,
                  ),
                ),
              ),
              child: const Text('开始练习'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(child: Text('暂无题目，请检查题库'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(
                          q.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionDetailScreen(question: q),
                          ),
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
              initialPrompt: '请讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
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
                      child: FilledButton(
                        onPressed: _confirmAnswer,
                        child: const Text('确认答案'),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => AiChatDialog.show(
                          context,
                          initialPrompt: '请详细讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
                          title: 'AI 题目讲解',
                        ),
                        icon: const Icon(Icons.smart_toy, size: 16),
                        label: const Text('AI 讲解'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _nextQuestion,
                        child: Text(
                          _currentIndex < widget.questions.length - 1 ? '下一题' : '完成',
                        ),
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
              initialPrompt: '请讲解这道题：\n${q.content}\n正确答案：${q.answer}\n${q.explanation ?? ""}',
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _userAnswer == null || _userAnswer!.isEmpty
                      ? null
                      : () async {
                          final isCorrect = _userAnswer!.trim().toUpperCase() ==
                              q.answer.trim().toUpperCase();
                          await context.read<QuestionService>().submitAnswer(
                            questionId: q.id!,
                            userAnswer: _userAnswer!,
                            isCorrect: isCorrect,
                          );
                          setState(() => _showAnswer = true);
                        },
                  child: const Text('确认答案'),
                ),
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
                  padding: const EdgeInsets.all(12),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final q = _favorites[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          q.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text('${q.subject} · ${q.category}'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionDetailScreen(
                              question: q,
                              showAnswerImmediately: true,
                            ),
                          ),
                        ).then((_) => _load()),
                      ),
                    );
                  },
                ),
    );
  }
}
