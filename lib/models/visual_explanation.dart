import 'dart:convert';

/// 可视化解题模型
/// 存储题目的逐步可视化动画配置
class VisualExplanation {
  final int? id;
  final int questionId;
  final String explanationType; // equation_walkthrough
  final String stepsJson; // JSON 数组：逐步可视化配置
  final String templateId; // 可视化模板标识
  final String? createdAt;

  const VisualExplanation({
    this.id,
    required this.questionId,
    required this.explanationType,
    required this.stepsJson,
    this.templateId = '',
    this.createdAt,
  });

  factory VisualExplanation.fromDb(Map<String, dynamic> map) {
    return VisualExplanation(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      explanationType: map['explanation_type'] as String,
      stepsJson: map['steps_json'] as String,
      templateId: (map['template_id'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'question_id': questionId,
      'explanation_type': explanationType,
      'steps_json': stepsJson,
      'template_id': templateId,
    };
  }

  /// 解析 stepsJson 为步骤列表
  List<VisualStep> get steps {
    try {
      final list = jsonDecode(stepsJson) as List<dynamic>;
      return list.map((e) => VisualStep.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

/// 一期支持的 visual_type
class VisualType {
  static const equationSetup = 'equation_setup';
  static const equationSubstitute = 'equation_substitute';
  static const equationSolve = 'equation_solve';
  static const highlightResult = 'highlight_result';

  /// 一期白名单
  static const supportedTypes = {
    equationSetup,
    equationSubstitute,
    equationSolve,
    highlightResult,
  };

  static bool isSupported(String type) => supportedTypes.contains(type);
}

/// 可视化步骤
class VisualStep {
  final int step;
  final String narration;
  final String visualType;
  final Map<String, dynamic> params;
  final String highlight;

  const VisualStep({
    required this.step,
    required this.narration,
    required this.visualType,
    this.params = const {},
    this.highlight = '',
  });

  factory VisualStep.fromJson(Map<String, dynamic> json) {
    return VisualStep(
      step: (json['step'] as num?)?.toInt() ?? 0,
      narration: (json['narration'] as String?) ?? '',
      visualType: (json['visual_type'] as String?) ?? '',
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      highlight: (json['highlight'] as String?) ?? '',
    );
  }
}
