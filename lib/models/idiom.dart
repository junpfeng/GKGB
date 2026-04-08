/// 成语数据模型
class Idiom {
  final int? id;
  final String text; // 成语文字，如 "厚此薄彼"
  final String definition; // 释义
  final String? createdAt;

  const Idiom({
    this.id,
    required this.text,
    this.definition = '',
    this.createdAt,
  });

  factory Idiom.fromDb(Map<String, dynamic> map) {
    return Idiom(
      id: map['id'] as int?,
      text: map['text'] as String,
      definition: (map['definition'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'text': text,
      'definition': definition,
    };
  }
}
