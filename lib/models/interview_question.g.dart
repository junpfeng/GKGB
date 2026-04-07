// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interview_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterviewQuestion _$InterviewQuestionFromJson(Map<String, dynamic> json) =>
    InterviewQuestion(
      id: (json['id'] as num?)?.toInt(),
      category: json['category'] as String,
      content: json['content'] as String,
      referenceAnswer: json['reference_answer'] as String?,
      keyPoints: json['key_points'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      region: json['region'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$InterviewQuestionToJson(InterviewQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'content': instance.content,
      'reference_answer': instance.referenceAnswer,
      'key_points': instance.keyPoints,
      'difficulty': instance.difficulty,
      'region': instance.region,
      'year': instance.year,
      'source': instance.source,
      'created_at': instance.createdAt,
    };
