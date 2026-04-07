// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interview_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterviewSession _$InterviewSessionFromJson(Map<String, dynamic> json) =>
    InterviewSession(
      id: (json['id'] as num?)?.toInt(),
      category: json['category'] as String,
      totalQuestions: (json['total_questions'] as num).toInt(),
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'ongoing',
      mode: json['mode'] as String? ?? 'text',
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      summary: json['summary'] as String?,
    );

Map<String, dynamic> _$InterviewSessionToJson(InterviewSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'total_questions': instance.totalQuestions,
      'total_score': instance.totalScore,
      'status': instance.status,
      'mode': instance.mode,
      'started_at': instance.startedAt,
      'finished_at': instance.finishedAt,
      'summary': instance.summary,
    };
