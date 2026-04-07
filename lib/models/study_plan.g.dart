// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudyPlan _$StudyPlanFromJson(Map<String, dynamic> json) => StudyPlan(
  id: (json['id'] as num?)?.toInt(),
  targetPositionId: (json['target_position_id'] as num?)?.toInt(),
  examDate: json['exam_date'] as String?,
  subjects: json['subjects'] == null
      ? const []
      : StudyPlan._listFromJson(json['subjects']),
  baselineScores: json['baseline_scores'] == null
      ? const {}
      : StudyPlan._mapFromJson(json['baseline_scores']),
  planData: json['plan_data'] as String?,
  status: json['status'] as String? ?? 'active',
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$StudyPlanToJson(StudyPlan instance) => <String, dynamic>{
  'id': instance.id,
  'target_position_id': instance.targetPositionId,
  'exam_date': instance.examDate,
  'subjects': StudyPlan._listToJson(instance.subjects),
  'baseline_scores': StudyPlan._mapToJson(instance.baselineScores),
  'plan_data': instance.planData,
  'status': instance.status,
  'created_at': instance.createdAt,
};
