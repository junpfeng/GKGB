import 'dart:convert';

/// 概念对比辨析模型
class ConceptComparison {
  final int? id;
  final String conceptA;
  final String conceptB;
  final String comparisonJson;
  final int? sourceDocumentId;
  final String? createdAt;

  const ConceptComparison({
    this.id,
    required this.conceptA,
    required this.conceptB,
    required this.comparisonJson,
    this.sourceDocumentId,
    this.createdAt,
  });

  /// 解析 comparison_json 中的维度列表
  List<ComparisonDimension> get dimensions {
    try {
      final map = jsonDecode(comparisonJson) as Map<String, dynamic>;
      final dims = map['dimensions'] as List<dynamic>? ?? [];
      return dims
          .map((d) => ComparisonDimension.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  factory ConceptComparison.fromDb(Map<String, dynamic> map) {
    return ConceptComparison(
      id: map['id'] as int?,
      conceptA: map['concept_a'] as String,
      conceptB: map['concept_b'] as String,
      comparisonJson: map['comparison_json'] as String,
      sourceDocumentId: map['source_document_id'] as int?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'concept_a': conceptA,
      'concept_b': conceptB,
      'comparison_json': comparisonJson,
      'source_document_id': sourceDocumentId,
    };
  }

  ConceptComparison copyWith({
    int? id,
    String? conceptA,
    String? conceptB,
    String? comparisonJson,
    int? sourceDocumentId,
  }) {
    return ConceptComparison(
      id: id ?? this.id,
      conceptA: conceptA ?? this.conceptA,
      conceptB: conceptB ?? this.conceptB,
      comparisonJson: comparisonJson ?? this.comparisonJson,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      createdAt: createdAt,
    );
  }
}

/// 对比维度
class ComparisonDimension {
  final String name;
  final String aDesc;
  final String bDesc;

  const ComparisonDimension({
    required this.name,
    required this.aDesc,
    required this.bDesc,
  });

  factory ComparisonDimension.fromJson(Map<String, dynamic> json) {
    return ComparisonDimension(
      name: (json['name'] as String?) ?? '',
      aDesc: (json['a_desc'] as String?) ?? '',
      bDesc: (json['b_desc'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'a_desc': aDesc,
    'b_desc': bDesc,
  };
}
