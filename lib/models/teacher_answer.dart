import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'teacher_answer.g.dart';

/// 名师答案模型
@JsonSerializable()
class TeacherAnswer {
  final int? id;
  @JsonKey(name: 'sub_question_id')
  final int subQuestionId;
  @JsonKey(name: 'teacher_name')
  final String teacherName;
  @JsonKey(name: 'teacher_type', defaultValue: 'teacher')
  final String teacherType;
  @JsonKey(name: 'answer_text')
  final String answerText;
  @JsonKey(name: 'score_points', defaultValue: <String>[])
  final List<String> scorePoints;
  @JsonKey(name: 'word_count', defaultValue: 0)
  final int wordCount;
  @JsonKey(name: 'source_note', defaultValue: '')
  final String sourceNote;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const TeacherAnswer({
    this.id,
    required this.subQuestionId,
    required this.teacherName,
    this.teacherType = 'teacher',
    required this.answerText,
    this.scorePoints = const [],
    this.wordCount = 0,
    this.sourceNote = '',
    this.createdAt,
  });

  factory TeacherAnswer.fromJson(Map<String, dynamic> json) =>
      _$TeacherAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$TeacherAnswerToJson(this);

  factory TeacherAnswer.fromDb(Map<String, dynamic> map) {
    // score_points 在数据库中以 JSON 字符串存储
    List<String> points = [];
    final raw = map['score_points'];
    if (raw is String && raw.isNotEmpty) {
      try {
        points = (jsonDecode(raw) as List).cast<String>();
      } catch (_) {
        points = [];
      }
    }
    return TeacherAnswer(
      id: map['id'] as int?,
      subQuestionId: map['sub_question_id'] as int,
      teacherName: map['teacher_name'] as String,
      teacherType: (map['teacher_type'] as String?) ?? 'teacher',
      answerText: map['answer_text'] as String,
      scorePoints: points,
      wordCount: (map['word_count'] as int?) ?? 0,
      sourceNote: (map['source_note'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'sub_question_id': subQuestionId,
      'teacher_name': teacherName,
      'teacher_type': teacherType,
      'answer_text': answerText,
      'score_points': jsonEncode(scorePoints),
      'word_count': wordCount,
      'source_note': sourceNote,
    };
  }

  TeacherAnswer copyWith({
    int? id,
    int? subQuestionId,
    String? teacherName,
    String? teacherType,
    String? answerText,
    List<String>? scorePoints,
    int? wordCount,
    String? sourceNote,
    String? createdAt,
  }) {
    return TeacherAnswer(
      id: id ?? this.id,
      subQuestionId: subQuestionId ?? this.subQuestionId,
      teacherName: teacherName ?? this.teacherName,
      teacherType: teacherType ?? this.teacherType,
      answerText: answerText ?? this.answerText,
      scorePoints: scorePoints ?? this.scorePoints,
      wordCount: wordCount ?? this.wordCount,
      sourceNote: sourceNote ?? this.sourceNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
