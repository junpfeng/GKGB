import 'package:json_annotation/json_annotation.dart';

part 'hot_topic.g.dart';

/// 时政热点模型
@JsonSerializable()
class HotTopic {
  final int? id;
  final String title;
  @JsonKey(defaultValue: '')
  final String summary;
  @JsonKey(defaultValue: '')
  final String source;
  @JsonKey(name: 'source_url', defaultValue: '')
  final String sourceUrl;
  @JsonKey(name: 'publish_date')
  final String? publishDate;
  @JsonKey(name: 'relevance_score', defaultValue: 5)
  final int relevanceScore;
  @JsonKey(name: 'exam_points', defaultValue: '')
  final String examPoints;
  @JsonKey(name: 'essay_angles', defaultValue: '')
  final String essayAngles;
  @JsonKey(defaultValue: '')
  final String category;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const HotTopic({
    this.id,
    required this.title,
    this.summary = '',
    this.source = '',
    this.sourceUrl = '',
    this.publishDate,
    this.relevanceScore = 5,
    this.examPoints = '',
    this.essayAngles = '',
    this.category = '',
    this.createdAt,
  });

  factory HotTopic.fromJson(Map<String, dynamic> json) =>
      _$HotTopicFromJson(json);
  Map<String, dynamic> toJson() => _$HotTopicToJson(this);

  factory HotTopic.fromDb(Map<String, dynamic> map) {
    return HotTopic(
      id: map['id'] as int?,
      title: map['title'] as String,
      summary: (map['summary'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
      sourceUrl: (map['source_url'] as String?) ?? '',
      publishDate: map['publish_date'] as String?,
      relevanceScore: (map['relevance_score'] as int?) ?? 5,
      examPoints: (map['exam_points'] as String?) ?? '',
      essayAngles: (map['essay_angles'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'summary': summary,
      'source': source,
      'source_url': sourceUrl,
      'publish_date': publishDate,
      'relevance_score': relevanceScore,
      'exam_points': examPoints,
      'essay_angles': essayAngles,
      'category': category,
    };
  }

  HotTopic copyWith({
    int? id,
    String? title,
    String? summary,
    String? source,
    String? sourceUrl,
    String? publishDate,
    int? relevanceScore,
    String? examPoints,
    String? essayAngles,
    String? category,
    String? createdAt,
  }) {
    return HotTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      publishDate: publishDate ?? this.publishDate,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      examPoints: examPoints ?? this.examPoints,
      essayAngles: essayAngles ?? this.essayAngles,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
