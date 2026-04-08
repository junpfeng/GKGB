import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'study_plan.g.dart';

/// 学习计划
@JsonSerializable()
class StudyPlan {
  final int? id;
  @JsonKey(name: 'target_position_id')
  final int? targetPositionId;
  @JsonKey(name: 'exam_date')
  final String? examDate;
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'subjects')
  final List<String> subjects; // 考试科目列表
  @JsonKey(fromJson: _mapFromJson, toJson: _mapToJson, name: 'baseline_scores')
  final Map<String, double> baselineScores; // 各科基线分
  @JsonKey(name: 'plan_data')
  final String? planData; // AI 生成的计划 JSON/文本
  final String status; // active/completed/abandoned
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const StudyPlan({
    this.id,
    this.targetPositionId,
    this.examDate,
    this.subjects = const [],
    this.baselineScores = const {},
    this.planData,
    this.status = 'active',
    this.createdAt,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) => _$StudyPlanFromJson(json);
  Map<String, dynamic> toJson() => _$StudyPlanToJson(this);

  factory StudyPlan.fromDb(Map<String, dynamic> map) {
    return StudyPlan(
      id: map['id'] as int?,
      targetPositionId: map['target_position_id'] as int?,
      examDate: map['exam_date'] as String?,
      subjects: map['subjects'] != null && (map['subjects'] as String).isNotEmpty
          ? List<String>.from(jsonDecode(map['subjects'] as String))
          : [],
      baselineScores: map['baseline_scores'] != null && (map['baseline_scores'] as String).isNotEmpty
          ? Map<String, double>.from(
              (jsonDecode(map['baseline_scores'] as String) as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ),
            )
          : {},
      planData: map['plan_data'] as String?,
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      if (targetPositionId != null) 'target_position_id': targetPositionId,
      'exam_date': examDate,
      'subjects': jsonEncode(subjects),
      'baseline_scores': jsonEncode(baselineScores),
      'plan_data': planData,
      'status': status,
    };
  }

  StudyPlan copyWith({
    int? id,
    int? targetPositionId,
    String? examDate,
    List<String>? subjects,
    Map<String, double>? baselineScores,
    String? planData,
    String? status,
  }) {
    return StudyPlan(
      id: id ?? this.id,
      targetPositionId: targetPositionId ?? this.targetPositionId,
      examDate: examDate ?? this.examDate,
      subjects: subjects ?? this.subjects,
      baselineScores: baselineScores ?? this.baselineScores,
      planData: planData ?? this.planData,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  static List<String> _listFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) return List<String>.from(jsonDecode(value));
    return [];
  }

  static dynamic _listToJson(List<String> value) => value;

  static Map<String, double> _mapFromJson(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return Map<String, double>.from(value.map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    }
    if (value is String) {
      final decoded = jsonDecode(value) as Map;
      return Map<String, double>.from(decoded.map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    }
    return {};
  }

  static dynamic _mapToJson(Map<String, double> value) => value;
}
