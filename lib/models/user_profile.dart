import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

/// 用户画像
@JsonSerializable()
class UserProfile {
  final int? id;
  final String? education;        // 本科/硕士/博士
  final String? degree;           // 学士/硕士/博士
  final String? major;            // 专业名称
  @JsonKey(name: 'major_code')
  final String? majorCode;        // 专业编码
  final String? university;       // 毕业院校
  @JsonKey(name: 'is_985')
  final bool is985;
  @JsonKey(name: 'is_211')
  final bool is211;
  @JsonKey(name: 'work_years')
  final int workYears;
  @JsonKey(name: 'has_grassroots_exp')
  final bool hasGrassrootsExp;    // 基层工作经历
  @JsonKey(name: 'political_status')
  final String? politicalStatus;  // 群众/团员/党员
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'certificates')
  final List<String> certificates; // 资格证书列表
  final int? age;
  final String? gender;           // 男/女
  @JsonKey(name: 'hukou_province')
  final String? hukouProvince;    // 户籍省份
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'target_cities')
  final List<String> targetCities; // 目标城市列表
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const UserProfile({
    this.id,
    this.education,
    this.degree,
    this.major,
    this.majorCode,
    this.university,
    this.is985 = false,
    this.is211 = false,
    this.workYears = 0,
    this.hasGrassrootsExp = false,
    this.politicalStatus,
    this.certificates = const [],
    this.age,
    this.gender,
    this.hukouProvince,
    this.targetCities = const [],
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  factory UserProfile.fromDb(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      education: map['education'] as String?,
      degree: map['degree'] as String?,
      major: map['major'] as String?,
      majorCode: map['major_code'] as String?,
      university: map['university'] as String?,
      is985: (map['is_985'] as int?) == 1,
      is211: (map['is_211'] as int?) == 1,
      workYears: (map['work_years'] as int?) ?? 0,
      hasGrassrootsExp: (map['has_grassroots_exp'] as int?) == 1,
      politicalStatus: map['political_status'] as String?,
      certificates: map['certificates'] != null
          ? List<String>.from(jsonDecode(map['certificates'] as String))
          : [],
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      hukouProvince: map['hukou_province'] as String?,
      targetCities: map['target_cities'] != null
          ? List<String>.from(jsonDecode(map['target_cities'] as String))
          : [],
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'education': education,
      'degree': degree,
      'major': major,
      'major_code': majorCode,
      'university': university,
      'is_985': is985 ? 1 : 0,
      'is_211': is211 ? 1 : 0,
      'work_years': workYears,
      'has_grassroots_exp': hasGrassrootsExp ? 1 : 0,
      'political_status': politicalStatus,
      'certificates': jsonEncode(certificates),
      'age': age,
      'gender': gender,
      'hukou_province': hukouProvince,
      'target_cities': jsonEncode(targetCities),
    };
  }

  UserProfile copyWith({
    int? id,
    String? education,
    String? degree,
    String? major,
    String? majorCode,
    String? university,
    bool? is985,
    bool? is211,
    int? workYears,
    bool? hasGrassrootsExp,
    String? politicalStatus,
    List<String>? certificates,
    int? age,
    String? gender,
    String? hukouProvince,
    List<String>? targetCities,
  }) {
    return UserProfile(
      id: id ?? this.id,
      education: education ?? this.education,
      degree: degree ?? this.degree,
      major: major ?? this.major,
      majorCode: majorCode ?? this.majorCode,
      university: university ?? this.university,
      is985: is985 ?? this.is985,
      is211: is211 ?? this.is211,
      workYears: workYears ?? this.workYears,
      hasGrassrootsExp: hasGrassrootsExp ?? this.hasGrassrootsExp,
      politicalStatus: politicalStatus ?? this.politicalStatus,
      certificates: certificates ?? this.certificates,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      hukouProvince: hukouProvince ?? this.hukouProvince,
      targetCities: targetCities ?? this.targetCities,
    );
  }

  static List<String> _listFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) return List<String>.from(jsonDecode(value));
    return [];
  }

  static dynamic _listToJson(List<String> value) => value;
}
