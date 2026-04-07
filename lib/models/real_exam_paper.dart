import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'real_exam_paper.g.dart';

/// 真题试卷模板（静态元数据）
@JsonSerializable()
class RealExamPaper {
  final int? id;
  final String name;
  final String region;
  final int year;
  @JsonKey(name: 'exam_type')
  final String examType;        // 国考/省考/事业编/选调
  @JsonKey(name: 'exam_session')
  final String examSession;     // 上半年/下半年
  final String subject;         // 行测/申论/公基
  @JsonKey(name: 'time_limit')
  final int timeLimit;          // 单位：秒
  @JsonKey(name: 'total_score')
  final double totalScore;
  @JsonKey(name: 'question_ids', fromJson: _idsFromJson, toJson: _idsToJson)
  final List<int> questionIds;  // 有序题目 ID 列表
  @JsonKey(name: 'score_distribution', fromJson: _scoreDistFromJson, toJson: _scoreDistToJson)
  final Map<String, double>? scoreDistribution; // 每题分值（可选）
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const RealExamPaper({
    this.id,
    required this.name,
    required this.region,
    required this.year,
    required this.examType,
    this.examSession = '',
    required this.subject,
    required this.timeLimit,
    this.totalScore = 100,
    required this.questionIds,
    this.scoreDistribution,
    this.createdAt,
  });

  factory RealExamPaper.fromJson(Map<String, dynamic> json) =>
      _$RealExamPaperFromJson(json);
  Map<String, dynamic> toJson() => _$RealExamPaperToJson(this);

  /// 从数据库 Map 转换
  factory RealExamPaper.fromDb(Map<String, dynamic> map) {
    return RealExamPaper(
      id: map['id'] as int?,
      name: map['name'] as String,
      region: map['region'] as String,
      year: map['year'] as int,
      examType: map['exam_type'] as String,
      examSession: (map['exam_session'] as String?) ?? '',
      subject: map['subject'] as String,
      timeLimit: map['time_limit'] as int,
      totalScore: ((map['total_score'] as num?) ?? 100).toDouble(),
      questionIds: map['question_ids'] != null
          ? List<int>.from(jsonDecode(map['question_ids'] as String))
          : [],
      scoreDistribution: map['score_distribution'] != null
          ? Map<String, double>.from(
              (jsonDecode(map['score_distribution'] as String) as Map)
                  .map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : null,
      createdAt: map['created_at'] as String?,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'region': region,
      'year': year,
      'exam_type': examType,
      'exam_session': examSession,
      'subject': subject,
      'time_limit': timeLimit,
      'total_score': totalScore,
      'question_ids': jsonEncode(questionIds),
      if (scoreDistribution != null)
        'score_distribution': jsonEncode(scoreDistribution),
    };
  }

  static List<int> _idsFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<int>.from(value);
    if (value is String) return List<int>.from(jsonDecode(value));
    return [];
  }

  static dynamic _idsToJson(List<int> ids) => ids;

  static Map<String, double>? _scoreDistFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    }
    if (value is String) {
      final decoded = jsonDecode(value) as Map;
      return decoded
          .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    }
    return null;
  }

  static dynamic _scoreDistToJson(Map<String, double>? dist) => dist;
}
