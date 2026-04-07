import 'package:json_annotation/json_annotation.dart';

part 'user_answer.g.dart';

/// 答题记录
@JsonSerializable()
class UserAnswer {
  final int? id;
  @JsonKey(name: 'question_id')
  final int questionId;
  @JsonKey(name: 'exam_id')
  final int? examId; // null 表示刷题模式
  @JsonKey(name: 'user_answer')
  final String userAnswer;
  @JsonKey(name: 'is_correct')
  final bool isCorrect;
  @JsonKey(name: 'time_spent')
  final int timeSpent; // 秒
  @JsonKey(name: 'error_type')
  final String errorType; // blind_spot / confusion / careless / timeout / trap / ''
  @JsonKey(name: 'answered_at')
  final String? answeredAt;

  const UserAnswer({
    this.id,
    required this.questionId,
    this.examId,
    required this.userAnswer,
    required this.isCorrect,
    this.timeSpent = 0,
    this.errorType = '',
    this.answeredAt,
  });

  factory UserAnswer.fromJson(Map<String, dynamic> json) => _$UserAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$UserAnswerToJson(this);

  factory UserAnswer.fromDb(Map<String, dynamic> map) {
    return UserAnswer(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      examId: map['exam_id'] as int?,
      userAnswer: map['user_answer'] as String,
      isCorrect: (map['is_correct'] as int) == 1,
      timeSpent: (map['time_spent'] as int?) ?? 0,
      errorType: (map['error_type'] as String?) ?? '',
      answeredAt: map['answered_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'question_id': questionId,
      if (examId != null) 'exam_id': examId,
      'user_answer': userAnswer,
      'is_correct': isCorrect ? 1 : 0,
      'time_spent': timeSpent,
      'error_type': errorType,
    };
  }
}
