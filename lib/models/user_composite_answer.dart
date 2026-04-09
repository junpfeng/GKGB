import 'package:json_annotation/json_annotation.dart';

part 'user_composite_answer.g.dart';

/// 用户综合答案模型
@JsonSerializable()
class UserCompositeAnswer {
  final int? id;
  @JsonKey(name: 'sub_question_id')
  final int subQuestionId;
  final String content;
  @JsonKey(defaultValue: '')
  final String notes;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const UserCompositeAnswer({
    this.id,
    required this.subQuestionId,
    required this.content,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory UserCompositeAnswer.fromJson(Map<String, dynamic> json) =>
      _$UserCompositeAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$UserCompositeAnswerToJson(this);

  factory UserCompositeAnswer.fromDb(Map<String, dynamic> map) {
    return UserCompositeAnswer(
      id: map['id'] as int?,
      subQuestionId: map['sub_question_id'] as int,
      content: (map['content'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'sub_question_id': subQuestionId,
      'content': content,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserCompositeAnswer copyWith({
    int? id,
    int? subQuestionId,
    String? content,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserCompositeAnswer(
      id: id ?? this.id,
      subQuestionId: subQuestionId ?? this.subQuestionId,
      content: content ?? this.content,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
