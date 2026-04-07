// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchResult _$MatchResultFromJson(Map<String, dynamic> json) => MatchResult(
  id: (json['id'] as num?)?.toInt(),
  positionId: (json['position_id'] as num).toInt(),
  matchScore: (json['match_score'] as num).toInt(),
  matchedItems: json['matched_items'] == null
      ? const []
      : MatchResult._listFromJson(json['matched_items']),
  riskItems: json['risk_items'] == null
      ? const []
      : MatchResult._listFromJson(json['risk_items']),
  unmatchedItems: json['unmatched_items'] == null
      ? const []
      : MatchResult._listFromJson(json['unmatched_items']),
  advice: json['advice'] as String?,
  isTarget: json['is_target'] as bool? ?? false,
  matchedAt: json['matched_at'] as String?,
);

Map<String, dynamic> _$MatchResultToJson(MatchResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'position_id': instance.positionId,
      'match_score': instance.matchScore,
      'matched_items': MatchResult._listToJson(instance.matchedItems),
      'risk_items': MatchResult._listToJson(instance.riskItems),
      'unmatched_items': MatchResult._listToJson(instance.unmatchedItems),
      'advice': instance.advice,
      'is_target': instance.isTarget,
      'matched_at': instance.matchedAt,
    };
