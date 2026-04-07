import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'question.g.dart';

/// 题目类型枚举
enum QuestionType {
  single,    // 单选题
  multiple,  // 多选题
  judge,     // 判断题
  subjective // 主观题（申论/作文）
}

/// 题目模型
@JsonSerializable()
class Question {
  final int? id;
  final String subject;   // 行测/申论/公基
  final String category;  // 言语理解/数量关系 等
  final String type;      // single/multiple/judge/subjective
  final String content;
  @JsonKey(fromJson: _optionsFromJson, toJson: _optionsToJson)
  final List<String> options;
  final String answer;
  final String? explanation;
  final int difficulty;   // 1-5
  @JsonKey(name: 'created_at')
  final String? createdAt;

  // 真题相关字段
  final String region;       // 地区（如"北京"、"全国"）
  final int year;            // 年份（0 表示非真题）
  @JsonKey(name: 'exam_type')
  final String examType;     // 国考/省考/事业编/选调
  @JsonKey(name: 'exam_session')
  final String examSession;  // 上半年/下半年
  @JsonKey(name: 'is_real_exam')
  final int isRealExam;      // 1=真题, 0=非真题

  const Question({
    this.id,
    required this.subject,
    required this.category,
    required this.type,
    required this.content,
    this.options = const [],
    required this.answer,
    this.explanation,
    this.difficulty = 1,
    this.createdAt,
    this.region = '',
    this.year = 0,
    this.examType = '',
    this.examSession = '',
    this.isRealExam = 0,
  });

  factory Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionToJson(this);

  /// 从数据库 Map 转换（options 为 JSON 字符串）
  factory Question.fromDb(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      subject: map['subject'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      options: map['options'] != null
          ? List<String>.from(jsonDecode(map['options'] as String))
          : [],
      answer: map['answer'] as String,
      explanation: map['explanation'] as String?,
      difficulty: (map['difficulty'] as int?) ?? 1,
      createdAt: map['created_at'] as String?,
      region: (map['region'] as String?) ?? '',
      year: (map['year'] as int?) ?? 0,
      examType: (map['exam_type'] as String?) ?? '',
      examSession: (map['exam_session'] as String?) ?? '',
      isRealExam: (map['is_real_exam'] as int?) ?? 0,
    );
  }

  /// 转换为数据库 Map（options 序列化为 JSON 字符串）
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'subject': subject,
      'category': category,
      'type': type,
      'content': content,
      'options': jsonEncode(options),
      'answer': answer,
      'explanation': explanation,
      'difficulty': difficulty,
      'region': region,
      'year': year,
      'exam_type': examType,
      'exam_session': examSession,
      'is_real_exam': isRealExam,
    };
  }

  static List<String> _optionsFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) return List<String>.from(jsonDecode(value));
    return [];
  }

  static dynamic _optionsToJson(List<String> options) => options;
}
