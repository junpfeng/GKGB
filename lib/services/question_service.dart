import 'package:flutter/foundation.dart';

class QuestionService extends ChangeNotifier {
  int _totalQuestions = 0;
  int _answeredCount = 0;
  int _correctCount = 0;

  int get totalQuestions => _totalQuestions;
  int get answeredCount => _answeredCount;
  int get correctCount => _correctCount;
  double get accuracy => _answeredCount == 0 ? 0 : _correctCount / _answeredCount;

  void updateStats({required int total, required int answered, required int correct}) {
    _totalQuestions = total;
    _answeredCount = answered;
    _correctCount = correct;
    notifyListeners();
  }
}
