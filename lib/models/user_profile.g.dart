// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: (json['id'] as num?)?.toInt(),
  education: json['education'] as String?,
  degree: json['degree'] as String?,
  major: json['major'] as String?,
  majorCode: json['major_code'] as String?,
  university: json['university'] as String?,
  is985: json['is_985'] as bool? ?? false,
  is211: json['is_211'] as bool? ?? false,
  workYears: (json['work_years'] as num?)?.toInt() ?? 0,
  hasGrassrootsExp: json['has_grassroots_exp'] as bool? ?? false,
  politicalStatus: json['political_status'] as String?,
  certificates: json['certificates'] == null
      ? const []
      : UserProfile._listFromJson(json['certificates']),
  age: (json['age'] as num?)?.toInt(),
  gender: json['gender'] as String?,
  hukouProvince: json['hukou_province'] as String?,
  targetCities: json['target_cities'] == null
      ? const []
      : UserProfile._listFromJson(json['target_cities']),
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'education': instance.education,
      'degree': instance.degree,
      'major': instance.major,
      'major_code': instance.majorCode,
      'university': instance.university,
      'is_985': instance.is985,
      'is_211': instance.is211,
      'work_years': instance.workYears,
      'has_grassroots_exp': instance.hasGrassrootsExp,
      'political_status': instance.politicalStatus,
      'certificates': UserProfile._listToJson(instance.certificates),
      'age': instance.age,
      'gender': instance.gender,
      'hukou_province': instance.hukouProvince,
      'target_cities': UserProfile._listToJson(instance.targetCities),
      'updated_at': instance.updatedAt,
    };
