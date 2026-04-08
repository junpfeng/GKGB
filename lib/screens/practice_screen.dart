import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_category.dart';
import '../services/exam_category_service.dart';
import '../services/question_service.dart';
import '../services/wrong_analysis_service.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/subject_category_ui.dart';
import '../theme/app_theme.dart';
import 'real_exam_screen.dart';
import 'interview_home_screen.dart';
import 'wrong_analysis_screen.dart';
import 'adaptive_quiz_screen.dart';
import 'idiom_list_screen.dart';

/// 刷题页：科目选择 → 题目列表 → 答题界面
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ecService = context.watch<ExamCategoryService>();
    // 从活跃科目动态构建科目列表
    final subjects = <Map<String, dynamic>>[];
    for (final s in ecService.activeSubjects) {
      for (final c in s.categories) {
        subjects.add({
          'subject': s.subject,
          'category': c.category,
          'label': c.label,
          'icon': c.icon,
          'gradient': c.gradient,
        });
      }
    }
    final showInterview = ecService.isFeatureSupported(Feature.interview);

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
            _SubjectList(subjects: subjects, showInterview: showInterview),
            const _WrongQuestionList(),
            const RealExamScreen(),
          ],
        ),
      ),
    );
  }
}

class _SubjectList extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final bool showInterview;
  const _SubjectList({required this.subjects, this.showInterview = true});

  @override
  State<_SubjectList> createState() => _SubjectListState();
}

class _SubjectListState extends State<_SubjectList> {
  /// 缓存每个分类的真题数量，key = "subject::category"
  final Map<String, int> _realExamCounts = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRealExamCounts();
  }

  /// 异步预加载所有分类的真题数量
  Future<void> _loadRealExamCounts() async {
    final qs = context.read<QuestionService>();
    for (final s in widget.subjects) {
      final key = '${s['subject']}::${s['category']}';
      if (!_realExamCounts.containsKey(key)) {
        final count = await qs.countRealExamByCategory(
          subject: s['subject'] as String,
          category: s['category'] as String,
        );
        if (mounted) {
          setState(() => _realExamCounts[key] = count);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 特殊卡片数量（面试+自适应+收藏）
    final extraCards = widget.showInterview ? 3 : 2;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: widget.subjects.length + extraCards,
      itemBuilder: (context, index) {
        // 面试入口横幅卡片（仅支持面试功能时显示）
        if (widget.showInterview && index == 0) {
          return _buildInterviewEntryCard(context);
        }
        // 智能练习入口卡片
        final quizIndex = widget.showInterview ? 1 : 0;
        if (index == quizIndex) {
          return _buildAdaptiveQuizCard(context);
        }
        if (index == widget.subjects.length + extraCards - 1) {
          return _buildFavoritesCard(context);
        }
        final subjectIndex = widget.showInterview ? index - 2 : index - 1;
        final subject = widget.subjects[subjectIndex];
        final gradientColors = subject['gradient'] as List<Color>;
        final gradient = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        // 从缓存读取真题数量
        final cacheKey = '${subject['subject']}::${subject['category']}';
        final realExamCount = _realExamCounts[cacheKey];
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
                // 真题数量角标
                if (realExamCount != null && realExamCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: gradientColors.first.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: gradientColors.first.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '真题$realExamCount',
                      style: TextStyle(
                        fontSize: 10,
                        color: gradientColors.first,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
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

/// 题目来源筛选枚举
enum _SourceFilter { all, realExam, simulated }

class _QuestionListScreenState extends State<QuestionListScreen> {
  List<Question> _questions = [];
  bool _loading = true;

  /// 来源筛选：全部/真题/模拟题
  _SourceFilter _sourceFilter = _SourceFilter.all;
  /// 真题子筛选
  String? _examTypeFilter;
  String? _regionFilter;
  int? _yearFilter;

  /// 动态可选项
  List<String> _availableExamTypes = [];
  List<String> _availableRegions = [];
  List<String> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final qs = context.read<QuestionService>();

    // 构建 isRealExam 参数
    int? isRealExam;
    if (_sourceFilter == _SourceFilter.realExam) {
      isRealExam = 1;
    } else if (_sourceFilter == _SourceFilter.simulated) {
      isRealExam = 0;
    }

    final questions = await qs.loadQuestions(
      subject: widget.subject,
      category: widget.category,
      isRealExam: isRealExam,
      examType: _sourceFilter == _SourceFilter.realExam ? _examTypeFilter : null,
      region: _sourceFilter == _SourceFilter.realExam ? _regionFilter : null,
      year: _sourceFilter == _SourceFilter.realExam ? _yearFilter : null,
      limit: 50,
    );
    if (mounted) {
      setState(() {
        _questions = questions;
        _loading = false;
      });
    }
  }

  /// 加载真题筛选可选项
  Future<void> _loadFilterOptions() async {
    final qs = context.read<QuestionService>();
    final types = await qs.getAvailableExamTypes(
      subject: widget.subject,
      category: widget.category,
    );
    final regions = await qs.getAvailableRegions(
      subject: widget.subject,
      category: widget.category,
      examType: _examTypeFilter,
    );
    final years = await qs.getAvailableYears(
      subject: widget.subject,
      category: widget.category,
      examType: _examTypeFilter,
      region: _regionFilter,
    );
    if (mounted) {
      setState(() {
        _availableExamTypes = types;
        _availableRegions = regions;
        _availableYears = years;
      });
    }
  }

  /// 切换来源筛选
  void _onSourceChanged(Set<_SourceFilter> selected) {
    final newFilter = selected.first;
    if (newFilter == _sourceFilter) return;
    setState(() {
      _sourceFilter = newFilter;
      // 切换来源时重置真题子筛选
      _examTypeFilter = null;
      _regionFilter = null;
      _yearFilter = null;
    });
    if (newFilter == _SourceFilter.realExam) {
      _loadFilterOptions();
    }
    _loadQuestions();
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
      body: Column(
        children: [
          // 来源切换：全部/真题/模拟题
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_SourceFilter>(
                segments: const [
                  ButtonSegment(
                    value: _SourceFilter.all,
                    label: Text('全部'),
                    icon: Icon(Icons.list, size: 16),
                  ),
                  ButtonSegment(
                    value: _SourceFilter.realExam,
                    label: Text('真题'),
                    icon: Icon(Icons.verified, size: 16),
                  ),
                  ButtonSegment(
                    value: _SourceFilter.simulated,
                    label: Text('模拟题'),
                    icon: Icon(Icons.edit_note, size: 16),
                  ),
                ],
                selected: {_sourceFilter},
                onSelectionChanged: _onSourceChanged,
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 13),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          // 真题子筛选行（仅选"真题"时展开）
          if (_sourceFilter == _SourceFilter.realExam)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 考试类型
                    _buildDropdownFilter(
                      label: '考试类型',
                      value: _examTypeFilter,
                      items: _availableExamTypes,
                      onChanged: (v) {
                        setState(() {
                          _examTypeFilter = v;
                          _regionFilter = null;
                          _yearFilter = null;
                        });
                        _loadFilterOptions();
                        _loadQuestions();
                      },
                    ),
                    const SizedBox(width: 8),
                    // 地区
                    _buildDropdownFilter(
                      label: '地区',
                      value: _regionFilter,
                      items: _availableRegions,
                      onChanged: (v) {
                        setState(() {
                          _regionFilter = v;
                          _yearFilter = null;
                        });
                        _loadFilterOptions();
                        _loadQuestions();
                      },
                    ),
                    const SizedBox(width: 8),
                    // 年份
                    _buildDropdownFilter(
                      label: '年份',
                      value: _yearFilter?.toString(),
                      items: _availableYears,
                      onChanged: (v) {
                        setState(() {
                          _yearFilter = v != null ? int.tryParse(v) : null;
                        });
                        _loadQuestions();
                      },
                    ),
                  ],
                ),
              ),
            ),
          // 成语整理入口（仅言语理解/言语运用类别显示）
          if (['言语理解', '言语运用'].contains(widget.category))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IdiomListScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '成语整理',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '查看选词填空中的成语释义和人民日报用法',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          // 题目列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _sourceFilter == _SourceFilter.realExam
                                  ? Icons.verified_outlined
                                  : Icons.quiz_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _sourceFilter == _SourceFilter.realExam
                                  ? '该分类暂无符合条件的真题'
                                  : _sourceFilter == _SourceFilter.simulated
                                      ? '该分类暂无模拟题'
                                      : '暂无题目，请检查题库',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 24),
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
                                  builder: (_) =>
                                      QuestionDetailScreen(question: q),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                        // 真题题目显示年份+考试类型标签
                                        if (q.isRealExam == 1 &&
                                            (q.year > 0 ||
                                                q.examType.isNotEmpty))
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                if (q.year > 0)
                                                  _buildQuestionTag(
                                                      '${q.year}'),
                                                if (q.examType.isNotEmpty) ...[
                                                  const SizedBox(width: 4),
                                                  _buildQuestionTag(
                                                      q.examType),
                                                ],
                                              ],
                                            ),
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
          ),
        ],
      ),
    );
  }

  /// 构建筛选下拉按钮
  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value != null
            ? const Color(0xFF667eea).withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null
              ? const Color(0xFF667eea).withValues(alpha: 0.4)
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: value != null ? const Color(0xFF667eea) : Colors.grey[500],
          ),
          style: const TextStyle(fontSize: 12, color: Color(0xFF667eea)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('全部$label', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 12)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 构建真题年份/类型小标签
  Widget _buildQuestionTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF667eea),
        ),
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
