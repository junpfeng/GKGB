// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Position _$PositionFromJson(Map<String, dynamic> json) => Position(
  id: (json['id'] as num?)?.toInt(),
  policyId: (json['policy_id'] as num?)?.toInt(),
  positionName: json['position_name'] as String,
  positionCode: json['position_code'] as String?,
  department: json['department'] as String?,
  recruitCount: (json['recruit_count'] as num?)?.toInt() ?? 1,
  educationReq: json['education_req'] as String?,
  degreeReq: json['degree_req'] as String?,
  majorReq: json['major_req'] as String?,
  ageReq: json['age_req'] as String?,
  politicalReq: json['political_req'] as String?,
  workExpReq: json['work_exp_req'] as String?,
  certificateReq: json['certificate_req'] as String?,
  genderReq: json['gender_req'] as String?,
  hukouReq: json['hukou_req'] as String?,
  otherReq: json['other_req'] as String?,
  examSubjects: json['exam_subjects'] as String?,
  examDate: json['exam_date'] as String?,
);

Map<String, dynamic> _$PositionToJson(Position instance) => <String, dynamic>{
  'id': instance.id,
  'policy_id': instance.policyId,
  'position_name': instance.positionName,
  'position_code': instance.positionCode,
  'department': instance.department,
  'recruit_count': instance.recruitCount,
  'education_req': instance.educationReq,
  'degree_req': instance.degreeReq,
  'major_req': instance.majorReq,
  'age_req': instance.ageReq,
  'political_req': instance.politicalReq,
  'work_exp_req': instance.workExpReq,
  'certificate_req': instance.certificateReq,
  'gender_req': instance.genderReq,
  'hukou_req': instance.hukouReq,
  'other_req': instance.otherReq,
  'exam_subjects': instance.examSubjects,
  'exam_date': instance.examDate,
};
