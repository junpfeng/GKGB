// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Exam _$ExamFromJson(Map<String, dynamic> json) => Exam(
  id: (json['id'] as num?)?.toInt(),
  subject: json['subject'] as String,
  totalQuestions: (json['total_questions'] as num).toInt(),
  score: (json['score'] as num?)?.toDouble() ?? 0,
  timeLimit: (json['time_limit'] as num).toInt(),
  startedAt: json['started_at'] as String?,
  finishedAt: json['finished_at'] as String?,
  status: json['status'] as String? ?? 'pending',
);

Map<String, dynamic> _$ExamToJson(Exam instance) => <String, dynamic>{
  'id': instance.id,
  'subject': instance.subject,
  'total_questions': instance.totalQuestions,
  'score': instance.score,
  'time_limit': instance.timeLimit,
  'started_at': instance.startedAt,
  'finished_at': instance.finishedAt,
  'status': instance.status,
};
