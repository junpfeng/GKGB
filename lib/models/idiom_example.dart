/// 成语例句数据模型（来源：人民日报）
class IdiomExample {
  final int? id;
  final int idiomId; // 关联的成语 ID
  final String sentence; // 包含成语的原句
  final int year; // 发表年份
  final String sourceUrl; // 原文链接

  const IdiomExample({
    this.id,
    required this.idiomId,
    required this.sentence,
    required this.year,
    this.sourceUrl = '',
  });

  factory IdiomExample.fromDb(Map<String, dynamic> map) {
    return IdiomExample(
      id: map['id'] as int?,
      idiomId: map['idiom_id'] as int,
      sentence: map['sentence'] as String,
      year: map['year'] as int,
      sourceUrl: (map['source_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'idiom_id': idiomId,
      'sentence': sentence,
      'year': year,
      'source_url': sourceUrl,
    };
  }
}
