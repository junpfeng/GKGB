import 'package:json_annotation/json_annotation.dart';

part 'interview_score.g.dart';

/// 面试评分详情模型
@JsonSerializable()
class InterviewScore {
  final int? id;
  @JsonKey(name: 'session_id')
  final int sessionId;
  @JsonKey(name: 'question_id')
  final int questionId;
  /// 用户作答内容
  @JsonKey(name: 'user_answer')
  final String userAnswer;
  /// 内容维度 1-10
  @JsonKey(name: 'content_score')
  final double contentScore;
  /// 表达维度 1-10
  @JsonKey(name: 'expression_score')
  final double expressionScore;
  /// 时间维度 1-10
  @JsonKey(name: 'time_score')
  final double timeScore;
  /// 综合分
  @JsonKey(name: 'total_score')
  final double totalScore;
  /// AI 逐题点评
  @JsonKey(name: 'ai_comment')
  final String? aiComment;
  /// AI 追问
  @JsonKey(name: 'follow_up_question')
  final String? followUpQuestion;
  /// 用户追问回答
  @JsonKey(name: 'follow_up_answer')
  final String? followUpAnswer;
  /// 追问点评
  @JsonKey(name: 'follow_up_comment')
  final String? followUpComment;
  /// 实际作答秒数
  @JsonKey(name: 'time_spent')
  final int timeSpent;
  @JsonKey(name: 'answered_at')
  final String? answeredAt;

  const InterviewScore({
    this.id,
    required this.sessionId,
    required this.questionId,
    required this.userAnswer,
    this.contentScore = 0,
    this.expressionScore = 0,
    this.timeScore = 0,
    this.totalScore = 0,
    this.aiComment,
    this.followUpQuestion,
    this.followUpAnswer,
    this.followUpComment,
    this.timeSpent = 0,
    this.answeredAt,
  });

  factory InterviewScore.fromJson(Map<String, dynamic> json) =>
      _$InterviewScoreFromJson(json);
  Map<String, dynamic> toJson() => _$InterviewScoreToJson(this);

  factory InterviewScore.fromDb(Map<String, dynamic> map) {
    return InterviewScore(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      questionId: map['question_id'] as int,
      userAnswer: map['user_answer'] as String,
      contentScore: ((map['content_score'] as num?) ?? 0).toDouble(),
      expressionScore: ((map['expression_score'] as num?) ?? 0).toDouble(),
      timeScore: ((map['time_score'] as num?) ?? 0).toDouble(),
      totalScore: ((map['total_score'] as num?) ?? 0).toDouble(),
      aiComment: map['ai_comment'] as String?,
      followUpQuestion: map['follow_up_question'] as String?,
      followUpAnswer: map['follow_up_answer'] as String?,
      followUpComment: map['follow_up_comment'] as String?,
      timeSpent: (map['time_spent'] as int?) ?? 0,
      answeredAt: map['answered_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'question_id': questionId,
      'user_answer': userAnswer,
      'content_score': contentScore,
      'expression_score': expressionScore,
      'time_score': timeScore,
      'total_score': totalScore,
      'ai_comment': aiComment,
      'follow_up_question': followUpQuestion,
      'follow_up_answer': followUpAnswer,
      'follow_up_comment': followUpComment,
      'time_spent': timeSpent,
      'answered_at': answeredAt ?? DateTime.now().toIso8601String(),
    };
  }

  InterviewScore copyWith({
    int? id,
    int? sessionId,
    int? questionId,
    String? userAnswer,
    double? contentScore,
    double? expressionScore,
    double? timeScore,
    double? totalScore,
    String? aiComment,
    String? followUpQuestion,
    String? followUpAnswer,
    String? followUpComment,
    int? timeSpent,
    String? answeredAt,
  }) {
    return InterviewScore(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      userAnswer: userAnswer ?? this.userAnswer,
      contentScore: contentScore ?? this.contentScore,
      expressionScore: expressionScore ?? this.expressionScore,
      timeScore: timeScore ?? this.timeScore,
      totalScore: totalScore ?? this.totalScore,
      aiComment: aiComment ?? this.aiComment,
      followUpQuestion: followUpQuestion ?? this.followUpQuestion,
      followUpAnswer: followUpAnswer ?? this.followUpAnswer,
      followUpComment: followUpComment ?? this.followUpComment,
      timeSpent: timeSpent ?? this.timeSpent,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }
}
