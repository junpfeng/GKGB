import 'package:json_annotation/json_annotation.dart';

part 'mastery_score.g.dart';

/// 知识点掌握度模型
@JsonSerializable()
class MasteryScore {
  final int? id;
  @JsonKey(name: 'knowledge_point_id')
  final int knowledgePointId;
  final double score;
  @JsonKey(name: 'total_attempts')
  final int totalAttempts;
  @JsonKey(name: 'correct_attempts')
  final int correctAttempts;
  @JsonKey(name: 'last_practiced_at')
  final String? lastPracticedAt;
  @JsonKey(name: 'next_review_at')
  final String? nextReviewAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const MasteryScore({
    this.id,
    required this.knowledgePointId,
    this.score = 50,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.lastPracticedAt,
    this.nextReviewAt,
    this.updatedAt,
  });

  factory MasteryScore.fromJson(Map<String, dynamic> json) =>
      _$MasteryScoreFromJson(json);
  Map<String, dynamic> toJson() => _$MasteryScoreToJson(this);

  factory MasteryScore.fromDb(Map<String, dynamic> map) {
    return MasteryScore(
      id: map['id'] as int?,
      knowledgePointId: map['knowledge_point_id'] as int,
      score: (map['score'] as num?)?.toDouble() ?? 50,
      totalAttempts: (map['total_attempts'] as int?) ?? 0,
      correctAttempts: (map['correct_attempts'] as int?) ?? 0,
      lastPracticedAt: map['last_practiced_at'] as String?,
      nextReviewAt: map['next_review_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'knowledge_point_id': knowledgePointId,
      'score': score,
      'total_attempts': totalAttempts,
      'correct_attempts': correctAttempts,
      'last_practiced_at': lastPracticedAt,
      'next_review_at': nextReviewAt,
      'updated_at': updatedAt,
    };
  }

  /// 正确率
  double get accuracy =>
      totalAttempts == 0 ? 0 : correctAttempts / totalAttempts;
}
