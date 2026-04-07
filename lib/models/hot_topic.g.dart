// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hot_topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotTopic _$HotTopicFromJson(Map<String, dynamic> json) => HotTopic(
  id: (json['id'] as num?)?.toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String? ?? '',
  source: json['source'] as String? ?? '',
  sourceUrl: json['source_url'] as String? ?? '',
  publishDate: json['publish_date'] as String?,
  relevanceScore: (json['relevance_score'] as num?)?.toInt() ?? 5,
  examPoints: json['exam_points'] as String? ?? '',
  essayAngles: json['essay_angles'] as String? ?? '',
  category: json['category'] as String? ?? '',
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$HotTopicToJson(HotTopic instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'summary': instance.summary,
  'source': instance.source,
  'source_url': instance.sourceUrl,
  'publish_date': instance.publishDate,
  'relevance_score': instance.relevanceScore,
  'exam_points': instance.examPoints,
  'essay_angles': instance.essayAngles,
  'category': instance.category,
  'created_at': instance.createdAt,
};
