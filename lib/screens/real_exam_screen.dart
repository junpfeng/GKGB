import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../models/real_exam_paper.dart';
import '../services/question_service.dart';
import '../services/real_exam_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'real_exam_paper_screen.dart';
import 'contribute_question_screen.dart';
import 'practice_screen.dart';

/// 真题专区主页：三级联动筛选（考试类型 → 地区 → 年份）
class RealExamScreen extends StatefulWidget {
  const RealExamScreen({super.key});

  @override
  State<RealExamScreen> createState() => _RealExamScreenState();
}

class _RealExamScreenState extends State<RealExamScreen> {
  // 筛选条件
  String? _selectedExamType;
  String? _selectedRegion;
  String? _selectedYear;

  // 筛选选项
  List<String> _examTypes = [];
  List<String> _regions = [];
  List<String> _years = [];

  // 结果
  List<Question> _questions = [];
  List<RealExamPaper> _papers = [];
  bool _loading = true;
  int _totalCount = 0;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final qs = context.read<QuestionService>();
    final rs = context.read<RealExamService>();
    // 确保数据已导入
    await rs.ensureSampleData();

    final examTypes = await qs.getAvailableExamTypes();
    if (mounted) {
      setState(() {
        _examTypes = examTypes;
        _loading = false;
      });
    }
    await _loadResults();
  }

  Future<void> _onExamTypeChanged(String? value) async {
    setState(() {
      _selectedExamType = value;
      _selectedRegion = null;
      _selectedYear = null;
      _regions = [];
      _years = [];
      _currentPage = 0;
    });
    if (value != null) {
      final qs = context.read<QuestionService>();
      final regions = await qs.getAvailableRegions(examType: value);
      if (mounted) setState(() => _regions = regions);
    }
    await _loadResults();
  }

  Future<void> _onRegionChanged(String? value) async {
    setState(() {
      _selectedRegion = value;
      _selectedYear = null;
      _years = [];
      _currentPage = 0;
    });
    if (value != null) {
      final qs = context.read<QuestionService>();
      final years = await qs.getAvailableYears(
        examType: _selectedExamType,
        region: value,
      );
      if (mounted) setState(() => _years = years);
    }
    await _loadResults();
  }

  Future<void> _onYearChanged(String? value) async {
    setState(() {
      _selectedYear = value;
      _currentPage = 0;
    });
    await _loadResults();
  }

  Future<void> _loadResults() async {
    final qs = context.read<QuestionService>();
    final rs = context.read<RealExamService>();

    final year = _selectedYear != null ? int.tryParse(_selectedYear!) : null;

    final questions = await qs.loadRealExamQuestions(
      examType: _selectedExamType,
      region: _selectedRegion,
      year: year,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
    );

    final totalCount = await qs.countRealExamQuestions(
      examType: _selectedExamType,
      region: _selectedRegion,
      year: year,
    );

    final papers = await rs.loadPapers(
      examType: _selectedExamType,
      region: _selectedRegion,
      year: year,
    );

    if (mounted) {
      setState(() {
        _questions = questions;
        _papers = papers;
        _totalCount = totalCount;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _currentPage++);
    final qs = context.read<QuestionService>();
    final year = _selectedYear != null ? int.tryParse(_selectedYear!) : null;
    final more = await qs.loadRealExamQuestions(
      examType: _selectedExamType,
      region: _selectedRegion,
      year: year,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
    );
    if (mounted) {
      setState(() => _questions = [..._questions, ...more]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 筛选区
        _buildFilterBar(),
        // 结果区
        Expanded(
          child: _questions.isEmpty && _papers.isEmpty
              ? _buildEmptyState()
              : _buildResultList(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return GlassCard(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterChips(
                  label: '考试类型',
                  options: _examTypes,
                  selected: _selectedExamType,
                  onSelected: _onExamTypeChanged,
                ),
              ),
              // 贡献真题按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: '贡献真题',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContributeQuestionScreen(),
                  ),
                ).then((_) => _loadResults()),
              ),
            ],
          ),
          if (_regions.isNotEmpty)
            _FilterChips(
              label: '地区',
              options: _regions,
              selected: _selectedRegion,
              onSelected: _onRegionChanged,
            ),
          if (_years.isNotEmpty)
            _FilterChips(
              label: '年份',
              options: _years,
              selected: _selectedYear,
              onSelected: _onYearChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无真题数据',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ContributeQuestionScreen(),
              ),
            ).then((_) => _loadResults()),
            label: '贡献真题',
            icon: Icons.add,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 整卷列表
        if (_papers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              '整套试卷（${_papers.length}套）',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          ..._papers.map((paper) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaperCard(paper: paper),
              )),
          const SizedBox(height: 12),
        ],
        // 单题列表
        if (_questions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '单题练习（共$_totalCount题）',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          ..._questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionDetailScreen(question: q),
                  ),
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
                          '${i + 1}',
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildTag(q.examType),
                              if (q.region.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _buildTag(q.region),
                              ],
                              if (q.year > 0) ...[
                                const SizedBox(width: 4),
                                _buildTag('${q.year}'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400], size: 16),
                  ],
                ),
              ),
            );
          }),
          // 加载更多
          if (_questions.length < _totalCount)
            Center(
              child: TextButton(
                onPressed: _loadMore,
                child: const Text('加载更多'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTag(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF667eea)),
      ),
    );
  }
}

/// 筛选 Chip 行
class _FilterChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label：',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 「全部」选项
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('全部'),
                      selected: selected == null,
                      onSelected: (_) => onSelected(null),
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ...options.map((opt) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(opt),
                          selected: selected == opt,
                          onSelected: (sel) => onSelected(sel ? opt : null),
                          visualDensity: VisualDensity.compact,
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 试卷卡片
class _PaperCard extends StatelessWidget {
  final RealExamPaper paper;
  const _PaperCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RealExamPaperScreen(paperId: paper.id!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.infoGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${paper.questionIds.length}题 · ${paper.timeLimit ~/ 60}分钟 · ${paper.totalScore.round()}分',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}
