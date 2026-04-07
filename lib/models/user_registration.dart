import 'package:json_annotation/json_annotation.dart';

part 'user_registration.g.dart';

/// 用户报名信息
@JsonSerializable()
class UserRegistration {
  final int? id;
  @JsonKey(name: 'calendar_id')
  final int calendarId;
  @JsonKey(name: 'ticket_number')
  final String ticketNumber;
  @JsonKey(name: 'exam_location')
  final String examLocation;
  @JsonKey(name: 'seat_number')
  final String seatNumber;
  final String notes;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const UserRegistration({
    this.id,
    required this.calendarId,
    this.ticketNumber = '',
    this.examLocation = '',
    this.seatNumber = '',
    this.notes = '',
    this.createdAt,
  });

  factory UserRegistration.fromJson(Map<String, dynamic> json) =>
      _$UserRegistrationFromJson(json);
  Map<String, dynamic> toJson() => _$UserRegistrationToJson(this);

  factory UserRegistration.fromDb(Map<String, dynamic> map) {
    return UserRegistration(
      id: map['id'] as int?,
      calendarId: map['calendar_id'] as int,
      ticketNumber: (map['ticket_number'] as String?) ?? '',
      examLocation: (map['exam_location'] as String?) ?? '',
      seatNumber: (map['seat_number'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'calendar_id': calendarId,
      'ticket_number': ticketNumber,
      'exam_location': examLocation,
      'seat_number': seatNumber,
      'notes': notes,
    };
  }

  UserRegistration copyWith({
    int? id,
    int? calendarId,
    String? ticketNumber,
    String? examLocation,
    String? seatNumber,
    String? notes,
    String? createdAt,
  }) {
    return UserRegistration(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      examLocation: examLocation ?? this.examLocation,
      seatNumber: seatNumber ?? this.seatNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get hasInfo =>
      ticketNumber.isNotEmpty ||
      examLocation.isNotEmpty ||
      seatNumber.isNotEmpty ||
      notes.isNotEmpty;
}
