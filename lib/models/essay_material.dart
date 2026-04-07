import 'package:json_annotation/json_annotation.dart';

part 'essay_material.g.dart';

/// 申论素材模型
@JsonSerializable()
class EssayMaterial {
  final int? id;
  /// 主题：经济发展/社会治理/生态环保/文化教育/科技创新/乡村振兴
  final String theme;
  /// 类型：名言金句/典型案例/政策表述/数据支撑
  @JsonKey(name: 'material_type')
  final String materialType;
  final String content;
  @JsonKey(defaultValue: '')
  final String source;
  @JsonKey(name: 'is_favorited', defaultValue: 0)
  final int isFavorited;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const EssayMaterial({
    this.id,
    required this.theme,
    required this.materialType,
    required this.content,
    this.source = '',
    this.isFavorited = 0,
    this.createdAt,
  });

  bool get favorited => isFavorited == 1;

  factory EssayMaterial.fromJson(Map<String, dynamic> json) =>
      _$EssayMaterialFromJson(json);
  Map<String, dynamic> toJson() => _$EssayMaterialToJson(this);

  factory EssayMaterial.fromDb(Map<String, dynamic> map) {
    return EssayMaterial(
      id: map['id'] as int?,
      theme: map['theme'] as String,
      materialType: map['material_type'] as String,
      content: map['content'] as String,
      source: (map['source'] as String?) ?? '',
      isFavorited: (map['is_favorited'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'theme': theme,
      'material_type': materialType,
      'content': content,
      'source': source,
      'is_favorited': isFavorited,
    };
  }

  EssayMaterial copyWith({
    int? id,
    String? theme,
    String? materialType,
    String? content,
    String? source,
    int? isFavorited,
    String? createdAt,
  }) {
    return EssayMaterial(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      materialType: materialType ?? this.materialType,
      content: content ?? this.content,
      source: source ?? this.source,
      isFavorited: isFavorited ?? this.isFavorited,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
