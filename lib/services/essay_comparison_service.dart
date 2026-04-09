import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/essay_sub_question.dart';
import '../models/teacher_answer.dart';
import '../models/user_composite_answer.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 申论小题多名师答案对比服务
class EssayComparisonService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llm;

  static const _versionKey = 'essay_sub_questions_preset_version';

  // 状态字段
  bool _isLoading = false;
  bool _isImporting = false;
  String? _error;

  // 数据缓存
  List<Map<String, dynamic>> _exams = [];
  List<EssaySubQuestion> _subQuestions = [];
  List<TeacherAnswer> _teacherAnswers = [];
  UserCompositeAnswer? _compositeAnswer;
  String _aiAnalysis = '';
  bool _isAnalyzing = false;

  // 筛选选项
  List<int> _availableYears = [];
  List<String> _availableRegions = [];
  List<String> _availableExamTypes = [];
  int? _selectedYear;
  String? _selectedRegion;
  String? _selectedExamType;

  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  String? get error => _error;
  List<Map<String, dynamic>> get exams => _exams;
  List<EssaySubQuestion> get subQuestions => _subQuestions;
  List<TeacherAnswer> get teacherAnswers => _teacherAnswers;
  UserCompositeAnswer? get compositeAnswer => _compositeAnswer;
  String get aiAnalysis => _aiAnalysis;
  bool get isAnalyzing => _isAnalyzing;
  List<int> get availableYears => _availableYears;
  List<String> get availableRegions => _availableRegions;
  List<String> get availableExamTypes => _availableExamTypes;
  int? get selectedYear => _selectedYear;
  String? get selectedRegion => _selectedRegion;
  String? get selectedExamType => _selectedExamType;

  EssayComparisonService(this._llm);

  /// 幂等导入预置数据（页面进入时触发）
  Future<void> importPresetData() async {
    _isImporting = true;
    notifyListeners();

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/essay_sub_questions_preset.json',
      );
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final assetVersion = data['version'] as String? ?? '0';

      // 版本比对：已导入相同版本则跳过
      final importedVersion = await _db.getMetadata(_versionKey);
      if (importedVersion == assetVersion) {
        _isImporting = false;
        notifyListeners();
        return;
      }

      final questions = (data['questions'] as List).cast<Map<String, dynamic>>();

      for (final q in questions) {
        // 插入小题
        final questionData = {
          'year': q['year'],
          'region': q['region'],
          'exam_type': q['exam_type'],
          'exam_session': q['exam_session'] ?? '',
          'question_number': q['question_number'],
          'question_text': q['question_text'],
          'question_type': q['question_type'] ?? '',
          'material_summary': q['material_summary'] ?? '',
        };
        await _db.insertEssaySubQuestion(questionData);

        // 获取刚插入小题的 ID（通过唯一约束查找）
        final rows = await _db.queryEssaySubQuestions(
          year: q['year'] as int,
          region: q['region'] as String,
          examType: q['exam_type'] as String,
          examSession: q['exam_session'] as String?,
        );
        final subQ = rows.firstWhere(
          (r) => r['question_number'] == q['question_number'],
          orElse: () => <String, dynamic>{},
        );
        if (subQ.isEmpty) continue;
        final subQId = subQ['id'] as int;

        // 插入名师答案
        final answers = (q['answers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final a in answers) {
          await _db.insertTeacherAnswer({
            'sub_question_id': subQId,
            'teacher_name': a['teacher_name'],
            'teacher_type': a['teacher_type'] ?? 'teacher',
            'answer_text': a['answer_text'],
            'score_points': jsonEncode(a['score_points'] ?? []),
            'word_count': a['word_count'] ?? 0,
            'source_note': a['source_note'] ?? '',
          });
        }
      }

      await _db.setMetadata(_versionKey, assetVersion);
    } catch (e) {
      debugPrint('导入申论小题预置数据失败: $e');
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// 刷新筛选选项
  Future<void> _refreshFilterOptions() async {
    _availableYears = await _db.queryEssaySubQuestionYears();
    _availableRegions = await _db.queryEssaySubQuestionRegions();
    _availableExamTypes = await _db.queryEssaySubQuestionExamTypes();
  }

  /// 初始化筛选列表
  Future<void> initFilters() async {
    await _refreshFilterOptions();
    notifyListeners();
  }

  /// 设置年份筛选
  Future<void> setYear(int? year) async {
    _selectedYear = year;
    notifyListeners();
    await loadExams();
  }

  /// 设置地区筛选
  Future<void> setRegion(String? region) async {
    _selectedRegion = region;
    notifyListeners();
    await loadExams();
  }

  /// 设置考试类型筛选
  Future<void> setExamType(String? examType) async {
    _selectedExamType = examType;
    notifyListeners();
    await loadExams();
  }

  /// 筛选试卷（去重的试卷维度数据）
  Future<List<EssaySubQuestion>> loadExams({
    int? year,
    String? region,
    String? examType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.queryEssayExams(
        year: year ?? _selectedYear,
        region: region ?? _selectedRegion,
        examType: examType ?? _selectedExamType,
      );
      _exams = rows;
      return []; // 返回空列表，实际数据在 _exams
    } catch (e) {
      _error = '加载试卷列表失败: $e';
      debugPrint(_error);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取某套试卷的小题
  Future<List<EssaySubQuestion>> loadSubQuestions({
    required int year,
    required String region,
    required String examType,
    String? examSession,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.queryEssaySubQuestions(
        year: year,
        region: region,
        examType: examType,
        examSession: examSession,
      );
      _subQuestions = rows.map((r) => EssaySubQuestion.fromDb(r)).toList();
      return _subQuestions;
    } catch (e) {
      _error = '加载小题列表失败: $e';
      debugPrint(_error);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取某题的名师答案
  Future<List<TeacherAnswer>> loadTeacherAnswers(int subQuestionId) async {
    _isLoading = true;
    _error = null;
    _aiAnalysis = '';
    notifyListeners();
    try {
      final rows = await _db.queryTeacherAnswers(subQuestionId);
      _teacherAnswers = rows.map((r) => TeacherAnswer.fromDb(r)).toList();

      // 同时加载用户综合答案
      final composite = await _db.queryCompositeAnswer(subQuestionId);
      _compositeAnswer = composite != null
          ? UserCompositeAnswer.fromDb(composite)
          : null;

      return _teacherAnswers;
    } catch (e) {
      _error = '加载名师答案失败: $e';
      debugPrint(_error);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存用户综合答案（INSERT OR REPLACE）
  Future<void> saveCompositeAnswer(
    int subQuestionId,
    String content, {
    String? notes,
  }) async {
    try {
      await _db.upsertCompositeAnswer({
        'sub_question_id': subQuestionId,
        'content': content,
        'notes': notes ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
      // 重新加载
      final composite = await _db.queryCompositeAnswer(subQuestionId);
      _compositeAnswer = composite != null
          ? UserCompositeAnswer.fromDb(composite)
          : null;
      notifyListeners();
    } catch (e) {
      _error = '保存综合答案失败: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  /// 流式 AI 分析（提取共同得分要点、差异点、综合建议）
  Stream<String> analyzeWithAI(int subQuestionId) {
    _isAnalyzing = true;
    _aiAnalysis = '';
    notifyListeners();

    // 构建 AI 分析的 prompt
    final question = _subQuestions.firstWhere(
      (q) => q.id == subQuestionId,
      orElse: () => _subQuestions.first,
    );

    final answersText = _teacherAnswers.map((a) {
      final typeLabel = a.teacherType == 'institution' ? '（机构）' : '';
      final points = a.scorePoints.isNotEmpty
          ? '\n  得分要点：${a.scorePoints.join("、")}'
          : '';
      return '【${a.teacherName}$typeLabel】（${a.wordCount}字）\n${a.answerText}$points';
    }).join('\n\n');

    final prompt = '''你是一位资深申论阅卷专家。请分析以下申论小题的多位名师答案，提炼出核心信息。

## 题目信息
- 年份：${question.year}年 ${question.region} ${question.examType}
- 题号：第${question.questionNumber}题（${question.questionType}题）
- 题目：${question.questionText}

## 名师答案
$answersText

## 请分析以下内容

### 一、共同得分要点
提取所有名师答案中共同出现的核心要点，这些是最有可能的采分点。

### 二、差异分析
列出各名师答案之间的主要差异，包括结构差异、论述角度差异、独特亮点等。

### 三、答题建议
基于以上分析，给出一份综合答题建议，帮助考生取长补短，写出高分答案。

请用简洁的条目式输出，便于考生快速抓住重点。''';

    final messages = [
      ChatMessage(role: 'system', content: '你是一位资深申论阅卷专家，擅长分析不同名师的答案差异和共同得分要点。'),
      ChatMessage(role: 'user', content: prompt),
    ];

    return _llm.streamChat(messages);
  }

  /// 更新 AI 分析文本（由 Screen 层在 stream 回调中调用）
  void appendAnalysis(String chunk) {
    _aiAnalysis += chunk;
    notifyListeners();
  }

  /// AI 分析完成
  void finishAnalysis() {
    _isAnalyzing = false;
    notifyListeners();
  }

  /// AI 分析出错
  void errorAnalysis(String msg) {
    _isAnalyzing = false;
    _error = msg;
    notifyListeners();
  }

  /// 名师统计
  Future<Map<String, int>> getTeacherStats() async {
    final rows = await _db.queryTeacherStats();
    final stats = <String, int>{};
    for (final r in rows) {
      stats[r['teacher_name'] as String] = r['answer_count'] as int;
    }
    return stats;
  }
}
