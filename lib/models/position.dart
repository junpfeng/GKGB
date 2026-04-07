import 'package:json_annotation/json_annotation.dart';

part 'position.g.dart';

/// 岗位信息
@JsonSerializable()
class Position {
  final int? id;
  @JsonKey(name: 'policy_id')
  final int? policyId;
  @JsonKey(name: 'position_name')
  final String positionName;
  @JsonKey(name: 'position_code')
  final String? positionCode;
  final String? department;
  @JsonKey(name: 'recruit_count')
  final int recruitCount;
  @JsonKey(name: 'education_req')
  final String? educationReq;
  @JsonKey(name: 'degree_req')
  final String? degreeReq;
  @JsonKey(name: 'major_req')
  final String? majorReq;
  @JsonKey(name: 'age_req')
  final String? ageReq;
  @JsonKey(name: 'political_req')
  final String? politicalReq;
  @JsonKey(name: 'work_exp_req')
  final String? workExpReq;
  @JsonKey(name: 'certificate_req')
  final String? certificateReq;
  @JsonKey(name: 'gender_req')
  final String? genderReq;
  @JsonKey(name: 'hukou_req')
  final String? hukouReq;
  @JsonKey(name: 'other_req')
  final String? otherReq;
  @JsonKey(name: 'exam_subjects')
  final String? examSubjects;
  @JsonKey(name: 'exam_date')
  final String? examDate;

  // 关联字段（查询时 JOIN 获取，不存入 DB）
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? policyTitle;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? city;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? province;

  const Position({
    this.id,
    this.policyId,
    required this.positionName,
    this.positionCode,
    this.department,
    this.recruitCount = 1,
    this.educationReq,
    this.degreeReq,
    this.majorReq,
    this.ageReq,
    this.politicalReq,
    this.workExpReq,
    this.certificateReq,
    this.genderReq,
    this.hukouReq,
    this.otherReq,
    this.examSubjects,
    this.examDate,
    this.policyTitle,
    this.city,
    this.province,
  });

  factory Position.fromJson(Map<String, dynamic> json) => _$PositionFromJson(json);
  Map<String, dynamic> toJson() => _$PositionToJson(this);

  factory Position.fromDb(Map<String, dynamic> map) {
    return Position(
      id: map['id'] as int?,
      policyId: map['policy_id'] as int?,
      positionName: map['position_name'] as String,
      positionCode: map['position_code'] as String?,
      department: map['department'] as String?,
      recruitCount: (map['recruit_count'] as int?) ?? 1,
      educationReq: map['education_req'] as String?,
      degreeReq: map['degree_req'] as String?,
      majorReq: map['major_req'] as String?,
      ageReq: map['age_req'] as String?,
      politicalReq: map['political_req'] as String?,
      workExpReq: map['work_exp_req'] as String?,
      certificateReq: map['certificate_req'] as String?,
      genderReq: map['gender_req'] as String?,
      hukouReq: map['hukou_req'] as String?,
      otherReq: map['other_req'] as String?,
      examSubjects: map['exam_subjects'] as String?,
      examDate: map['exam_date'] as String?,
      policyTitle: map['policy_title'] as String?,
      city: map['city'] as String?,
      province: map['province'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      if (policyId != null) 'policy_id': policyId,
      'position_name': positionName,
      'position_code': positionCode,
      'department': department,
      'recruit_count': recruitCount,
      'education_req': educationReq,
      'degree_req': degreeReq,
      'major_req': majorReq,
      'age_req': ageReq,
      'political_req': politicalReq,
      'work_exp_req': workExpReq,
      'certificate_req': certificateReq,
      'gender_req': genderReq,
      'hukou_req': hukouReq,
      'other_req': otherReq,
      'exam_subjects': examSubjects,
      'exam_date': examDate,
    };
  }
}
