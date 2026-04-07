// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Question _$QuestionFromJson(Map<String, dynamic> json) => Question(
  id: (json['id'] as num?)?.toInt(),
  subject: json['subject'] as String,
  category: json['category'] as String,
  type: json['type'] as String,
  content: json['content'] as String,
  options: json['options'] == null
      ? const []
      : Question._optionsFromJson(json['options']),
  answer: json['answer'] as String,
  explanation: json['explanation'] as String?,
  difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$QuestionToJson(Question instance) => <String, dynamic>{
  'id': instance.id,
  'subject': instance.subject,
  'category': instance.category,
  'type': instance.type,
  'content': instance.content,
  'options': Question._optionsToJson(instance.options),
  'answer': instance.answer,
  'explanation': instance.explanation,
  'difficulty': instance.difficulty,
  'created_at': instance.createdAt,
};
