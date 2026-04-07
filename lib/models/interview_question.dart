import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'interview_question.g.dart';

/// 面试题模型
@JsonSerializable()
class InterviewQuestion {
  final int? id;
  /// 题型：综合分析/计划组织/人际关系/应急应变/自我认知
  final String category;
  /// 题目正文
  final String content;
  /// 参考答案框架
  @JsonKey(name: 'reference_answer')
  final String? referenceAnswer;
  /// 答题要点（JSON 数组字符串）
  @JsonKey(name: 'key_points')
  final String? keyPoints;
  /// 难度 1-5
  final int difficulty;
  /// 地区（空表示通用）
  final String region;
  /// 年份（0 表示模拟题）
  final int year;
  /// 来源说明
  final String source;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const InterviewQuestion({
    this.id,
    required this.category,
    required this.content,
    this.referenceAnswer,
    this.keyPoints,
    this.difficulty = 3,
    this.region = '',
    this.year = 0,
    this.source = '',
    this.createdAt,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) =>
      _$InterviewQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$InterviewQuestionToJson(this);

  factory InterviewQuestion.fromDb(Map<String, dynamic> map) {
    return InterviewQuestion(
      id: map['id'] as int?,
      category: map['category'] as String,
      content: map['content'] as String,
      referenceAnswer: map['reference_answer'] as String?,
      keyPoints: map['key_points'] as String?,
      difficulty: (map['difficulty'] as int?) ?? 3,
      region: (map['region'] as String?) ?? '',
      year: (map['year'] as int?) ?? 0,
      source: (map['source'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'content': content,
      'reference_answer': referenceAnswer,
      'key_points': keyPoints,
      'difficulty': difficulty,
      'region': region,
      'year': year,
      'source': source,
    };
  }

  /// 解析要点列表
  List<String> get keyPointsList {
    if (keyPoints == null || keyPoints!.isEmpty) return [];
    try {
      return (jsonDecode(keyPoints!) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  InterviewQuestion copyWith({
    int? id,
    String? category,
    String? content,
    String? referenceAnswer,
    String? keyPoints,
    int? difficulty,
    String? region,
    int? year,
    String? source,
    String? createdAt,
  }) {
    return InterviewQuestion(
      id: id ?? this.id,
      category: category ?? this.category,
      content: content ?? this.content,
      referenceAnswer: referenceAnswer ?? this.referenceAnswer,
      keyPoints: keyPoints ?? this.keyPoints,
      difficulty: difficulty ?? this.difficulty,
      region: region ?? this.region,
      year: year ?? this.year,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
