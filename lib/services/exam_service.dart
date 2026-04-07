import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../models/user_answer.dart';
import 'question_service.dart';

/// 模拟考试服务：组卷、计时、评分、历史
class ExamService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final QuestionService _questionService;

  Exam? _currentExam;
  List<Question> _examQuestions = [];
  final Map<int, String> _userAnswers = {}; // questionId -> userAnswer
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isLoading = false;
  List<Exam> _history = [];

  Exam? get currentExam => _currentExam;
  List<Question> get examQuestions => List.unmodifiable(_examQuestions);
  Map<int, String> get userAnswers => Map.unmodifiable(_userAnswers);
  int get remainingSeconds => _remainingSeconds;
  bool get isLoading => _isLoading;
  bool get isRunning => _timer?.isActive == true;
  List<Exam> get history => List.unmodifiable(_history);

  ExamService(this._questionService);

  /// 创建并开始考试
  Future<Exam> startExam({
    required String subject,
    required int totalQuestions,
    required int timeLimitSeconds,
    String? category,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 随机抽题
      _examQuestions = await _questionService.randomQuestions(
        subject: subject,
        category: category,
        count: totalQuestions,
      );

      // 写入 DB
      final now = DateTime.now().toIso8601String();
      final examData = {
        'subject': subject,
        'total_questions': _examQuestions.length,
        'score': 0.0,
        'time_limit': timeLimitSeconds,
        'started_at': now,
        'status': 'ongoing',
      };
      final id = await _db.insertExam(examData);

      _currentExam = Exam(
        id: id,
        subject: subject,
        totalQuestions: _examQuestions.length,
        timeLimit: timeLimitSeconds,
        startedAt: now,
        status: 'ongoing',
      );
      _userAnswers.clear();
      _remainingSeconds = timeLimitSeconds;

      // 开始计时
      _startTimer();
      return _currentExam!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 记录用户答案
  void recordAnswer(int questionId, String answer) {
    _userAnswers[questionId] = answer;
    notifyListeners();
  }

  /// 提交考试并评分
  Future<Exam> submitExam() async {
    _stopTimer();
    if (_currentExam == null) throw Exception('没有进行中的考试');

    _isLoading = true;
    notifyListeners();

    try {
      int correctCount = 0;
      for (final question in _examQuestions) {
        final userAns = _userAnswers[question.id] ?? '';
        final isCorrect = _isAnswerCorrect(userAns, question.answer, question.type);
        if (isCorrect) correctCount++;

        // 保存答题记录
        await _db.insertAnswer({
          'question_id': question.id,
          'exam_id': _currentExam!.id,
          'user_answer': userAns,
          'is_correct': isCorrect ? 1 : 0,
          'time_spent': 0,
        });
      }

      final total = _examQuestions.length;
      final score = total == 0 ? 0.0 : correctCount / total * 100.0;
      final now = DateTime.now().toIso8601String();

      await _db.updateExam(_currentExam!.id!, {
        'score': score,
        'finished_at': now,
        'status': 'finished',
      });

      _currentExam = _currentExam!.copyWith(
        score: score,
        finishedAt: now,
        status: 'finished',
      );

      await _questionService.refreshStats();
      await loadHistory();
      return _currentExam!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 取消/放弃考试
  void cancelExam() {
    _stopTimer();
    _currentExam = null;
    _examQuestions = [];
    _userAnswers.clear();
    notifyListeners();
  }

  /// 加载历史记录
  Future<void> loadHistory({int limit = 20}) async {
    final rows = await _db.queryExams(limit: limit);
    _history = rows.map((r) => Exam.fromDb(r)).toList();
    notifyListeners();
  }

  /// 获取考试答题详情（答案对照）
  Future<List<UserAnswer>> getExamAnswers(int examId) async {
    final rows = await _db.queryAnswersByExam(examId);
    return rows.map((r) => UserAnswer.fromDb(r)).toList();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        // 时间到，自动提交
        submitExam();
        return;
      }
      _remainingSeconds--;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool _isAnswerCorrect(String userAnswer, String correctAnswer, String type) {
    if (type == 'subjective') return false; // 主观题需 AI 批改
    return userAnswer.trim().toUpperCase() == correctAnswer.trim().toUpperCase();
  }

  String formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
