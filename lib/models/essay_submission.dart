import 'package:json_annotation/json_annotation.dart';

part 'essay_submission.g.dart';

/// 申论写作提交模型
@JsonSerializable()
class EssaySubmission {
  final int? id;
  final String topic;
  final String content;
  @JsonKey(name: 'word_count', defaultValue: 0)
  final int wordCount;
  @JsonKey(name: 'time_spent', defaultValue: 0)
  final int timeSpent;
  @JsonKey(name: 'ai_score', defaultValue: 0)
  final double aiScore;
  @JsonKey(name: 'ai_comment', defaultValue: '')
  final String aiComment;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const EssaySubmission({
    this.id,
    required this.topic,
    required this.content,
    this.wordCount = 0,
    this.timeSpent = 0,
    this.aiScore = 0,
    this.aiComment = '',
    this.createdAt,
  });

  factory EssaySubmission.fromJson(Map<String, dynamic> json) =>
      _$EssaySubmissionFromJson(json);
  Map<String, dynamic> toJson() => _$EssaySubmissionToJson(this);

  factory EssaySubmission.fromDb(Map<String, dynamic> map) {
    return EssaySubmission(
      id: map['id'] as int?,
      topic: map['topic'] as String,
      content: (map['content'] as String?) ?? '',
      wordCount: (map['word_count'] as int?) ?? 0,
      timeSpent: (map['time_spent'] as int?) ?? 0,
      aiScore: ((map['ai_score'] as num?) ?? 0).toDouble(),
      aiComment: (map['ai_comment'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'topic': topic,
      'content': content,
      'word_count': wordCount,
      'time_spent': timeSpent,
      'ai_score': aiScore,
      'ai_comment': aiComment,
    };
  }

  EssaySubmission copyWith({
    int? id,
    String? topic,
    String? content,
    int? wordCount,
    int? timeSpent,
    double? aiScore,
    String? aiComment,
    String? createdAt,
  }) {
    return EssaySubmission(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      timeSpent: timeSpent ?? this.timeSpent,
      aiScore: aiScore ?? this.aiScore,
      aiComment: aiComment ?? this.aiComment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
