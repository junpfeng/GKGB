import 'package:json_annotation/json_annotation.dart';

part 'interview_session.g.dart';

/// 面试会话模型
@JsonSerializable()
class InterviewSession {
  final int? id;
  /// 题型或"综合随机"
  final String category;
  @JsonKey(name: 'total_questions')
  final int totalQuestions;
  /// 综合得分（各题平均）
  @JsonKey(name: 'total_score')
  final double totalScore;
  /// ongoing/finished/cancelled
  final String status;
  /// text/voice
  final String mode;
  @JsonKey(name: 'started_at')
  final String? startedAt;
  @JsonKey(name: 'finished_at')
  final String? finishedAt;
  /// AI 生成的综合评价
  final String? summary;

  const InterviewSession({
    this.id,
    required this.category,
    required this.totalQuestions,
    this.totalScore = 0,
    this.status = 'ongoing',
    this.mode = 'text',
    this.startedAt,
    this.finishedAt,
    this.summary,
  });

  factory InterviewSession.fromJson(Map<String, dynamic> json) =>
      _$InterviewSessionFromJson(json);
  Map<String, dynamic> toJson() => _$InterviewSessionToJson(this);

  factory InterviewSession.fromDb(Map<String, dynamic> map) {
    return InterviewSession(
      id: map['id'] as int?,
      category: map['category'] as String,
      totalQuestions: map['total_questions'] as int,
      totalScore: ((map['total_score'] as num?) ?? 0).toDouble(),
      status: (map['status'] as String?) ?? 'ongoing',
      mode: (map['mode'] as String?) ?? 'text',
      startedAt: map['started_at'] as String?,
      finishedAt: map['finished_at'] as String?,
      summary: map['summary'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'total_questions': totalQuestions,
      'total_score': totalScore,
      'status': status,
      'mode': mode,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'summary': summary,
    };
  }

  InterviewSession copyWith({
    int? id,
    String? category,
    int? totalQuestions,
    double? totalScore,
    String? status,
    String? mode,
    String? startedAt,
    String? finishedAt,
    String? summary,
  }) {
    return InterviewSession(
      id: id ?? this.id,
      category: category ?? this.category,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalScore: totalScore ?? this.totalScore,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      summary: summary ?? this.summary,
    );
  }
}
