/// 口诀/记忆法模型
class Mnemonic {
  final int? id;
  final int? examPointId;
  final int? documentId;
  final String topic;
  final String mnemonicText;
  final String explanation;
  final String style;
  final bool isAiGenerated;
  final bool isFavorited;
  final String? createdAt;

  const Mnemonic({
    this.id,
    this.examPointId,
    this.documentId,
    required this.topic,
    required this.mnemonicText,
    this.explanation = '',
    this.style = 'rhyme',
    this.isAiGenerated = true,
    this.isFavorited = false,
    this.createdAt,
  });

  /// style 枚举映射
  static const Map<String, String> styleLabels = {
    'rhyme': '顺口溜',
    'acronym': '首字缩写',
    'story': '故事联想',
    'homophone': '谐音梗',
  };

  static const List<String> styleValues = ['rhyme', 'acronym', 'story', 'homophone'];

  String get styleLabel => styleLabels[style] ?? style;

  factory Mnemonic.fromDb(Map<String, dynamic> map) {
    return Mnemonic(
      id: map['id'] as int?,
      examPointId: map['exam_point_id'] as int?,
      documentId: map['document_id'] as int?,
      topic: map['topic'] as String,
      mnemonicText: map['mnemonic_text'] as String,
      explanation: (map['explanation'] as String?) ?? '',
      style: (map['style'] as String?) ?? 'rhyme',
      isAiGenerated: (map['is_ai_generated'] as int?) == 1,
      isFavorited: (map['is_favorited'] as int?) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'exam_point_id': examPointId,
      'document_id': documentId,
      'topic': topic,
      'mnemonic_text': mnemonicText,
      'explanation': explanation,
      'style': style,
      'is_ai_generated': isAiGenerated ? 1 : 0,
      'is_favorited': isFavorited ? 1 : 0,
    };
  }

  Mnemonic copyWith({
    int? id,
    int? examPointId,
    int? documentId,
    String? topic,
    String? mnemonicText,
    String? explanation,
    String? style,
    bool? isAiGenerated,
    bool? isFavorited,
  }) {
    return Mnemonic(
      id: id ?? this.id,
      examPointId: examPointId ?? this.examPointId,
      documentId: documentId ?? this.documentId,
      topic: topic ?? this.topic,
      mnemonicText: mnemonicText ?? this.mnemonicText,
      explanation: explanation ?? this.explanation,
      style: style ?? this.style,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isFavorited: isFavorited ?? this.isFavorited,
      createdAt: createdAt,
    );
  }
}
