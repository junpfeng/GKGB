import 'dart:convert';

/// 空间可视化配置模型
/// 关联题目的立体拼合/折叠可视化数据
class SpatialVisualization {
  final int? id;
  final int questionId;
  final String vizType; // cube_fold, cube_rotate, cut_section, assembly
  final String configJson; // 可视化配置 JSON
  final String solvingApproach; // 解题思路文字说明
  final String? createdAt;

  const SpatialVisualization({
    this.id,
    required this.questionId,
    required this.vizType,
    required this.configJson,
    this.solvingApproach = '',
    this.createdAt,
  });

  factory SpatialVisualization.fromDb(Map<String, dynamic> map) {
    return SpatialVisualization(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      vizType: map['viz_type'] as String,
      configJson: map['config_json'] as String,
      solvingApproach: (map['solving_approach'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'question_id': questionId,
      'viz_type': vizType,
      'config_json': configJson,
      'solving_approach': solvingApproach,
    };
  }

  /// 解析 config_json 为 Map
  Map<String, dynamic> get config {
    try {
      return jsonDecode(configJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
