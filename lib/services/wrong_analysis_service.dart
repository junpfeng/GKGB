import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/error_analysis.dart';
import '../models/question.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 错题深度分析服务
/// 只注入 LlmManager，直接用 DatabaseHelper.instance
class WrongAnalysisService extends ChangeNotifier {
  final LlmManager _llm;
  final DatabaseHelper _db = DatabaseHelper.instance;

  WrongAnalysisService(this._llm);

  /// AI 错因分析：streamChat + join + timeout(15s)
  /// 返回 ErrorAnalysis，失败返回 null
  Future<ErrorAnalysis?> analyzeError(
    Question question,
    String userAnswer,
    String correctAnswer,
  ) async {
    if (!_llm.hasProvider) return null;

    final prompt = '''
请分析以下答题错误的原因，并归类为以下5种错因之一：
- blind_spot：知识盲区（完全不知道相关知识点）
- confusion：概念混淆（知道但混淆了相似概念）
- careless：粗心大意（知道正确答案但看错/选错）
- timeout：时间不足（来不及仔细分析）
- trap：陷阱题（题目有迷惑性设置）

题目：${question.content}
选项：${question.options.join('；')}
<user_answer>$userAnswer</user_answer>
正确答案：$correctAnswer
${question.explanation != null ? '解析：${question.explanation}' : ''}

请严格按以下 JSON 格式回复（不要包含其他内容）：
{"error_type": "错因类型", "analysis": "简短分析（50字内）"}''';

    try {
      final messages = [
        const ChatMessage(role: 'system', content: '你是一个考公考编错题分析专家，请用中文回复。'),
        ChatMessage(role: 'user', content: prompt),
      ];

      // streamChat + join + timeout 15s
      final result = await _llm
          .streamChat(messages)
          .join()
          .timeout(const Duration(seconds: 15));

      return _parseAnalysisResult(result);
    } catch (e) {
      debugPrint('错因分析失败: $e');
      return null;
    }
  }

  /// 解析 LLM 返回的 JSON，失败用 regex 降级
  ErrorAnalysis? _parseAnalysisResult(String raw) {
    // 尝试 JSON 解析
    try {
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(raw);
      if (jsonMatch != null) {
        final map = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final errorType = map['error_type'] as String? ?? '';
        final analysis = map['analysis'] as String? ?? '';
        if (_validErrorTypes.contains(errorType)) {
          return ErrorAnalysis(errorType: errorType, analysis: analysis);
        }
      }
    } catch (_) {}

    // regex 降级：尝试从文本中提取错因类型
    for (final type in _validErrorTypes) {
      if (raw.contains(type)) {
        return ErrorAnalysis(errorType: type, analysis: raw.substring(0, raw.length.clamp(0, 100)));
      }
    }

    return null;
  }

  static const _validErrorTypes = ['blind_spot', 'confusion', 'careless', 'timeout', 'trap'];

  /// 错因分布统计
  Future<Map<String, int>> getErrorTypeDistribution({String? subject}) async {
    return await _db.queryErrorTypeDistribution(subject: subject);
  }

  /// 高频错误分类 TOP N
  Future<List<Map<String, dynamic>>> getTopWrongCategories({int limit = 10}) async {
    return await _db.queryTopWrongCategories(limit: limit);
  }

  /// 各分类正确率（知识图谱用，LEFT JOIN）
  Future<List<Map<String, dynamic>>> getCategoryAccuracy() async {
    return await _db.queryCategoryAccuracy();
  }

  /// 近 N 天错题统计摘要
  Future<Map<String, dynamic>> getRecentWrongStats({int days = 7}) async {
    final rows = await _db.queryRecentWrongAnswers(days: days);
    // 按分类统计
    final categoryCount = <String, int>{};
    final errorTypeCount = <String, int>{};
    for (final row in rows) {
      final cat = row['category'] as String? ?? '未知';
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
      final et = row['error_type'] as String? ?? '';
      if (et.isNotEmpty) {
        errorTypeCount[et] = (errorTypeCount[et] ?? 0) + 1;
      }
    }
    return {
      'total': rows.length,
      'by_category': categoryCount,
      'by_error_type': errorTypeCount,
      'details': rows,
    };
  }

  /// AI 诊断报告（流式）
  Stream<String> generateDiagnosisReport() {
    final controller = StreamController<String>();

    () async {
      try {
        if (!_llm.hasProvider) {
          controller.add('未配置 AI 模型，请先在设置中添加。');
          controller.close();
          return;
        }

        // 获取近 7 天错题数据
        final stats = await getRecentWrongStats(days: 7);
        final total = stats['total'] as int;
        if (total == 0) {
          controller.add('近 7 天没有错题记录，继续保持！');
          controller.close();
          return;
        }

        final byCategory = stats['by_category'] as Map<String, int>;
        final byErrorType = stats['by_error_type'] as Map<String, int>;

        // 构建摘要文本
        final categorySummary = byCategory.entries
            .map((e) => '${e.key}: ${e.value}题')
            .join('、');
        final errorTypeSummary = byErrorType.entries
            .map((e) => '${ErrorAnalysis.errorTypeLabels[e.key] ?? e.key}: ${e.value}题')
            .join('、');

        final prompt = '''
请根据以下考公考编学习者近 7 天的错题数据，生成一份简洁的诊断报告（300字内）。

错题总数：$total 题
分类分布：$categorySummary
错因分布：$errorTypeSummary

报告应包含：
1. 薄弱环节分析
2. 主要错因诊断
3. 针对性改进建议（具体可操作）

请用中文回复，使用 Markdown 格式。''';

        final messages = [
          const ChatMessage(role: 'system', content: '你是一个考公考编学习诊断专家。'),
          ChatMessage(role: 'user', content: prompt),
        ];

        await for (final chunk in _llm.streamChat(messages)) {
          controller.add(chunk);
        }
        controller.close();
      } catch (e) {
        controller.add('\n\n诊断报告生成失败: $e');
        controller.close();
      }
    }();

    return controller.stream;
  }

  /// 异步分析并更新错因到 DB
  Future<void> analyzeAndSave(
    Question question,
    String userAnswer,
    String correctAnswer,
  ) async {
    final answerId = await _db.queryLatestWrongAnswerId(question.id!);
    if (answerId == null) return;

    final result = await analyzeError(question, userAnswer, correctAnswer);
    if (result != null && result.errorType.isNotEmpty) {
      await _db.updateAnswerErrorType(answerId, result.errorType);
      notifyListeners();
    }
  }
}
