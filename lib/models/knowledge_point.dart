import 'package:json_annotation/json_annotation.dart';

part 'knowledge_point.g.dart';

/// 知识点模型
@JsonSerializable()
class KnowledgePoint {
  final int? id;
  final String name;
  final String subject;
  final String category;
  @JsonKey(name: 'parent_id')
  final int parentId;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const KnowledgePoint({
    this.id,
    required this.name,
    required this.subject,
    required this.category,
    this.parentId = 0,
    this.sortOrder = 0,
  });

  factory KnowledgePoint.fromJson(Map<String, dynamic> json) =>
      _$KnowledgePointFromJson(json);
  Map<String, dynamic> toJson() => _$KnowledgePointToJson(this);

  factory KnowledgePoint.fromDb(Map<String, dynamic> map) {
    return KnowledgePoint(
      id: map['id'] as int?,
      name: map['name'] as String,
      subject: map['subject'] as String,
      category: map['category'] as String,
      parentId: (map['parent_id'] as int?) ?? 0,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'subject': subject,
      'category': category,
      'parent_id': parentId,
      'sort_order': sortOrder,
    };
  }
}
