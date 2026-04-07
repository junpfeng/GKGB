import 'package:json_annotation/json_annotation.dart';

part 'exam.g.dart';

/// 模拟考试状态
enum ExamStatus { pending, ongoing, finished }

/// 模拟考试记录
@JsonSerializable()
class Exam {
  final int? id;
  final String subject;
  @JsonKey(name: 'total_questions')
  final int totalQuestions;
  final double score;
  @JsonKey(name: 'time_limit')
  final int timeLimit; // 单位：秒
  @JsonKey(name: 'started_at')
  final String? startedAt;
  @JsonKey(name: 'finished_at')
  final String? finishedAt;
  final String status; // pending/ongoing/finished

  const Exam({
    this.id,
    required this.subject,
    required this.totalQuestions,
    this.score = 0,
    required this.timeLimit,
    this.startedAt,
    this.finishedAt,
    this.status = 'pending',
  });

  factory Exam.fromJson(Map<String, dynamic> json) => _$ExamFromJson(json);
  Map<String, dynamic> toJson() => _$ExamToJson(this);

  factory Exam.fromDb(Map<String, dynamic> map) {
    return Exam(
      id: map['id'] as int?,
      subject: map['subject'] as String,
      totalQuestions: map['total_questions'] as int,
      score: ((map['score'] as num?) ?? 0).toDouble(),
      timeLimit: map['time_limit'] as int,
      startedAt: map['started_at'] as String?,
      finishedAt: map['finished_at'] as String?,
      status: (map['status'] as String?) ?? 'pending',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'subject': subject,
      'total_questions': totalQuestions,
      'score': score,
      'time_limit': timeLimit,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'status': status,
    };
  }

  Exam copyWith({
    int? id,
    String? subject,
    int? totalQuestions,
    double? score,
    int? timeLimit,
    String? startedAt,
    String? finishedAt,
    String? status,
  }) {
    return Exam(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      score: score ?? this.score,
      timeLimit: timeLimit ?? this.timeLimit,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
    );
  }
}
