import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/database_helper.dart';
import '../models/visual_explanation.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 可视化解题服务
/// 管理数量关系题目的逐步可视化动画数据，支持 AI 生成 + 预置数据导入
class VisualExplanationService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llm;

  /// 内存缓存：已有可视化数据的 questionId 集合
  final Set<int> _cachedQuestionIds = {};

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  VisualExplanationService(this._llm);

  // ===== 查询方法 =====

  /// 同步判断某题是否有可视化数据（纯内存查询）
  bool hasExplanation(int questionId) {
    return _cachedQuestionIds.contains(questionId);
  }

  /// 从 DB 获取可视化解题数据
  Future<VisualExplanation?> getExplanation(int questionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'visual_explanations',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VisualExplanation.fromDb(rows.first);
  }

  // ===== AI 生成 =====

  /// AI 生成可视化解题数据
  /// 使用 streamChat 收集完整 JSON 后解析，超时 30s
  Future<VisualExplanation> generateExplanation(
    int questionId, {
    required String questionContent,
    required String questionAnswer,
    String? questionExplanation,
  }) async {
    if (!_llm.hasProvider) {
      throw Exception('未配置 AI 模型，请在设置中添加');
    }

    _isGenerating = true;
    notifyListeners();

    try {
      final prompt = _buildPrompt(
        questionContent: questionContent,
        questionAnswer: questionAnswer,
        questionExplanation: questionExplanation,
      );

      final messages = [
        const ChatMessage(
          role: 'system',
          content: '你是一个数学可视化解题专家。你的任务是将数学题目的解题过程拆解为逐步可视化动画步骤。'
              '请严格按要求的 JSON 格式输出，不要包含 markdown 代码块标记。',
        ),
        ChatMessage(role: 'user', content: prompt),
      ];

      // streamChat + join + timeout 30s
      final result = await _llm
          .streamChat(messages)
          .join()
          .timeout(const Duration(seconds: 30));

      // 解析并校验
      final stepsJson = _parseAndValidate(result);

      // 存入 DB
      final explanation = VisualExplanation(
        questionId: questionId,
        explanationType: 'equation_walkthrough',
        stepsJson: stepsJson,
        templateId: 'equation',
      );

      final db = await _db.database;
      await db.insert(
        'visual_explanations',
        explanation.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 更新内存缓存
      _cachedQuestionIds.add(questionId);
      _isGenerating = false;
      notifyListeners();

      return explanation;
    } catch (e) {
      _isGenerating = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 构建 LLM prompt
  String _buildPrompt({
    required String questionContent,
    required String questionAnswer,
    String? questionExplanation,
  }) {
    return '''请将以下数量关系题的解题过程拆解为 3-8 个可视化步骤。

【题目】
$questionContent

【正确答案】
$questionAnswer

${questionExplanation != null && questionExplanation.isNotEmpty ? '【解析参考】\n$questionExplanation\n' : ''}
【输出格式要求】
返回一个纯 JSON 数组（不要用 ```json 包裹），每个步骤格式：
{
  "step": 步骤序号(从1开始),
  "narration": "简短说明文字(不超过20字)",
  "visual_type": "类型",
  "params": {参数对象},
  "highlight": "高亮标识(可为空字符串)"
}

【visual_type 枚举及 params 格式】
1. "equation_setup" — 列方程/设未知数
   params: {"equations": ["方程1", "方程2"]}
   highlight: "variable_intro" 或 ""

2. "equation_substitute" — 代入消元
   params: {"from": "代入的表达式", "into": "被代入的方程", "result": "化简结果"}
   highlight: "" 或 "substitution"

3. "equation_solve" — 求解
   params: {"result": "求解结果", "meaning": "结果的含义说明"}
   highlight: "" 或 "solution"

4. "highlight_result" — 最终结果高亮
   params: {"answer": "最终答案", "summary": "一句话总结"}
   highlight: "final_answer"

【注意事项】
- 步骤数 3-8 步
- narration 用中文，简洁易懂
- 数学运算符用 +, -, *, /, = 表示
- 分数用 a/b 格式
- 确保逻辑连贯，从设未知数到最终答案''';
  }

  /// 解析 AI 返回内容并校验格式
  String _parseAndValidate(String raw) {
    // 去除可能的 markdown 代码块包裹
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }

    // 尝试提取 JSON 数组
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
    if (arrayMatch == null) {
      throw FormatException('AI 返回内容不包含有效 JSON 数组');
    }

    final jsonStr = arrayMatch.group(0)!;
    final List<dynamic> steps;
    try {
      steps = jsonDecode(jsonStr) as List<dynamic>;
    } catch (e) {
      throw FormatException('JSON 解析失败: $e');
    }

    if (steps.isEmpty || steps.length > 10) {
      throw FormatException('步骤数量不合法: ${steps.length}');
    }

    // 校验每步必需字段 + visual_type 白名单过滤
    for (final step in steps) {
      if (step is! Map<String, dynamic>) {
        throw const FormatException('步骤格式错误');
      }
      if (step['step'] == null || step['narration'] == null || step['visual_type'] == null) {
        throw const FormatException('步骤缺少必需字段 (step/narration/visual_type)');
      }
      // 非一期支持的 visual_type 降级为 equation_setup（不崩溃）
      final vt = step['visual_type'] as String;
      if (!VisualType.isSupported(vt)) {
        step['visual_type'] = VisualType.equationSetup;
      }
    }

    return jsonEncode(steps);
  }

  // ===== 预置数据导入 =====

  /// 导入预置可视化数据（启动时调用，幂等）
  Future<void> importPresetData() async {
    final db = await _db.database;

    // 幂等检查
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM visual_explanations');
    final count = (result.first['cnt'] as int?) ?? 0;
    if (count > 0) {
      debugPrint('可视化解题预置数据已存在 ($count 条)，跳过导入');
      // 填充缓存
      await _loadCachedIds(db);
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString(
          'assets/data/visual_explanations.json');
      final List<dynamic> items = jsonDecode(jsonStr);
      debugPrint('加载预置可视化解题 JSON: ${items.length} 条');

      if (items.isEmpty) {
        await _loadCachedIds(db);
        return;
      }

      final batch = db.batch();
      for (final item in items) {
        final questionId = item['question_id'] as int?;
        if (questionId == null) continue;

        batch.insert('visual_explanations', {
          'question_id': questionId,
          'explanation_type': item['explanation_type'] ?? 'equation_walkthrough',
          'steps_json': item['steps_json'] is String
              ? item['steps_json']
              : jsonEncode(item['steps_json']),
          'template_id': item['template_id'] ?? 'equation',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);

      final finalResult = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM visual_explanations');
      debugPrint('可视化解题导入完成: ${finalResult.first['cnt']} 条');
    } catch (e, st) {
      debugPrint('导入预置可视化解题数据失败: $e\n$st');
    }

    // 填充缓存
    await _loadCachedIds(db);
  }

  /// 一次性填充内存缓存
  Future<void> _loadCachedIds(Database db) async {
    final rows = await db.rawQuery(
        'SELECT question_id FROM visual_explanations');
    _cachedQuestionIds.clear();
    for (final row in rows) {
      final qid = row['question_id'] as int?;
      if (qid != null) _cachedQuestionIds.add(qid);
    }
    debugPrint('可视化解题缓存已加载: ${_cachedQuestionIds.length} 条');
  }
}
