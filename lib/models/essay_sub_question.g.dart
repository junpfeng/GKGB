// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay_sub_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EssaySubQuestion _$EssaySubQuestionFromJson(Map<String, dynamic> json) =>
    EssaySubQuestion(
      id: (json['id'] as num?)?.toInt(),
      year: (json['year'] as num).toInt(),
      region: json['region'] as String,
      examType: json['exam_type'] as String,
      examSession: json['exam_session'] as String? ?? '',
      questionNumber: (json['question_number'] as num).toInt(),
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String? ?? '',
      materialSummary: json['material_summary'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$EssaySubQuestionToJson(EssaySubQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'year': instance.year,
      'region': instance.region,
      'exam_type': instance.examType,
      'exam_session': instance.examSession,
      'question_number': instance.questionNumber,
      'question_text': instance.questionText,
      'question_type': instance.questionType,
      'material_summary': instance.materialSummary,
      'created_at': instance.createdAt,
    };
