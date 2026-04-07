import 'package:json_annotation/json_annotation.dart';

part 'llm_config.g.dart';

/// LLM 模型配置（API Key 单独存入 flutter_secure_storage）
@JsonSerializable()
class LlmConfig {
  final int? id;
  @JsonKey(name: 'provider_name')
  final String providerName; // deepseek/qwen/claude/openai/ollama
  @JsonKey(name: 'base_url')
  final String? baseUrl;
  @JsonKey(name: 'model_name')
  final String? modelName;
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @JsonKey(name: 'is_fallback')
  final bool isFallback;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const LlmConfig({
    this.id,
    required this.providerName,
    this.baseUrl,
    this.modelName,
    this.isDefault = false,
    this.isFallback = false,
    this.updatedAt,
  });

  factory LlmConfig.fromJson(Map<String, dynamic> json) => _$LlmConfigFromJson(json);
  Map<String, dynamic> toJson() => _$LlmConfigToJson(this);

  factory LlmConfig.fromDb(Map<String, dynamic> map) {
    return LlmConfig(
      id: map['id'] as int?,
      providerName: map['provider_name'] as String,
      baseUrl: map['base_url'] as String?,
      modelName: map['model_name'] as String?,
      isDefault: (map['is_default'] as int?) == 1,
      isFallback: (map['is_fallback'] as int?) == 1,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'provider_name': providerName,
      'base_url': baseUrl,
      'model_name': modelName,
      'is_default': isDefault ? 1 : 0,
      'is_fallback': isFallback ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  LlmConfig copyWith({
    int? id,
    String? providerName,
    String? baseUrl,
    String? modelName,
    bool? isDefault,
    bool? isFallback,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      providerName: providerName ?? this.providerName,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      isDefault: isDefault ?? this.isDefault,
      isFallback: isFallback ?? this.isFallback,
      updatedAt: updatedAt,
    );
  }

  /// secure storage 中存储 API Key 的 key 名
  String get secureStorageKey => 'llm_key_$providerName';
}
