// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'real_exam_paper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RealExamPaper _$RealExamPaperFromJson(Map<String, dynamic> json) =>
    RealExamPaper(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      region: json['region'] as String,
      year: (json['year'] as num).toInt(),
      examType: json['exam_type'] as String,
      examSession: json['exam_session'] as String? ?? '',
      subject: json['subject'] as String,
      timeLimit: (json['time_limit'] as num).toInt(),
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 100,
      questionIds: RealExamPaper._idsFromJson(json['question_ids']),
      scoreDistribution: RealExamPaper._scoreDistFromJson(
        json['score_distribution'],
      ),
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$RealExamPaperToJson(RealExamPaper instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'region': instance.region,
      'year': instance.year,
      'exam_type': instance.examType,
      'exam_session': instance.examSession,
      'subject': instance.subject,
      'time_limit': instance.timeLimit,
      'total_score': instance.totalScore,
      'question_ids': RealExamPaper._idsToJson(instance.questionIds),
      'score_distribution': RealExamPaper._scoreDistToJson(
        instance.scoreDistribution,
      ),
      'created_at': instance.createdAt,
    };
