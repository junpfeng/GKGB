// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnowledgePoint _$KnowledgePointFromJson(Map<String, dynamic> json) =>
    KnowledgePoint(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      subject: json['subject'] as String,
      category: json['category'] as String,
      parentId: (json['parent_id'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$KnowledgePointToJson(KnowledgePoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'subject': instance.subject,
      'category': instance.category,
      'parent_id': instance.parentId,
      'sort_order': instance.sortOrder,
    };
