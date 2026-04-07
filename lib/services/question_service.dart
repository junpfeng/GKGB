import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/question.dart';
import '../models/user_answer.dart';

/// 题目服务：题库查询、答题记录、错题、收藏
class QuestionService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Question> _currentQuestions = [];
  int _totalQuestions = 0;
  int _answeredCount = 0;
  int _correctCount = 0;
  bool _isLoading = false;
  bool _sampleImported = false;

  List<Question> get currentQuestions => List.unmodifiable(_currentQuestions);
  int get totalQuestions => _totalQuestions;
  int get answeredCount => _answeredCount;
  int get correctCount => _correctCount;
  double get accuracy => _answeredCount == 0 ? 0 : _correctCount / _answeredCount;
  bool get isLoading => _isLoading;

  // ===== 题库 =====

  /// 按科目/分类加载题目
  Future<List<Question>> loadQuestions({
    String? subject,
    String? category,
    String? type,
    int? limit,
    int? offset,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 确保示例数据已导入
      await ensureSampleData();

      final rows = await _db.queryQuestions(
        subject: subject,
        category: category,
        type: type,
        limit: limit ?? 20,
        offset: offset ?? 0,
      );
      _currentQuestions = rows.map((r) => Question.fromDb(r)).toList();
      return _currentQuestions;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取题目总数（按科目）
  Future<int> countQuestions({String? subject, String? category}) async {
    return await _db.countQuestions(subject: subject, category: category);
  }

  /// 按科目随机抽题（组卷用）
  Future<List<Question>> randomQuestions({
    required String subject,
    String? category,
    required int count,
  }) async {
    final rows = await _db.randomQuestions(
      subject: subject,
      category: category,
      count: count,
    );
    return rows.map((r) => Question.fromDb(r)).toList();
  }

  /// 获取错题列表
  Future<List<Question>> loadWrongQuestions({String? subject}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ids = await _db.queryWrongQuestionIds(subject: subject);
      if (ids.isEmpty) {
        _currentQuestions = [];
        return [];
      }
      final questions = <Question>[];
      for (final id in ids) {
        final row = await _db.queryQuestionById(id);
        if (row != null) {
          questions.add(Question.fromDb(row));
        }
      }
      _currentQuestions = questions;
      return questions;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取收藏题目列表
  Future<List<Question>> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryFavorites();
      _currentQuestions = rows.map((r) => Question.fromDb(r)).toList();
      return _currentQuestions;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== 答题记录 =====

  /// 提交答案
  Future<UserAnswer> submitAnswer({
    required int questionId,
    int? examId,
    required String userAnswer,
    required bool isCorrect,
    int timeSpent = 0,
  }) async {
    final answer = UserAnswer(
      questionId: questionId,
      examId: examId,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      timeSpent: timeSpent,
    );
    final id = await _db.insertAnswer(answer.toDb());
    await refreshStats();
    return UserAnswer(
      id: id,
      questionId: questionId,
      examId: examId,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      timeSpent: timeSpent,
    );
  }

  /// 获取某题的答题历史
  Future<List<UserAnswer>> getAnswerHistory(int questionId) async {
    final rows = await _db.queryAnswersByQuestion(questionId);
    return rows.map((r) => UserAnswer.fromDb(r)).toList();
  }

  // ===== 收藏 =====

  Future<bool> isFavorite(int questionId) async {
    return await _db.isFavorite(questionId);
  }

  Future<void> toggleFavorite(int questionId) async {
    final isFav = await _db.isFavorite(questionId);
    if (isFav) {
      await _db.deleteFavorite(questionId);
    } else {
      await _db.insertFavorite({'question_id': questionId});
    }
    notifyListeners();
  }

  // ===== 统计 =====

  Future<void> refreshStats() async {
    final stats = await _db.queryTotalStats();
    _totalQuestions = await _db.countQuestions();
    _answeredCount = (stats['total'] as int?) ?? 0;
    _correctCount = (stats['correct'] as int?) ?? 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    return await _db.queryTodayStats();
  }

  Future<List<Map<String, dynamic>>> getAccuracyBySubject() async {
    return await _db.queryAccuracyBySubject();
  }

  // ===== 示例题库导入 =====

  static const List<String> _sampleFiles = [
    'assets/questions/verbal_comprehension.json',
    'assets/questions/quantitative_reasoning.json',
    'assets/questions/logical_reasoning.json',
    'assets/questions/data_analysis.json',
    'assets/questions/common_knowledge.json',
    'assets/questions/essay_writing.json',
    'assets/questions/public_basics.json',
  ];

  /// 确保示例数据已导入（首次启动时导入）
  Future<void> ensureSampleData() async {
    if (_sampleImported) return;
    final count = await _db.countQuestions();
    if (count > 0) {
      _sampleImported = true;
      return;
    }
    await _importSampleData();
    _sampleImported = true;
  }

  Future<void> _importSampleData() async {
    for (final filePath in _sampleFiles) {
      try {
        final jsonStr = await rootBundle.loadString(filePath);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final questions = data['questions'] as List<dynamic>;

        // 使用 compute isolate 批量解析（主线程不卡顿）
        final questionMaps = await compute(_parseQuestionsInIsolate, {
          'subject': data['subject'] as String,
          'category': data['category'] as String,
          'questions': questions,
        });

        for (final q in questionMaps) {
          await _db.insertQuestion(q);
        }
      } catch (e) {
        debugPrint('导入题库 $filePath 失败: $e');
      }
    }
  }

  static List<Map<String, dynamic>> _parseQuestionsInIsolate(Map<String, dynamic> params) {
    final subject = params['subject'] as String;
    final category = params['category'] as String;
    final questions = params['questions'] as List<dynamic>;

    return questions.map((q) {
      final map = q as Map<String, dynamic>;
      return {
        'subject': subject,
        'category': category,
        'type': map['type'] as String? ?? 'single',
        'content': map['content'] as String,
        'options': jsonEncode(map['options'] ?? []),
        'answer': map['answer'] as String,
        'explanation': map['explanation'] as String?,
        'difficulty': (map['difficulty'] as int?) ?? 1,
      };
    }).toList();
  }

  void updateStats({required int total, required int answered, required int correct}) {
    _totalQuestions = total;
    _answeredCount = answered;
    _correctCount = correct;
    notifyListeners();
  }
}
