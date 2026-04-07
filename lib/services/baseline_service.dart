import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/question.dart';
import 'question_service.dart';

/// 摸底测试服务：每科抽题、评估基线、生成基线报告
class BaselineService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final QuestionService _questionService;

  // 当前摸底测试状态
  List<Question> _baselineQuestions = [];
  final Map<int, String> _userAnswers = {}; // questionId -> userAnswer
  final Map<int, bool> _correctMap = {}; // questionId -> isCorrect
  List<String> _selectedSubjects = [];
  bool _isLoading = false;
  bool _isSubmitted = false;

  // 摸底报告
  Map<String, double> _baselineReport = {};

  List<Question> get baselineQuestions =>
      List.unmodifiable(_baselineQuestions);
  Map<int, String> get userAnswers => Map.unmodifiable(_userAnswers);
  List<String> get selectedSubjects => List.unmodifiable(_selectedSubjects);
  bool get isLoading => _isLoading;
  bool get isSubmitted => _isSubmitted;
  Map<String, double> get baselineReport =>
      Map.unmodifiable(_baselineReport);
  bool get hasQuestions => _baselineQuestions.isNotEmpty;

  BaselineService(this._questionService);

  /// 开始摸底测试：每科随机抽 10 题
  Future<void> startBaseline(List<String> subjects) async {
    _isLoading = true;
    _isSubmitted = false;
    _userAnswers.clear();
    _correctMap.clear();
    _baselineQuestions = [];
    _selectedSubjects = List.from(subjects);
    notifyListeners();

    try {
      // 确保示例数据已导入
      await _questionService.ensureSampleData();

      final allQuestions = <Question>[];
      for (final subject in subjects) {
        final questions = await _questionService.randomQuestions(
          subject: subject,
          count: 10,
        );
        allQuestions.addAll(questions);
      }
      _baselineQuestions = allQuestions;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 记录单题答案
  void recordAnswer(int questionId, String answer, bool isCorrect) {
    _userAnswers[questionId] = answer;
    _correctMap[questionId] = isCorrect;
    notifyListeners();
  }

  /// 提交摸底测试，计算各科正确率并写入数据库
  Future<Map<String, double>> submitBaseline() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();

      // 将所有摸底答题记录写入数据库
      for (final question in _baselineQuestions) {
        final qid = question.id!;
        final userAnswer = _userAnswers[qid] ?? '';
        final isCorrect = _correctMap[qid] ?? false;

        await _db.insertAnswer({
          'question_id': qid,
          'user_answer': userAnswer,
          'is_correct': isCorrect ? 1 : 0,
          'time_spent': 0,
          'is_baseline': 1,
          'answered_at': now,
        });
      }

      // 计算各科正确率
      final result = <String, double>{};
      final subjectGroups = <String, List<Question>>{};
      for (final q in _baselineQuestions) {
        subjectGroups.putIfAbsent(q.subject, () => []).add(q);
      }
      for (final entry in subjectGroups.entries) {
        final subject = entry.key;
        final questions = entry.value;
        if (questions.isEmpty) {
          result[subject] = 0;
          continue;
        }
        int correct = 0;
        for (final q in questions) {
          if (_correctMap[q.id!] == true) correct++;
        }
        result[subject] = correct / questions.length;
      }

      _baselineReport = result;
      _isSubmitted = true;

      // 刷新总统计
      await _questionService.refreshStats();
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 读取最近一次摸底测试结果（从数据库）
  Future<Map<String, double>> getBaselineReport() async {
    final rows = await _db.queryBaselineAccuracyBySubject();
    if (rows.isEmpty) return {};

    final report = <String, double>{};
    for (final row in rows) {
      final subject = row['subject'] as String;
      final total = (row['total'] as int?) ?? 0;
      final correct = (row['correct'] as int?) ?? 0;
      if (total > 0) {
        report[subject] = correct / total;
      }
    }
    _baselineReport = report;
    notifyListeners();
    return report;
  }

  /// 重置摸底状态（开始新一轮）
  void reset() {
    _baselineQuestions = [];
    _userAnswers.clear();
    _correctMap.clear();
    _selectedSubjects = [];
    _isSubmitted = false;
    _baselineReport = {};
    notifyListeners();
  }
}
