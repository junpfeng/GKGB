// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interview_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterviewScore _$InterviewScoreFromJson(Map<String, dynamic> json) =>
    InterviewScore(
      id: (json['id'] as num?)?.toInt(),
      sessionId: (json['session_id'] as num).toInt(),
      questionId: (json['question_id'] as num).toInt(),
      userAnswer: json['user_answer'] as String,
      contentScore: (json['content_score'] as num?)?.toDouble() ?? 0,
      expressionScore: (json['expression_score'] as num?)?.toDouble() ?? 0,
      timeScore: (json['time_score'] as num?)?.toDouble() ?? 0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
      aiComment: json['ai_comment'] as String?,
      followUpQuestion: json['follow_up_question'] as String?,
      followUpAnswer: json['follow_up_answer'] as String?,
      followUpComment: json['follow_up_comment'] as String?,
      timeSpent: (json['time_spent'] as num?)?.toInt() ?? 0,
      answeredAt: json['answered_at'] as String?,
    );

Map<String, dynamic> _$InterviewScoreToJson(InterviewScore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'session_id': instance.sessionId,
      'question_id': instance.questionId,
      'user_answer': instance.userAnswer,
      'content_score': instance.contentScore,
      'expression_score': instance.expressionScore,
      'time_score': instance.timeScore,
      'total_score': instance.totalScore,
      'ai_comment': instance.aiComment,
      'follow_up_question': instance.followUpQuestion,
      'follow_up_answer': instance.followUpAnswer,
      'follow_up_comment': instance.followUpComment,
      'time_spent': instance.timeSpent,
      'answered_at': instance.answeredAt,
    };
