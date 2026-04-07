import 'package:json_annotation/json_annotation.dart';

part 'exam_calendar_event.g.dart';

/// 考试日历事件
@JsonSerializable()
class ExamCalendarEvent {
  final int? id;
  final String name;
  @JsonKey(name: 'exam_type')
  final String examType;
  final String province;
  @JsonKey(name: 'announcement_date')
  final String? announcementDate;
  @JsonKey(name: 'reg_start_date')
  final String? regStartDate;
  @JsonKey(name: 'reg_end_date')
  final String? regEndDate;
  @JsonKey(name: 'payment_deadline')
  final String? paymentDeadline;
  @JsonKey(name: 'ticket_print_date')
  final String? ticketPrintDate;
  @JsonKey(name: 'exam_date')
  final String? examDate;
  @JsonKey(name: 'score_release_date')
  final String? scoreReleaseDate;
  @JsonKey(name: 'interview_date')
  final String? interviewDate;
  @JsonKey(name: 'source_url')
  final String sourceUrl;
  @JsonKey(name: 'is_subscribed')
  final int isSubscribed;
  final String notes;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const ExamCalendarEvent({
    this.id,
    required this.name,
    required this.examType,
    this.province = '',
    this.announcementDate,
    this.regStartDate,
    this.regEndDate,
    this.paymentDeadline,
    this.ticketPrintDate,
    this.examDate,
    this.scoreReleaseDate,
    this.interviewDate,
    this.sourceUrl = '',
    this.isSubscribed = 0,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ExamCalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$ExamCalendarEventFromJson(json);
  Map<String, dynamic> toJson() => _$ExamCalendarEventToJson(this);

  /// 从数据库 Map 构造
  factory ExamCalendarEvent.fromDb(Map<String, dynamic> map) {
    return ExamCalendarEvent(
      id: map['id'] as int?,
      name: map['name'] as String,
      examType: map['exam_type'] as String,
      province: (map['province'] as String?) ?? '',
      announcementDate: map['announcement_date'] as String?,
      regStartDate: map['reg_start_date'] as String?,
      regEndDate: map['reg_end_date'] as String?,
      paymentDeadline: map['payment_deadline'] as String?,
      ticketPrintDate: map['ticket_print_date'] as String?,
      examDate: map['exam_date'] as String?,
      scoreReleaseDate: map['score_release_date'] as String?,
      interviewDate: map['interview_date'] as String?,
      sourceUrl: (map['source_url'] as String?) ?? '',
      isSubscribed: (map['is_subscribed'] as int?) ?? 0,
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'exam_type': examType,
      'province': province,
      'announcement_date': announcementDate,
      'reg_start_date': regStartDate,
      'reg_end_date': regEndDate,
      'payment_deadline': paymentDeadline,
      'ticket_print_date': ticketPrintDate,
      'exam_date': examDate,
      'score_release_date': scoreReleaseDate,
      'interview_date': interviewDate,
      'source_url': sourceUrl,
      'is_subscribed': isSubscribed,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ExamCalendarEvent copyWith({
    int? id,
    String? name,
    String? examType,
    String? province,
    String? announcementDate,
    String? regStartDate,
    String? regEndDate,
    String? paymentDeadline,
    String? ticketPrintDate,
    String? examDate,
    String? scoreReleaseDate,
    String? interviewDate,
    String? sourceUrl,
    int? isSubscribed,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return ExamCalendarEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      examType: examType ?? this.examType,
      province: province ?? this.province,
      announcementDate: announcementDate ?? this.announcementDate,
      regStartDate: regStartDate ?? this.regStartDate,
      regEndDate: regEndDate ?? this.regEndDate,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      ticketPrintDate: ticketPrintDate ?? this.ticketPrintDate,
      examDate: examDate ?? this.examDate,
      scoreReleaseDate: scoreReleaseDate ?? this.scoreReleaseDate,
      interviewDate: interviewDate ?? this.interviewDate,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 所有 8 个日期字段
  List<String?> get allDates => [
        announcementDate,
        regStartDate,
        regEndDate,
        paymentDeadline,
        ticketPrintDate,
        examDate,
        scoreReleaseDate,
        interviewDate,
      ];

  /// 安全解析日期字符串，非法日期返回 null
  static DateTime? tryParseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// 获取最近的未来日期节点名称和日期
  ({String label, DateTime date, int daysLeft})? get nextMilestone {
    final now = DateTime.now();
    final milestones = <(String, DateTime)>[];
    final labels = [
      '公告发布',
      '报名开始',
      '报名截止',
      '缴费截止',
      '准考证打印',
      '笔试',
      '成绩公布',
      '面试',
    ];
    for (int i = 0; i < allDates.length; i++) {
      final d = tryParseDate(allDates[i]);
      if (d != null && d.isAfter(now)) {
        milestones.add((labels[i], d));
      }
    }
    if (milestones.isEmpty) return null;
    milestones.sort((a, b) => a.$2.compareTo(b.$2));
    final nearest = milestones.first;
    final daysLeft = nearest.$2.difference(now).inDays;
    return (label: nearest.$1, date: nearest.$2, daysLeft: daysLeft);
  }

  bool get subscribed => isSubscribed == 1;
}
