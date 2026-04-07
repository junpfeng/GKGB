import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'match_result.g.dart';

/// 岗位匹配结果
@JsonSerializable()
class MatchResult {
  final int? id;
  @JsonKey(name: 'position_id')
  final int positionId;
  @JsonKey(name: 'match_score')
  final int matchScore; // 0-100
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'matched_items')
  final List<String> matchedItems;  // 符合项
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'risk_items')
  final List<String> riskItems;     // 风险项
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'unmatched_items')
  final List<String> unmatchedItems; // 不符项
  final String? advice;
  @JsonKey(name: 'is_target')
  final bool isTarget; // 是否标记为目标岗位
  @JsonKey(name: 'matched_at')
  final String? matchedAt;

  // 关联字段（JOIN 获取）
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? positionName;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? department;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? recruitCount;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? policyTitle;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? city;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? province;

  const MatchResult({
    this.id,
    required this.positionId,
    required this.matchScore,
    this.matchedItems = const [],
    this.riskItems = const [],
    this.unmatchedItems = const [],
    this.advice,
    this.isTarget = false,
    this.matchedAt,
    this.positionName,
    this.department,
    this.recruitCount,
    this.policyTitle,
    this.city,
    this.province,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => _$MatchResultFromJson(json);
  Map<String, dynamic> toJson() => _$MatchResultToJson(this);

  factory MatchResult.fromDb(Map<String, dynamic> map) {
    return MatchResult(
      id: map['id'] as int?,
      positionId: map['position_id'] as int,
      matchScore: (map['match_score'] as int?) ?? 0,
      matchedItems: map['matched_items'] != null
          ? List<String>.from(jsonDecode(map['matched_items'] as String))
          : [],
      riskItems: map['risk_items'] != null
          ? List<String>.from(jsonDecode(map['risk_items'] as String))
          : [],
      unmatchedItems: map['unmatched_items'] != null
          ? List<String>.from(jsonDecode(map['unmatched_items'] as String))
          : [],
      advice: map['advice'] as String?,
      isTarget: (map['is_target'] as int?) == 1,
      matchedAt: map['matched_at'] as String?,
      positionName: map['position_name'] as String?,
      department: map['department'] as String?,
      recruitCount: map['recruit_count'] as int?,
      policyTitle: map['policy_title'] as String?,
      city: map['city'] as String?,
      province: map['province'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'position_id': positionId,
      'match_score': matchScore,
      'matched_items': jsonEncode(matchedItems),
      'risk_items': jsonEncode(riskItems),
      'unmatched_items': jsonEncode(unmatchedItems),
      'advice': advice,
      'is_target': isTarget ? 1 : 0,
    };
  }

  MatchResult copyWith({
    int? id,
    int? positionId,
    int? matchScore,
    List<String>? matchedItems,
    List<String>? riskItems,
    List<String>? unmatchedItems,
    String? advice,
    bool? isTarget,
    String? matchedAt,
  }) {
    return MatchResult(
      id: id ?? this.id,
      positionId: positionId ?? this.positionId,
      matchScore: matchScore ?? this.matchScore,
      matchedItems: matchedItems ?? this.matchedItems,
      riskItems: riskItems ?? this.riskItems,
      unmatchedItems: unmatchedItems ?? this.unmatchedItems,
      advice: advice ?? this.advice,
      isTarget: isTarget ?? this.isTarget,
      matchedAt: matchedAt ?? this.matchedAt,
      positionName: positionName,
      department: department,
      recruitCount: recruitCount,
      policyTitle: policyTitle,
      city: city,
      province: province,
    );
  }

  static List<String> _listFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) return List<String>.from(jsonDecode(value));
    return [];
  }

  static dynamic _listToJson(List<String> value) => value;
}
