import 'package:json_annotation/json_annotation.dart';

part 'user_exam_target.g.dart';

/// 用户备考目标（DB 存储）
@JsonSerializable()
class UserExamTarget {
  final int? id;

  @JsonKey(name: 'exam_category_id')
  final String examCategoryId; // 对应 ExamCategory.id

  @JsonKey(name: 'sub_type_id')
  final String subTypeId; // 对应 ExamSubType.id，无则为 ''

  final String province; // 省份，无则为 ''

  @JsonKey(name: 'is_primary')
  final int isPrimary; // 1=主目标（v1 始终为 1）

  @JsonKey(name: 'target_exam_date')
  final String? targetExamDate; // 目标考试日期（可选）

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const UserExamTarget({
    this.id,
    required this.examCategoryId,
    this.subTypeId = '',
    this.province = '',
    this.isPrimary = 1,
    this.targetExamDate,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPrimaryTarget => isPrimary == 1;

  /// 是否为探索模式标记
  bool get isExploreMarker => examCategoryId == '__explore__';

  factory UserExamTarget.fromJson(Map<String, dynamic> json) =>
      _$UserExamTargetFromJson(json);

  Map<String, dynamic> toJson() => _$UserExamTargetToJson(this);

  /// 从 DB 行构建（字段名与 DB 列一致）
  factory UserExamTarget.fromDb(Map<String, dynamic> row) =>
      UserExamTarget.fromJson(row);

  /// 转为 DB 可插入的 Map（移除 id 和时间戳，让 DB 自动生成）
  Map<String, dynamic> toDb() {
    final map = toJson();
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');
    return map;
  }

  UserExamTarget copyWith({
    int? id,
    String? examCategoryId,
    String? subTypeId,
    String? province,
    int? isPrimary,
    String? targetExamDate,
  }) {
    return UserExamTarget(
      id: id ?? this.id,
      examCategoryId: examCategoryId ?? this.examCategoryId,
      subTypeId: subTypeId ?? this.subTypeId,
      province: province ?? this.province,
      isPrimary: isPrimary ?? this.isPrimary,
      targetExamDate: targetExamDate ?? this.targetExamDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
