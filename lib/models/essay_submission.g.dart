// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay_submission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EssaySubmission _$EssaySubmissionFromJson(Map<String, dynamic> json) =>
    EssaySubmission(
      id: (json['id'] as num?)?.toInt(),
      topic: json['topic'] as String,
      content: json['content'] as String,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      timeSpent: (json['time_spent'] as num?)?.toInt() ?? 0,
      aiScore: (json['ai_score'] as num?)?.toDouble() ?? 0,
      aiComment: json['ai_comment'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$EssaySubmissionToJson(EssaySubmission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'topic': instance.topic,
      'content': instance.content,
      'word_count': instance.wordCount,
      'time_spent': instance.timeSpent,
      'ai_score': instance.aiScore,
      'ai_comment': instance.aiComment,
      'created_at': instance.createdAt,
    };
