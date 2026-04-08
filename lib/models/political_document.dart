/// 政治文件模型
class PoliticalDocument {
  final int? id;
  final String title;
  final String docType;
  final String? publishDate;
  final String summary;
  final String fullText;
  final String? createdAt;

  const PoliticalDocument({
    this.id,
    required this.title,
    required this.docType,
    this.publishDate,
    this.summary = '',
    this.fullText = '',
    this.createdAt,
  });

  /// doc_type 枚举映射
  static const Map<String, String> docTypeLabels = {
    'party_congress': '党代会报告',
    'gov_report': '政府工作报告',
    'plenary': '全会决定',
    'policy': '政策文件',
  };

  String get docTypeLabel => docTypeLabels[docType] ?? docType;

  factory PoliticalDocument.fromDb(Map<String, dynamic> map) {
    return PoliticalDocument(
      id: map['id'] as int?,
      title: map['title'] as String,
      docType: map['doc_type'] as String,
      publishDate: map['publish_date'] as String?,
      summary: (map['summary'] as String?) ?? '',
      fullText: (map['full_text'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'doc_type': docType,
      'publish_date': publishDate,
      'summary': summary,
      'full_text': fullText,
    };
  }

  PoliticalDocument copyWith({
    int? id,
    String? title,
    String? docType,
    String? publishDate,
    String? summary,
    String? fullText,
  }) {
    return PoliticalDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      docType: docType ?? this.docType,
      publishDate: publishDate ?? this.publishDate,
      summary: summary ?? this.summary,
      fullText: fullText ?? this.fullText,
      createdAt: createdAt,
    );
  }
}
