// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherAnswer _$TeacherAnswerFromJson(Map<String, dynamic> json) =>
    TeacherAnswer(
      id: (json['id'] as num?)?.toInt(),
      subQuestionId: (json['sub_question_id'] as num).toInt(),
      teacherName: json['teacher_name'] as String,
      teacherType: json['teacher_type'] as String? ?? 'teacher',
      answerText: json['answer_text'] as String,
      scorePoints:
          (json['score_points'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      sourceNote: json['source_note'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$TeacherAnswerToJson(TeacherAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sub_question_id': instance.subQuestionId,
      'teacher_name': instance.teacherName,
      'teacher_type': instance.teacherType,
      'answer_text': instance.answerText,
      'score_points': instance.scorePoints,
      'word_count': instance.wordCount,
      'source_note': instance.sourceNote,
      'created_at': instance.createdAt,
    };
