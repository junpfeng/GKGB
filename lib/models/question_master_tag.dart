/// 题目与母题类型的关联模型
class QuestionMasterTag {
  final int? id;
  final int questionId;
  final int masterTypeId;
  final int isRoot; // 1=根源母题, 0=变体题
  final String? createdAt;

  const QuestionMasterTag({
    this.id,
    required this.questionId,
    required this.masterTypeId,
    this.isRoot = 0,
    this.createdAt,
  });

  factory QuestionMasterTag.fromDb(Map<String, dynamic> map) {
    return QuestionMasterTag(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      masterTypeId: map['master_type_id'] as int,
      isRoot: (map['is_root'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'question_id': questionId,
      'master_type_id': masterTypeId,
      'is_root': isRoot,
    };
  }

  QuestionMasterTag copyWith({
    int? id,
    int? questionId,
    int? masterTypeId,
    int? isRoot,
    String? createdAt,
  }) {
    return QuestionMasterTag(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      masterTypeId: masterTypeId ?? this.masterTypeId,
      isRoot: isRoot ?? this.isRoot,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
