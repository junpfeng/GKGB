import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/question.dart';
import '../models/real_exam_paper.dart';
import 'question_service.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 真题服务：试卷管理、真题模考、用户贡献（AI 结构化）
class RealExamService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final QuestionService _questionService;
  final LlmManager _llmManager;

  List<RealExamPaper> _papers = [];
  bool _isLoading = false;
  bool _sampleImported = false;

  List<RealExamPaper> get papers => List.unmodifiable(_papers);
  bool get isLoading => _isLoading;

  RealExamService(this._questionService, this._llmManager);

  /// 加载试卷列表（支持筛选）
  Future<List<RealExamPaper>> loadPapers({
    String? examType,
    String? region,
    int? year,
    String? subject,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await ensureSampleData();
      final rows = await _db.queryRealExamPapers(
        examType: examType,
        region: region,
        year: year,
        subject: subject,
      );
      _papers = rows.map((r) => RealExamPaper.fromDb(r)).toList();
      return _papers;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 根据 ID 获取试卷
  Future<RealExamPaper?> getPaperById(int id) async {
    final row = await _db.queryRealExamPaperById(id);
    return row != null ? RealExamPaper.fromDb(row) : null;
  }

  /// 加载试卷内的题目（按原始题序）
  Future<List<Question>> loadPaperQuestions(int paperId) async {
    final paper = await getPaperById(paperId);
    if (paper == null) return [];

    final questions = <Question>[];
    for (final qId in paper.questionIds) {
      final row = await _db.queryQuestionById(qId);
      if (row != null) {
        questions.add(Question.fromDb(row));
      }
    }
    return questions;
  }

  /// 用户贡献真题：LLM 结构化解析，返回流式 Stream
  Stream<String> contributeQuestion(String rawText) {
    const prompt = '''
你是一名专业的公务员考试题目整理专家。请将以下原始文本解析为结构化的题目 JSON 数组。

输出要求：
- 返回一个 JSON 数组，每个元素包含以下字段：
  - subject: 科目（"行测"/"申论"/"公基"）
  - category: 分类（如"言语理解"、"数量关系"、"判断推理"、"资料分析"、"常识判断"、"申论"、"公共基础知识"）
  - type: 题型（"single"/"multiple"/"judge"/"subjective"）
  - content: 题目内容
  - options: 选项数组（如 ["A. xxx", "B. xxx", "C. xxx", "D. xxx"]，主观题为空数组）
  - answer: 正确答案（如 "B"、"ABD"、"正确"）
  - explanation: 解析说明
  - difficulty: 难度（1-5）

- 如果无法识别某些字段，给出合理的默认值
- 仅输出 JSON，不要输出其他内容

原始文本：
''';

    return _llmManager.streamChat([
      ChatMessage(role: 'system', content: prompt),
      ChatMessage(role: 'user', content: rawText),
    ]);
  }

  /// 确认贡献：将 AI 解析的题目入库
  Future<int> confirmContribution(Question question) async {
    final dbMap = question.toDb();
    // 确保标记为真题
    dbMap['is_real_exam'] = 1;
    return await _db.insertQuestion(dbMap);
  }

  // ===== 示例真题数据导入 =====

  /// 确保示例真题数据已导入
  Future<void> ensureSampleData() async {
    if (_sampleImported) return;
    // 确保普通题库也已导入
    await _questionService.ensureSampleData();
    final count = await _db.countRealExamQuestions();
    if (count > 0) {
      _sampleImported = true;
      return;
    }
    await _importSampleData();
    _sampleImported = true;
  }

  Future<void> _importSampleData() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/questions/real_exam_sample.json',
      );
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 导入题目
      final questions = data['questions'] as List<dynamic>? ?? [];
      final idMapping = <int, int>{}; // 原始序号 → 实际 DB ID

      for (var i = 0; i < questions.length; i++) {
        final q = questions[i] as Map<String, dynamic>;
        final dbMap = {
          'subject': q['subject'] as String,
          'category': q['category'] as String,
          'type': q['type'] as String? ?? 'single',
          'content': q['content'] as String,
          'options': jsonEncode(q['options'] ?? []),
          'answer': q['answer'] as String,
          'explanation': q['explanation'] as String?,
          'difficulty': (q['difficulty'] as int?) ?? 3,
          'region': q['region'] as String? ?? '',
          'year': (q['year'] as int?) ?? 0,
          'exam_type': q['exam_type'] as String? ?? '',
          'exam_session': q['exam_session'] as String? ?? '',
          'is_real_exam': 1,
        };
        final id = await _db.insertQuestion(dbMap);
        idMapping[i + 1] = id; // 序号从 1 开始
      }

      // 导入试卷
      final papers = data['papers'] as List<dynamic>? ?? [];
      for (final p in papers) {
        final paperMap = p as Map<String, dynamic>;
        // 将原始 question_ids 映射为实际 DB ID
        final originalIds = List<int>.from(paperMap['question_ids'] as List);
        final actualIds = originalIds
            .map((oid) => idMapping[oid])
            .where((id) => id != null)
            .cast<int>()
            .toList();

        final dbMap = {
          'name': paperMap['name'] as String,
          'region': paperMap['region'] as String,
          'year': paperMap['year'] as int,
          'exam_type': paperMap['exam_type'] as String,
          'exam_session': (paperMap['exam_session'] as String?) ?? '',
          'subject': paperMap['subject'] as String,
          'time_limit': paperMap['time_limit'] as int,
          'total_score': (paperMap['total_score'] as num?)?.toDouble() ?? 100,
          'question_ids': jsonEncode(actualIds),
        };
        await _db.insertRealExamPaper(dbMap);
      }
    } catch (e) {
      debugPrint('导入示例真题失败: $e');
    }
  }
}
