/// 考点提炼模型
class ExamPoint {
  final int? id;
  final int documentId;
  final String section;
  final String pointText;
  final int importance;
  final int frequency;
  final String? createdAt;

  const ExamPoint({
    this.id,
    required this.documentId,
    this.section = '',
    required this.pointText,
    this.importance = 3,
    this.frequency = 0,
    this.createdAt,
  });

  factory ExamPoint.fromDb(Map<String, dynamic> map) {
    return ExamPoint(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      section: (map['section'] as String?) ?? '',
      pointText: map['point_text'] as String,
      importance: (map['importance'] as int?) ?? 3,
      frequency: (map['frequency'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'section': section,
      'point_text': pointText,
      'importance': importance,
      'frequency': frequency,
    };
  }

  ExamPoint copyWith({
    int? id,
    int? documentId,
    String? section,
    String? pointText,
    int? importance,
    int? frequency,
  }) {
    return ExamPoint(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      section: section ?? this.section,
      pointText: pointText ?? this.pointText,
      importance: importance ?? this.importance,
      frequency: frequency ?? this.frequency,
      createdAt: createdAt,
    );
  }
}
