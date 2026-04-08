// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_exam_target.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserExamTarget _$UserExamTargetFromJson(Map<String, dynamic> json) =>
    UserExamTarget(
      id: (json['id'] as num?)?.toInt(),
      examCategoryId: json['exam_category_id'] as String,
      subTypeId: json['sub_type_id'] as String? ?? '',
      province: json['province'] as String? ?? '',
      isPrimary: (json['is_primary'] as num?)?.toInt() ?? 1,
      targetExamDate: json['target_exam_date'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$UserExamTargetToJson(UserExamTarget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exam_category_id': instance.examCategoryId,
      'sub_type_id': instance.subTypeId,
      'province': instance.province,
      'is_primary': instance.isPrimary,
      'target_exam_date': instance.targetExamDate,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
