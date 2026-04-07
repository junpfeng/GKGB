// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'talent_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TalentPolicy _$TalentPolicyFromJson(Map<String, dynamic> json) => TalentPolicy(
  id: (json['id'] as num?)?.toInt(),
  title: json['title'] as String,
  sourceUrl: json['source_url'] as String?,
  province: json['province'] as String?,
  city: json['city'] as String?,
  policyType: json['policy_type'] as String?,
  publishDate: json['publish_date'] as String?,
  deadline: json['deadline'] as String?,
  content: json['content'] as String?,
  attachmentUrls: json['attachment_urls'] == null
      ? const []
      : TalentPolicy._listFromJson(json['attachment_urls']),
  fetchedAt: json['fetched_at'] as String?,
);

Map<String, dynamic> _$TalentPolicyToJson(TalentPolicy instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'source_url': instance.sourceUrl,
      'province': instance.province,
      'city': instance.city,
      'policy_type': instance.policyType,
      'publish_date': instance.publishDate,
      'deadline': instance.deadline,
      'content': instance.content,
      'attachment_urls': TalentPolicy._listToJson(instance.attachmentUrls),
      'fetched_at': instance.fetchedAt,
    };
