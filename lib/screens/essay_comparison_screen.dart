import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/essay_sub_question.dart';
import '../models/teacher_answer.dart';
import '../services/essay_comparison_service.dart';
import '../widgets/glass_card.dart';

/// 申论小题多名师答案对比页面
/// 三级导航：试卷选择 → 小题列表 → 答案对比
class EssayComparisonScreen extends StatefulWidget {
  const EssayComparisonScreen({super.key});

  @override
  State<EssayComparisonScreen> createState() => _EssayComparisonScreenState();
}

/// 导航层级
enum _NavLevel { exams, questions, comparison }

class _EssayComparisonScreenState extends State<EssayComparisonScreen> {
  _NavLevel _level = _NavLevel.exams;
  bool _initialized = false;

  // 当前选中的试卷标题
  String _examTitle = '';

  // 当前选中的小题
  EssaySubQuestion? _selectedQuestion;

  // AI 分析流订阅
  StreamSubscription<String>? _analysisSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initData();
    }
  }

  Future<void> _initData() async {
    final service = context.read<EssayComparisonService>();
    await service.importPresetData();
    await service.initFilters();
    await service.loadExams();
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    super.dispose();
  }

  void _selectExam(Map<String, dynamic> exam) {
    final year = exam['year'] as int;
    final region = exam['region'] as String;
    final examType = exam['exam_type'] as String;
    final examSession = (exam['exam_session'] as String?) ?? '';
    final sessionSuffix = examSession.isNotEmpty ? ' $examSession' : '';

    setState(() {
      _examTitle = '$year年 $region $examType$sessionSuffix';
      _level = _NavLevel.questions;
    });

    context.read<EssayComparisonService>().loadSubQuestions(
      year: year,
      region: region,
      examType: examType,
      examSession: examSession.isEmpty ? null : examSession,
    );
  }

  void _selectQuestion(EssaySubQuestion question) {
    setState(() {
      _selectedQuestion = question;
      _level = _NavLevel.comparison;
    });
    context.read<EssayComparisonService>().loadTeacherAnswers(question.id!);
  }

  void _goBack() {
    _analysisSubscription?.cancel();
    setState(() {
      if (_level == _NavLevel.comparison) {
        _level = _NavLevel.questions;
        _selectedQuestion = null;
      } else if (_level == _NavLevel.questions) {
        _level = _NavLevel.exams;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _level == _NavLevel.exams,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          leading: _level != _NavLevel.exams
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  String get _appBarTitle {
    switch (_level) {
      case _NavLevel.exams:
        return '申论小题对比';
      case _NavLevel.questions:
        return _examTitle;
      case _NavLevel.comparison:
        return '第${_selectedQuestion?.questionNumber}题 答案对比';
    }
  }

  Widget _buildBody() {
    switch (_level) {
      case _NavLevel.exams:
        return _ExamListView(onSelect: _selectExam);
      case _NavLevel.questions:
        return _QuestionListView(onSelect: _selectQuestion);
      case _NavLevel.comparison:
        return _ComparisonView(
          question: _selectedQuestion!,
          onStartAnalysis: _startAIAnalysis,
          analysisSubscription: _analysisSubscription,
          onCancelAnalysis: () {
            _analysisSubscription?.cancel();
            context.read<EssayComparisonService>().finishAnalysis();
          },
        );
    }
  }

  void _startAIAnalysis() {
    _analysisSubscription?.cancel();
    final service = context.read<EssayComparisonService>();
    final stream = service.analyzeWithAI(_selectedQuestion!.id!);
    _analysisSubscription = stream.listen(
      (chunk) => service.appendAnalysis(chunk),
      onDone: () => service.finishAnalysis(),
      onError: (e) => service.errorAnalysis('AI 分析失败: $e'),
    );
  }
}

// ===== 第一级：试卷选择 =====

class _ExamListView extends StatelessWidget {
  final void Function(Map<String, dynamic>) onSelect;
  const _ExamListView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EssayComparisonService>();

    return Column(
      children: [
        // 筛选栏
        _FilterBar(service: service),
        // 试卷列表
        Expanded(
          child: service.isLoading || service.isImporting
              ? const Center(child: CircularProgressIndicator())
              : service.exams.isEmpty
                  ? const Center(child: Text('暂无数据，请稍候...'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: service.exams.length,
                      itemBuilder: (context, index) {
                        final exam = service.exams[index];
                        final year = exam['year'] as int;
                        final region = exam['region'] as String;
                        final examType = exam['exam_type'] as String;
                        final session = (exam['exam_session'] as String?) ?? '';
                        final count = exam['question_count'] as int;
                        final sessionSuffix =
                            session.isNotEmpty ? ' $session' : '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AccentCard(
                            accentGradient: const LinearGradient(
                              colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                            ),
                            accentWidth: 4,
                            onTap: () => onSelect(exam),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFf093fb)
                                            .withValues(alpha: 0.15),
                                        const Color(0xFFf5576c)
                                            .withValues(alpha: 0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.description_outlined,
                                    color: Color(0xFFf5576c),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$year年 $region $examType$sessionSuffix',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count 道小题',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Colors.grey[400], size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ===== 筛选栏 =====

class _FilterBar extends StatelessWidget {
  final EssayComparisonService service;
  const _FilterBar({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // 年份筛选
          _buildFilterChip(
            context: context,
            label: service.selectedYear?.toString() ?? '年份',
            isSelected: service.selectedYear != null,
            options: service.availableYears.map((y) => y.toString()).toList(),
            onSelected: (val) {
              service.setYear(val == null ? null : int.parse(val));
            },
          ),
          // 地区筛选
          _buildFilterChip(
            context: context,
            label: service.selectedRegion ?? '地区',
            isSelected: service.selectedRegion != null,
            options: service.availableRegions,
            onSelected: (val) => service.setRegion(val),
          ),
          // 考试类型筛选
          _buildFilterChip(
            context: context,
            label: service.selectedExamType ?? '考试类型',
            isSelected: service.selectedExamType != null,
            options: service.availableExamTypes,
            onSelected: (val) => service.setExamType(val),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required List<String> options,
    required void Function(String?) onSelected,
  }) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: null, child: Text('全部')),
        ...options.map(
          (o) => PopupMenuItem(value: o, child: Text(o)),
        ),
      ],
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[700],
          ),
        ),
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.08),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        visualDensity: VisualDensity.compact,
        deleteIcon: isSelected
            ? Icon(Icons.close, size: 16,
                color: Theme.of(context).colorScheme.primary)
            : null,
        onDeleted: isSelected ? () => onSelected(null) : null,
      ),
    );
  }
}

// ===== 第二级：小题列表 =====

class _QuestionListView extends StatelessWidget {
  final void Function(EssaySubQuestion) onSelect;
  const _QuestionListView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EssayComparisonService>();

    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.subQuestions.isEmpty) {
      return const Center(child: Text('该试卷暂无小题'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: service.subQuestions.length,
      itemBuilder: (context, index) {
        final q = service.subQuestions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AccentCard(
            accentGradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            accentWidth: 4,
            onTap: () => onSelect(q),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF667eea).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '第${q.questionNumber}题',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667eea),
                        ),
                      ),
                    ),
                    if (q.questionType.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          q.questionType,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: Colors.grey[400], size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.questionText,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===== 第三级：答案对比 =====

class _ComparisonView extends StatefulWidget {
  final EssaySubQuestion question;
  final VoidCallback onStartAnalysis;
  final StreamSubscription<String>? analysisSubscription;
  final VoidCallback onCancelAnalysis;

  const _ComparisonView({
    required this.question,
    required this.onStartAnalysis,
    required this.analysisSubscription,
    required this.onCancelAnalysis,
  });

  @override
  State<_ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<_ComparisonView> {
  bool _cardMode = true; // true=卡片横滑, false=列表模式
  bool _questionExpanded = true;
  final PageController _pageController = PageController();
  final TextEditingController _compositeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<EssayComparisonService>();
    if (service.compositeAnswer != null) {
      _compositeController.text = service.compositeAnswer!.content;
      _notesController.text = service.compositeAnswer!.notes;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _compositeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EssayComparisonService>();

    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目区（可折叠）
          _buildQuestionSection(),
          const SizedBox(height: 12),
          // 模式切换 + 名师答案
          _buildAnswersSection(service),
          const SizedBox(height: 16),
          // AI 分析区
          _buildAISection(service),
          const SizedBox(height: 16),
          // 用户综合答案区
          _buildCompositeSection(service),
        ],
      ),
    );
  }

  Widget _buildQuestionSection() {
    final q = widget.question;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _questionExpanded = !_questionExpanded),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '第${q.questionNumber}题 · ${q.questionType}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _questionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (_questionExpanded) ...[
            const SizedBox(height: 8),
            Text(
              q.questionText,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            if (q.materialSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '材料摘要：${q.materialSummary}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAnswersSection(EssayComparisonService service) {
    final answers = service.teacherAnswers;
    if (answers.isEmpty) {
      return const Center(child: Text('暂无名师答案'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 模式切换行
        Row(
          children: [
            Text(
              '名师答案（${answers.length}位）',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, icon: Icon(Icons.view_carousel, size: 18)),
                ButtonSegment(value: false, icon: Icon(Icons.view_list, size: 18)),
              ],
              selected: {_cardMode},
              onSelectionChanged: (v) =>
                  setState(() => _cardMode = v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 答案内容区
        _cardMode
            ? _buildCardMode(answers)
            : _buildListMode(answers),
      ],
    );
  }

  Widget _buildCardMode(List<TeacherAnswer> answers) {
    return SizedBox(
      height: 420,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: answers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AnswerCard(answer: answers[index]),
              );
            },
          ),
          // Windows 平台显示左右箭头按钮
          if (Platform.isWindows) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28),
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListMode(List<TeacherAnswer> answers) {
    return Column(
      children: answers
          .map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerCard(answer: a),
              ))
          .toList(),
    );
  }

  Widget _buildAISection(EssayComparisonService service) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF667eea)),
              const SizedBox(width: 6),
              const Text(
                'AI 要点分析',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (service.isAnalyzing)
                TextButton.icon(
                  onPressed: widget.onCancelAnalysis,
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('停止'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: service.teacherAnswers.isNotEmpty
                      ? widget.onStartAnalysis
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(
                    service.aiAnalysis.isNotEmpty ? '重新分析' : '开始分析',
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (service.isAnalyzing || service.aiAnalysis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                service.aiAnalysis.isEmpty ? '正在分析...' : service.aiAnalysis,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
            if (service.isAnalyzing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
          if (service.error != null &&
              service.error!.contains('AI')) ...[
            const SizedBox(height: 8),
            Text(
              service.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompositeSection(EssayComparisonService service) {
    // 同步已有综合答案到输入框
    if (service.compositeAnswer != null &&
        _compositeController.text.isEmpty) {
      _compositeController.text = service.compositeAnswer!.content;
      _notesController.text = service.compositeAnswer!.notes;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: Color(0xFF764ba2)),
              SizedBox(width: 6),
              Text(
                '我的综合答案',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _compositeController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '参考名师答案和 AI 分析，写出你的综合答案...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '备注（可选）',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                if (_compositeController.text.trim().isEmpty) return;
                service.saveCompositeAnswer(
                  widget.question.id!,
                  _compositeController.text.trim(),
                  notes: _notesController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('综合答案已保存')),
                );
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 名师答案卡片 =====

class _AnswerCard extends StatelessWidget {
  final TeacherAnswer answer;
  const _AnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    final isInstitution = answer.teacherType == 'institution';
    final color = isInstitution
        ? const Color(0xFF43e97b)
        : const Color(0xFF667eea);

    return GlassCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名师名称行
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    answer.teacherName[0],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  answer.teacherName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (isInstitution) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43e97b).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      '机构',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF43e97b)),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${answer.wordCount}字',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 答案正文
            SelectableText(
              answer.answerText,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            // 得分要点
            if (answer.scorePoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: answer.scorePoints
                    .map((p) => Chip(
                          label: Text(p,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor:
                              color.withValues(alpha: 0.08),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                              horizontal: 6),
                        ))
                    .toList(),
              ),
            ],
            // 来源
            if (answer.sourceNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '来源：${answer.sourceNote}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
