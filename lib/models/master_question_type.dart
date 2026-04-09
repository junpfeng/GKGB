/// 母题类型定义模型
class MasterQuestionType {
  final int? id;
  final String category; // 数量关系/资料分析
  final String name; // 如"工程问题"
  final String description; // 简要说明
  final int sortOrder;
  final int isPreset; // 1=预置, 0=用户自定义
  final String? createdAt;

  const MasterQuestionType({
    this.id,
    required this.category,
    required this.name,
    this.description = '',
    this.sortOrder = 0,
    this.isPreset = 0,
    this.createdAt,
  });

  factory MasterQuestionType.fromDb(Map<String, dynamic> map) {
    return MasterQuestionType(
      id: map['id'] as int?,
      category: map['category'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isPreset: (map['is_preset'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'name': name,
      'description': description,
      'sort_order': sortOrder,
      'is_preset': isPreset,
    };
  }

  MasterQuestionType copyWith({
    int? id,
    String? category,
    String? name,
    String? description,
    int? sortOrder,
    int? isPreset,
    String? createdAt,
  }) {
    return MasterQuestionType(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
