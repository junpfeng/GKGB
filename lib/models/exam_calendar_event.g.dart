// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_calendar_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExamCalendarEvent _$ExamCalendarEventFromJson(Map<String, dynamic> json) =>
    ExamCalendarEvent(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      examType: json['exam_type'] as String,
      province: json['province'] as String? ?? '',
      announcementDate: json['announcement_date'] as String?,
      regStartDate: json['reg_start_date'] as String?,
      regEndDate: json['reg_end_date'] as String?,
      paymentDeadline: json['payment_deadline'] as String?,
      ticketPrintDate: json['ticket_print_date'] as String?,
      examDate: json['exam_date'] as String?,
      scoreReleaseDate: json['score_release_date'] as String?,
      interviewDate: json['interview_date'] as String?,
      sourceUrl: json['source_url'] as String? ?? '',
      isSubscribed: (json['is_subscribed'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ExamCalendarEventToJson(ExamCalendarEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'exam_type': instance.examType,
      'province': instance.province,
      'announcement_date': instance.announcementDate,
      'reg_start_date': instance.regStartDate,
      'reg_end_date': instance.regEndDate,
      'payment_deadline': instance.paymentDeadline,
      'ticket_print_date': instance.ticketPrintDate,
      'exam_date': instance.examDate,
      'score_release_date': instance.scoreReleaseDate,
      'interview_date': instance.interviewDate,
      'source_url': instance.sourceUrl,
      'is_subscribed': instance.isSubscribed,
      'notes': instance.notes,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
