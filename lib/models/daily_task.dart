import 'package:json_annotation/json_annotation.dart';

part 'daily_task.g.dart';

/// 每日任务
@JsonSerializable()
class DailyTask {
  final int? id;
  @JsonKey(name: 'plan_id')
  final int? planId;
  @JsonKey(name: 'task_date')
  final String taskDate; // yyyy-MM-dd
  final String subject;
  final String? topic;
  @JsonKey(name: 'task_type')
  final String? taskType; // practice/review/exam/read
  @JsonKey(name: 'target_count')
  final int targetCount;
  @JsonKey(name: 'completed_count')
  final int completedCount;
  final String status; // pending/ongoing/completed/skipped

  const DailyTask({
    this.id,
    this.planId,
    required this.taskDate,
    required this.subject,
    this.topic,
    this.taskType,
    this.targetCount = 0,
    this.completedCount = 0,
    this.status = 'pending',
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) => _$DailyTaskFromJson(json);
  Map<String, dynamic> toJson() => _$DailyTaskToJson(this);

  factory DailyTask.fromDb(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] as int?,
      planId: map['plan_id'] as int?,
      taskDate: map['task_date'] as String,
      subject: map['subject'] as String,
      topic: map['topic'] as String?,
      taskType: map['task_type'] as String?,
      targetCount: (map['target_count'] as int?) ?? 0,
      completedCount: (map['completed_count'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'pending',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      'task_date': taskDate,
      'subject': subject,
      'topic': topic,
      'task_type': taskType,
      'target_count': targetCount,
      'completed_count': completedCount,
      'status': status,
    };
  }

  DailyTask copyWith({
    int? id,
    int? planId,
    String? taskDate,
    String? subject,
    String? topic,
    String? taskType,
    int? targetCount,
    int? completedCount,
    String? status,
  }) {
    return DailyTask(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      taskDate: taskDate ?? this.taskDate,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      taskType: taskType ?? this.taskType,
      targetCount: targetCount ?? this.targetCount,
      completedCount: completedCount ?? this.completedCount,
      status: status ?? this.status,
    );
  }
}
