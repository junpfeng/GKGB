import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../services/adaptive_quiz_service.dart';
import '../services/question_service.dart';
import '../services/wrong_analysis_service.dart';
import '../widgets/question_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ai_chat_dialog.dart';
import 'mastery_overview_screen.dart';

/// 智能练习页面
class AdaptiveQuizScreen extends StatefulWidget {
  const AdaptiveQuizScreen({super.key});

  @override
  State<AdaptiveQuizScreen> createState() => _AdaptiveQuizScreenState();
}

class _AdaptiveQuizScreenState extends State<AdaptiveQuizScreen> {
  List<Question> _questions = [];
  bool _loading = true;
  bool _practicing = false;
  int _currentIndex = 0;
  String? _selectedSubject;
  List<String> _subjects = [];
  final Map<int, String> _answers = {};
  final Map<int, bool> _results = {};
  final PageController _pageController = PageController();

  // 掌握度变化记录
  final Map<String, double> _masteryBefore = {};
  final Map<String, double> _masteryAfter = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final service = context.read<AdaptiveQuizService>();
    await service.ensureInitialized();
    final subjects = await service.getSubjects();
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _loading = false;
      });
    }
  }

  Future<void> _startPractice() async {
    setState(() => _loading = true);
    final service = context.read<AdaptiveQuizService>();

    // 记录练习前掌握度
    final overview = await service.getMasteryOverview(subject: _selectedSubject);
    for (final item in overview) {
      final name = item['name'] as String? ?? '';
      _masteryBefore[name] = (item['score'] as num?)?.toDouble() ?? 50;
    }

    final questions = await service.getNextQuestions(
      count: 10,
      subject: _selectedSubject,
    );
    if (mounted) {
      setState(() {
        _questions = questions;
        _practicing = true;
        _currentIndex = 0;
        _answers.clear();
        _results.clear();
        _loading = false;
      });
    }
  }

  Future<void> _confirmAnswer() async {
    final q = _questions[_currentIndex];
    final userAns = _answers[q.id] ?? '';
    if (userAns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择答案')),
      );
      return;
    }
    final isCorrect =
        userAns.trim().toUpperCase() == q.answer.trim().toUpperCase();

    // 提交答题记录
    final qs = context.read<QuestionService>();
    final adaptiveService = context.read<AdaptiveQuizService>();
    final wa = context.read<WrongAnalysisService>();

    await qs.submitAnswer(
      questionId: q.id!,
      userAnswer: userAns,
      isCorrect: isCorrect,
    );

    // 更新掌握度
    final kpId = await adaptiveService.getKnowledgePointId(q.subject, q.category);
    if (kpId != null) {
      await adaptiveService.updateMastery(kpId, isCorrect);
    }

    if (!mounted) return;
    setState(() => _results[q.id!] = isCorrect);

    // 答错后异步调用 AI 错因分析
    if (!isCorrect) {
      wa.analyzeAndSave(q, userAns, q.answer);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentIndex++);
    } else {
      _showSummary();
    }
  }

  Future<void> _showSummary() async {
    final service = context.read<AdaptiveQuizService>();
    // 记录练习后掌握度
    final overview = await service.getMasteryOverview(subject: _selectedSubject);
    for (final item in overview) {
      final name = item['name'] as String? ?? '';
      _masteryAfter[name] = (item['score'] as num?)?.toDouble() ?? 50;
    }

    if (!mounted) return;

    final total = _questions.length;
    final answered = _results.length;
    final correct = _results.values.where((v) => v).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('智能练习完成'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本次练习 $total 题，回答 $answered 题，正确 $correct 题'),
              const SizedBox(height: 16),
              const Text('掌握度变化：',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildMasteryChanges(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _practicing = false;
                _questions = [];
              });
            },
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startPractice();
            },
            child: const Text('继续练习'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMasteryChanges() {
    final changes = <Widget>[];
    for (final name in _masteryBefore.keys) {
      final before = _masteryBefore[name] ?? 50;
      final after = _masteryAfter[name] ?? before;
      final diff = after - before;
      if (diff.abs() < 0.1) continue;
      changes.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              '${before.toStringAsFixed(0)} → ${after.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 4),
            Icon(
              diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: diff > 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ));
    }
    if (changes.isEmpty) {
      changes.add(const Text('暂无变化', style: TextStyle(color: Colors.grey)));
    }
    return changes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能练习'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '掌握度总览',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MasteryOverviewScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _practicing
              ? _buildPracticeView()
              : _buildStartView(),
    );
  }

  Widget _buildStartView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 科目选择
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择练习科目',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSubjectChip(null, '全部科目'),
                    ..._subjects.map((s) => _buildSubjectChip(s, s)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 掌握度概览
          FutureBuilder<List<Map<String, dynamic>>>(
            future: context
                .read<AdaptiveQuizService>()
                .getMasteryOverview(subject: _selectedSubject),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data = snapshot.data!;
              if (data.isEmpty) return const SizedBox();
              final avgScore = data.fold<double>(
                    0,
                    (sum, r) =>
                        sum + ((r['score'] as num?)?.toDouble() ?? 50),
                  ) /
                  data.length;
              final weakCount =
                  data.where((r) => ((r['score'] as num?)?.toDouble() ?? 50) < 60).length;

              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '掌握度概览',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MasteryOverviewScreen(),
                            ),
                          ),
                          child: const Text('查看详情'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 总进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avgScore / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          avgScore >= 80
                              ? Colors.green
                              : avgScore >= 60
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '平均掌握度 ${avgScore.toStringAsFixed(0)}%，'
                      '${weakCount > 0 ? '$weakCount 个薄弱知识点' : '无薄弱知识点'}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 开始按钮
          Center(
            child: GradientButton(
              onPressed: _startPractice,
              label: '开始智能练习',
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(String? value, String label) {
    final selected = _selectedSubject == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedSubject = value),
      selectedColor: const Color(0xFF667eea).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF667eea) : null,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
    );
  }

  Widget _buildPracticeView() {
    final q = _questions[_currentIndex];
    final isSubmitted = _results.containsKey(q.id);

    return Column(
      children: [
        // 进度条
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation(Color(0xFF667eea)),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (_, i) {
              final question = _questions[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: QuestionCard(
                  question: question,
                  index: i + 1,
                  userAnswer: _answers[question.id],
                  showAnswer: _results.containsKey(question.id),
                  onAnswerChanged: (ans) =>
                      setState(() => _answers[question.id!] = ans),
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
                      label: _currentIndex < _questions.length - 1
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
    );
  }
}
