import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'talent_policy.g.dart';

/// 人才引进公告
@JsonSerializable()
class TalentPolicy {
  final int? id;
  final String title;
  @JsonKey(name: 'source_url')
  final String? sourceUrl;
  final String? province;
  final String? city;
  @JsonKey(name: 'policy_type')
  final String? policyType; // 事业编/国企/高校 等
  @JsonKey(name: 'publish_date')
  final String? publishDate;
  final String? deadline;
  final String? content;  // 原始公告文本
  @JsonKey(fromJson: _listFromJson, toJson: _listToJson, name: 'attachment_urls')
  final List<String> attachmentUrls;
  @JsonKey(name: 'fetched_at')
  final String? fetchedAt;

  const TalentPolicy({
    this.id,
    required this.title,
    this.sourceUrl,
    this.province,
    this.city,
    this.policyType,
    this.publishDate,
    this.deadline,
    this.content,
    this.attachmentUrls = const [],
    this.fetchedAt,
  });

  factory TalentPolicy.fromJson(Map<String, dynamic> json) => _$TalentPolicyFromJson(json);
  Map<String, dynamic> toJson() => _$TalentPolicyToJson(this);

  factory TalentPolicy.fromDb(Map<String, dynamic> map) {
    return TalentPolicy(
      id: map['id'] as int?,
      title: map['title'] as String,
      sourceUrl: map['source_url'] as String?,
      province: map['province'] as String?,
      city: map['city'] as String?,
      policyType: map['policy_type'] as String?,
      publishDate: map['publish_date'] as String?,
      deadline: map['deadline'] as String?,
      content: map['content'] as String?,
      attachmentUrls: map['attachment_urls'] != null && (map['attachment_urls'] as String).isNotEmpty
          ? List<String>.from(jsonDecode(map['attachment_urls'] as String))
          : [],
      fetchedAt: map['fetched_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'source_url': sourceUrl,
      'province': province,
      'city': city,
      'policy_type': policyType,
      'publish_date': publishDate,
      'deadline': deadline,
      'content': content,
      'attachment_urls': jsonEncode(attachmentUrls),
    };
  }

  static List<String> _listFromJson(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) return List<String>.from(jsonDecode(value));
    return [];
  }

  static dynamic _listToJson(List<String> value) => value;
}
