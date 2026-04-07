// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay_material.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EssayMaterial _$EssayMaterialFromJson(Map<String, dynamic> json) =>
    EssayMaterial(
      id: (json['id'] as num?)?.toInt(),
      theme: json['theme'] as String,
      materialType: json['material_type'] as String,
      content: json['content'] as String,
      source: json['source'] as String? ?? '',
      isFavorited: (json['is_favorited'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$EssayMaterialToJson(EssayMaterial instance) =>
    <String, dynamic>{
      'id': instance.id,
      'theme': instance.theme,
      'material_type': instance.materialType,
      'content': instance.content,
      'source': instance.source,
      'is_favorited': instance.isFavorited,
      'created_at': instance.createdAt,
    };
