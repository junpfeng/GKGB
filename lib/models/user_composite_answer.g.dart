// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_composite_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserCompositeAnswer _$UserCompositeAnswerFromJson(Map<String, dynamic> json) =>
    UserCompositeAnswer(
      id: (json['id'] as num?)?.toInt(),
      subQuestionId: (json['sub_question_id'] as num).toInt(),
      content: json['content'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$UserCompositeAnswerToJson(
  UserCompositeAnswer instance,
) => <String, dynamic>{
  'id': instance.id,
  'sub_question_id': instance.subQuestionId,
  'content': instance.content,
  'notes': instance.notes,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
