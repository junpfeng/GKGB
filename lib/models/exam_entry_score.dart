import 'package:json_annotation/json_annotation.dart';

part 'exam_entry_score.g.dart';

/// 进面分数线数据模型
@JsonSerializable()
class ExamEntryScore {
  final int? id;
  final String province;
  final String city;
  final int year;
  @JsonKey(name: 'exam_type')
  final String examType;
  final String department;
  @JsonKey(name: 'position_name')
  final String positionName;
  @JsonKey(name: 'position_code')
  final String? positionCode;
  @JsonKey(name: 'recruit_count')
  final int? recruitCount;
  @JsonKey(name: 'major_req')
  final String? majorReq;
  @JsonKey(name: 'education_req')
  final String? educationReq;
  @JsonKey(name: 'degree_req')
  final String? degreeReq;
  @JsonKey(name: 'political_req')
  final String? politicalReq;
  @JsonKey(name: 'work_exp_req')
  final String? workExpReq;
  @JsonKey(name: 'other_req')
  final String? otherReq;
  @JsonKey(name: 'min_entry_score')
  final double? minEntryScore;
  @JsonKey(name: 'max_entry_score')
  final double? maxEntryScore;
  @JsonKey(name: 'entry_count')
  final int? entryCount;
  @JsonKey(name: 'source_url')
  final String? sourceUrl;
  @JsonKey(name: 'fetched_at')
  final String? fetchedAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const ExamEntryScore({
    this.id,
    required this.province,
    required this.city,
    required this.year,
    required this.examType,
    required this.department,
    required this.positionName,
    this.positionCode,
    this.recruitCount,
    this.majorReq,
    this.educationReq,
    this.degreeReq,
    this.politicalReq,
    this.workExpReq,
    this.otherReq,
    this.minEntryScore,
    this.maxEntryScore,
    this.entryCount,
    this.sourceUrl,
    this.fetchedAt,
    this.updatedAt,
  });

  factory ExamEntryScore.fromJson(Map<String, dynamic> json) =>
      _$ExamEntryScoreFromJson(json);
  Map<String, dynamic> toJson() => _$ExamEntryScoreToJson(this);

  factory ExamEntryScore.fromDb(Map<String, dynamic> map) {
    return ExamEntryScore(
      id: map['id'] as int?,
      province: map['province'] as String,
      city: map['city'] as String,
      year: map['year'] as int,
      examType: map['exam_type'] as String,
      department: map['department'] as String,
      positionName: map['position_name'] as String,
      positionCode: map['position_code'] as String?,
      recruitCount: map['recruit_count'] as int?,
      majorReq: map['major_req'] as String?,
      educationReq: map['education_req'] as String?,
      degreeReq: map['degree_req'] as String?,
      politicalReq: map['political_req'] as String?,
      workExpReq: map['work_exp_req'] as String?,
      otherReq: map['other_req'] as String?,
      minEntryScore: (map['min_entry_score'] as num?)?.toDouble(),
      maxEntryScore: (map['max_entry_score'] as num?)?.toDouble(),
      entryCount: map['entry_count'] as int?,
      sourceUrl: map['source_url'] as String?,
      fetchedAt: map['fetched_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'province': province,
      'city': city,
      'year': year,
      'exam_type': examType,
      'department': department,
      'position_name': positionName,
      'position_code': positionCode,
      'recruit_count': recruitCount,
      'major_req': majorReq,
      'education_req': educationReq,
      'degree_req': degreeReq,
      'political_req': politicalReq,
      'work_exp_req': workExpReq,
      'other_req': otherReq,
      'min_entry_score': minEntryScore,
      'max_entry_score': maxEntryScore,
      'entry_count': entryCount,
      'source_url': sourceUrl,
      'fetched_at': fetchedAt,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// 平均进面分数（用于热度排行）
  double? get avgEntryScore {
    if (minEntryScore != null && maxEntryScore != null) {
      return (minEntryScore! + maxEntryScore!) / 2;
    }
    return minEntryScore ?? maxEntryScore;
  }

  /// 分数区间展示文本
  String get scoreRangeText {
    if (minEntryScore == null && maxEntryScore == null) return '暂无数据';
    if (minEntryScore != null && maxEntryScore != null) {
      return '${minEntryScore!.toStringAsFixed(1)} ~ ${maxEntryScore!.toStringAsFixed(1)}';
    }
    return (minEntryScore ?? maxEntryScore)!.toStringAsFixed(1);
  }
}
