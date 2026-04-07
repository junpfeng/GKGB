// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserAnswer _$UserAnswerFromJson(Map<String, dynamic> json) => UserAnswer(
  id: (json['id'] as num?)?.toInt(),
  questionId: (json['question_id'] as num).toInt(),
  examId: (json['exam_id'] as num?)?.toInt(),
  userAnswer: json['user_answer'] as String,
  isCorrect: json['is_correct'] as bool,
  timeSpent: (json['time_spent'] as num?)?.toInt() ?? 0,
  answeredAt: json['answered_at'] as String?,
);

Map<String, dynamic> _$UserAnswerToJson(UserAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question_id': instance.questionId,
      'exam_id': instance.examId,
      'user_answer': instance.userAnswer,
      'is_correct': instance.isCorrect,
      'time_spent': instance.timeSpent,
      'answered_at': instance.answeredAt,
    };
