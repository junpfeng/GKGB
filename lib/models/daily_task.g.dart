// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyTask _$DailyTaskFromJson(Map<String, dynamic> json) => DailyTask(
  id: (json['id'] as num?)?.toInt(),
  planId: (json['plan_id'] as num?)?.toInt(),
  taskDate: json['task_date'] as String,
  subject: json['subject'] as String,
  topic: json['topic'] as String?,
  taskType: json['task_type'] as String?,
  targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
  completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? 'pending',
);

Map<String, dynamic> _$DailyTaskToJson(DailyTask instance) => <String, dynamic>{
  'id': instance.id,
  'plan_id': instance.planId,
  'task_date': instance.taskDate,
  'subject': instance.subject,
  'topic': instance.topic,
  'task_type': instance.taskType,
  'target_count': instance.targetCount,
  'completed_count': instance.completedCount,
  'status': instance.status,
};
