// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmConfig _$LlmConfigFromJson(Map<String, dynamic> json) => LlmConfig(
  id: (json['id'] as num?)?.toInt(),
  providerName: json['provider_name'] as String,
  baseUrl: json['base_url'] as String?,
  modelName: json['model_name'] as String?,
  isDefault: json['is_default'] as bool? ?? false,
  isFallback: json['is_fallback'] as bool? ?? false,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$LlmConfigToJson(LlmConfig instance) => <String, dynamic>{
  'id': instance.id,
  'provider_name': instance.providerName,
  'base_url': instance.baseUrl,
  'model_name': instance.modelName,
  'is_default': instance.isDefault,
  'is_fallback': instance.isFallback,
  'updated_at': instance.updatedAt,
};
