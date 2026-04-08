// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_entry_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExamEntryScore _$ExamEntryScoreFromJson(Map<String, dynamic> json) =>
    ExamEntryScore(
      id: (json['id'] as num?)?.toInt(),
      province: json['province'] as String,
      city: json['city'] as String,
      year: (json['year'] as num).toInt(),
      examType: json['exam_type'] as String,
      department: json['department'] as String,
      positionName: json['position_name'] as String,
      positionCode: json['position_code'] as String?,
      recruitCount: (json['recruit_count'] as num?)?.toInt(),
      majorReq: json['major_req'] as String?,
      educationReq: json['education_req'] as String?,
      degreeReq: json['degree_req'] as String?,
      politicalReq: json['political_req'] as String?,
      workExpReq: json['work_exp_req'] as String?,
      otherReq: json['other_req'] as String?,
      minEntryScore: (json['min_entry_score'] as num?)?.toDouble(),
      maxEntryScore: (json['max_entry_score'] as num?)?.toDouble(),
      entryCount: (json['entry_count'] as num?)?.toInt(),
      sourceUrl: json['source_url'] as String?,
      fetchedAt: json['fetched_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ExamEntryScoreToJson(ExamEntryScore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'province': instance.province,
      'city': instance.city,
      'year': instance.year,
      'exam_type': instance.examType,
      'department': instance.department,
      'position_name': instance.positionName,
      'position_code': instance.positionCode,
      'recruit_count': instance.recruitCount,
      'major_req': instance.majorReq,
      'education_req': instance.educationReq,
      'degree_req': instance.degreeReq,
      'political_req': instance.politicalReq,
      'work_exp_req': instance.workExpReq,
      'other_req': instance.otherReq,
      'min_entry_score': instance.minEntryScore,
      'max_entry_score': instance.maxEntryScore,
      'entry_count': instance.entryCount,
      'source_url': instance.sourceUrl,
      'fetched_at': instance.fetchedAt,
      'updated_at': instance.updatedAt,
    };
