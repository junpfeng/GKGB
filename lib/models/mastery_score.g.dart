// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mastery_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MasteryScore _$MasteryScoreFromJson(Map<String, dynamic> json) => MasteryScore(
  id: (json['id'] as num?)?.toInt(),
  knowledgePointId: (json['knowledge_point_id'] as num).toInt(),
  score: (json['score'] as num?)?.toDouble() ?? 50,
  totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
  correctAttempts: (json['correct_attempts'] as num?)?.toInt() ?? 0,
  lastPracticedAt: json['last_practiced_at'] as String?,
  nextReviewAt: json['next_review_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$MasteryScoreToJson(MasteryScore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'knowledge_point_id': instance.knowledgePointId,
      'score': instance.score,
      'total_attempts': instance.totalAttempts,
      'correct_attempts': instance.correctAttempts,
      'last_practiced_at': instance.lastPracticedAt,
      'next_review_at': instance.nextReviewAt,
      'updated_at': instance.updatedAt,
    };
