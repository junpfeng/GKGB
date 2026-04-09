import 'package:json_annotation/json_annotation.dart';

part 'essay_sub_question.g.dart';

/// 申论小题模型
@JsonSerializable()
class EssaySubQuestion {
  final int? id;
  final int year;
  final String region;
  @JsonKey(name: 'exam_type')
  final String examType;
  @JsonKey(name: 'exam_session', defaultValue: '')
  final String examSession;
  @JsonKey(name: 'question_number')
  final int questionNumber;
  @JsonKey(name: 'question_text')
  final String questionText;
  @JsonKey(name: 'question_type', defaultValue: '')
  final String questionType;
  @JsonKey(name: 'material_summary', defaultValue: '')
  final String materialSummary;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const EssaySubQuestion({
    this.id,
    required this.year,
    required this.region,
    required this.examType,
    this.examSession = '',
    required this.questionNumber,
    required this.questionText,
    this.questionType = '',
    this.materialSummary = '',
    this.createdAt,
  });

  factory EssaySubQuestion.fromJson(Map<String, dynamic> json) =>
      _$EssaySubQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$EssaySubQuestionToJson(this);

  factory EssaySubQuestion.fromDb(Map<String, dynamic> map) {
    return EssaySubQuestion(
      id: map['id'] as int?,
      year: map['year'] as int,
      region: map['region'] as String,
      examType: map['exam_type'] as String,
      examSession: (map['exam_session'] as String?) ?? '',
      questionNumber: map['question_number'] as int,
      questionText: map['question_text'] as String,
      questionType: (map['question_type'] as String?) ?? '',
      materialSummary: (map['material_summary'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'year': year,
      'region': region,
      'exam_type': examType,
      'exam_session': examSession,
      'question_number': questionNumber,
      'question_text': questionText,
      'question_type': questionType,
      'material_summary': materialSummary,
    };
  }

  /// 生成试卷维度的唯一标识（用于 group by 去重）
  String get examKey => '$year|$region|$examType|$examSession';

  /// 试卷显示标题
  String get examTitle {
    final sessionSuffix = examSession.isNotEmpty ? ' $examSession' : '';
    return '$year年 $region $examType$sessionSuffix';
  }

  EssaySubQuestion copyWith({
    int? id,
    int? year,
    String? region,
    String? examType,
    String? examSession,
    int? questionNumber,
    String? questionText,
    String? questionType,
    String? materialSummary,
    String? createdAt,
  }) {
    return EssaySubQuestion(
      id: id ?? this.id,
      year: year ?? this.year,
      region: region ?? this.region,
      examType: examType ?? this.examType,
      examSession: examSession ?? this.examSession,
      questionNumber: questionNumber ?? this.questionNumber,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      materialSummary: materialSummary ?? this.materialSummary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
