// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRegistration _$UserRegistrationFromJson(Map<String, dynamic> json) =>
    UserRegistration(
      id: (json['id'] as num?)?.toInt(),
      calendarId: (json['calendar_id'] as num).toInt(),
      ticketNumber: json['ticket_number'] as String? ?? '',
      examLocation: json['exam_location'] as String? ?? '',
      seatNumber: json['seat_number'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$UserRegistrationToJson(UserRegistration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'calendar_id': instance.calendarId,
      'ticket_number': instance.ticketNumber,
      'exam_location': instance.examLocation,
      'seat_number': instance.seatNumber,
      'notes': instance.notes,
      'created_at': instance.createdAt,
    };
