import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/political_document.dart';
import '../models/exam_point.dart';
import '../models/mnemonic.dart';
import '../models/concept_comparison.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 政治理论文件解读与口诀记忆服务
class PoliticalTheoryService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llm;

  List<PoliticalDocument> _documents = [];
  List<ExamPoint> _examPoints = [];
  List<Mnemonic> _mnemonics = [];
  List<ConceptComparison> _comparisons = [];
  bool _isLoading = false;

  // 流式生成状态
  String _streamingContent = '';
  bool _isGenerating = false;

  List<PoliticalDocument> get documents => List.unmodifiable(_documents);
  List<ExamPoint> get examPoints => List.unmodifiable(_examPoints);
  List<Mnemonic> get mnemonics => List.unmodifiable(_mnemonics);
  List<ConceptComparison> get comparisons => List.unmodifiable(_comparisons);
  bool get isLoading => _isLoading;
  String get streamingContent => _streamingContent;
  bool get isGenerating => _isGenerating;

  PoliticalTheoryService(this._llm);

  // ===== 预置数据导入（启动时调用，幂等） =====

  Future<void> importPresetData() async {
    final count = await _db.countPoliticalDocuments();
    if (count > 0) {
      debugPrint('政治理论预置数据已存在 ($count 份文件)，跳过导入');
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/political_theory_preset.json',
      );
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 导入文件
      final docs = data['documents'] as List<dynamic>? ?? [];
      for (final doc in docs) {
        final docId = await _db.insertPoliticalDocument({
          'title': doc['title'],
          'doc_type': doc['doc_type'],
          'publish_date': doc['publish_date'] ?? '',
          'summary': doc['summary'] ?? '',
          'full_text': doc['full_text'] ?? '',
        });
        if (docId <= 0) continue;

        // 导入该文件的考点
        final points = doc['exam_points'] as List<dynamic>? ?? [];
        for (final pt in points) {
          final pointId = await _db.insertExamPoint({
            'document_id': docId,
            'section': pt['section'] ?? '',
            'point_text': pt['point_text'],
            'importance': pt['importance'] ?? 3,
            'frequency': pt['frequency'] ?? 0,
          });

          // 导入考点下的口诀
          final mnemonics = pt['mnemonics'] as List<dynamic>? ?? [];
          for (final m in mnemonics) {
            await _db.insertMnemonic({
              'exam_point_id': pointId,
              'document_id': docId,
              'topic': m['topic'],
              'mnemonic_text': m['mnemonic_text'],
              'explanation': m['explanation'] ?? '',
              'style': m['style'] ?? 'rhyme',
              'is_ai_generated': 0,
              'is_favorited': 0,
            });
          }
        }
      }

      // 导入概念对比
      final comps = data['comparisons'] as List<dynamic>? ?? [];
      for (final c in comps) {
        // 按字典序排列 concept_a/concept_b
        final pair = _sortConceptPair(
          c['concept_a'] as String,
          c['concept_b'] as String,
        );
        await _db.insertConceptComparison({
          'concept_a': pair.$1,
          'concept_b': pair.$2,
          'comparison_json': jsonEncode(c['comparison']),
          'source_document_id': c['source_document_id'],
        });
      }

      final finalCount = await _db.countPoliticalDocuments();
      debugPrint('政治理论预置数据导入完成: $finalCount 份文件');
    } catch (e, st) {
      debugPrint('导入政治理论预置数据失败: $e\n$st');
    }
  }

  // ===== 文件管理 =====

  /// 加载文件列表（排除 full_text）
  Future<void> loadDocuments({String? docType}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryPoliticalDocuments(docType: docType);
      _documents = rows.map((r) => PoliticalDocument.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载单个文件详情（含 full_text）
  Future<PoliticalDocument?> loadDocumentDetail(int id) async {
    final row = await _db.queryPoliticalDocumentById(id);
    return row != null ? PoliticalDocument.fromDb(row) : null;
  }

  // ===== 考点管理 =====

  /// 加载指定文件的考点列表
  Future<void> loadExamPoints(int documentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryExamPoints(documentId: documentId);
      _examPoints = rows.map((r) => ExamPoint.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 搜索考点
  Future<List<ExamPoint>> searchExamPoints(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final rows = await _db.searchExamPoints(keyword.trim());
    return rows.map((r) => ExamPoint.fromDb(r)).toList();
  }

  // ===== 口诀生成（流式） =====

  /// AI 生成口诀（streamChat 流式）
  Future<Mnemonic?> generateMnemonic(
    int examPointId, {
    String style = 'rhyme',
    int? documentId,
  }) async {
    _isGenerating = true;
    _streamingContent = '';
    notifyListeners();

    try {
      final pointRow = await _db.queryExamPointById(examPointId);
      if (pointRow == null) throw Exception('考点不存在');
      final point = ExamPoint.fromDb(pointRow);

      // 获取文件标题作为上下文
      String documentTitle = '';
      String section = point.section;
      if (documentId != null || point.documentId > 0) {
        final docRow = await _db.queryPoliticalDocumentById(
          documentId ?? point.documentId,
        );
        if (docRow != null) {
          documentTitle = docRow['title'] as String? ?? '';
        }
      }

      final styleLabel = Mnemonic.styleLabels[style] ?? '顺口溜';
      final messages = [
        ChatMessage(
          role: 'system',
          content: '你是公考政治理论记忆大师，擅长编创意口诀。请为以下考点生成一个$styleLabel。\n'
              '要求：\n'
              '- 越有趣越好，可以用谐音、段子、画面感、甚至"邪门"的联想\n'
              '- 先给出口诀本身（简短好记）\n'
              '- 再逐条解释口诀中每个词对应的考点内容\n\n'
              '输出格式：\n'
              '【口诀】你的口诀内容\n'
              '【解释】逐条映射说明',
        ),
        ChatMessage(
          role: 'user',
          content: '考点：${point.pointText}\n'
              '${documentTitle.isNotEmpty ? '上下文：$documentTitle' : ''}'
              '${section.isNotEmpty ? ' - $section' : ''}',
        ),
      ];

      final buffer = StringBuffer();
      await for (final chunk in _llm.streamChat(messages)) {
        buffer.write(chunk);
        _streamingContent = buffer.toString();
        notifyListeners();
      }

      final fullText = buffer.toString();
      // 解析口诀和解释
      final mnemonicText = _parseMnemonicText(fullText);
      final explanation = _parseExplanation(fullText);

      // INSERT 新记录（"换一个"保留历史）
      final id = await _db.insertMnemonic({
        'exam_point_id': examPointId,
        'document_id': documentId ?? point.documentId,
        'topic': point.pointText.length > 30
            ? '${point.pointText.substring(0, 30)}...'
            : point.pointText,
        'mnemonic_text': mnemonicText,
        'explanation': explanation,
        'style': style,
        'is_ai_generated': 1,
        'is_favorited': 0,
      });

      final mnemonic = Mnemonic(
        id: id,
        examPointId: examPointId,
        documentId: documentId ?? point.documentId,
        topic: point.pointText.length > 30
            ? '${point.pointText.substring(0, 30)}...'
            : point.pointText,
        mnemonicText: mnemonicText,
        explanation: explanation,
        style: style,
        isAiGenerated: true,
      );

      _isGenerating = false;
      _streamingContent = '';
      notifyListeners();
      return mnemonic;
    } catch (e) {
      debugPrint('生成口诀失败: $e');
      _isGenerating = false;
      _streamingContent = '';
      notifyListeners();
      rethrow;
    }
  }

  /// "换一个"：INSERT 新记录保留历史，UI 展示最新
  Future<Mnemonic?> regenerateMnemonic(int examPointId, {String? style}) async {
    return generateMnemonic(
      examPointId,
      style: style ?? 'rhyme',
    );
  }

  // ===== 口诀列表 =====

  /// 加载口诀列表
  Future<void> loadMnemonics({
    int? documentId,
    bool? favoritedOnly,
    String? style,
    int? limit,
    int? offset,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryMnemonics(
        documentId: documentId,
        favoritedOnly: favoritedOnly,
        style: style,
        limit: limit,
        offset: offset,
      );
      final loaded = rows.map((r) => Mnemonic.fromDb(r)).toList();
      if (offset != null && offset > 0) {
        _mnemonics.addAll(loaded);
      } else {
        _mnemonics = loaded;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 查询某考点的最新口诀
  Future<Mnemonic?> getLatestMnemonic(int examPointId) async {
    final row = await _db.queryLatestMnemonic(examPointId: examPointId);
    return row != null ? Mnemonic.fromDb(row) : null;
  }

  /// 切换收藏
  Future<void> toggleFavorite(int mnemonicId) async {
    final idx = _mnemonics.indexWhere((m) => m.id == mnemonicId);
    if (idx < 0) return;

    final current = _mnemonics[idx];
    final newVal = current.isFavorited ? 0 : 1;
    await _db.updateMnemonic(mnemonicId, {'is_favorited': newVal});
    _mnemonics[idx] = current.copyWith(isFavorited: !current.isFavorited);
    notifyListeners();
  }

  // ===== 概念对比 =====

  /// 加载概念对比列表
  Future<void> loadComparisons({int? sourceDocumentId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryConceptComparisons(
        sourceDocumentId: sourceDocumentId,
      );
      _comparisons = rows.map((r) => ConceptComparison.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// AI 生成概念对比（最多重试 2 次 JSON 校验）
  Future<ConceptComparison?> generateComparison(
    String conceptA,
    String conceptB, {
    int? sourceDocumentId,
  }) async {
    _isGenerating = true;
    _streamingContent = '';
    notifyListeners();

    try {
      // 按字典序排列
      final pair = _sortConceptPair(conceptA, conceptB);

      // 检查是否已存在
      final existing = await _db.queryConceptComparisonByPair(pair.$1, pair.$2);
      if (existing != null) {
        _isGenerating = false;
        notifyListeners();
        return ConceptComparison.fromDb(existing);
      }

      final messages = [
        const ChatMessage(
          role: 'system',
          content: '请对比以下两个政治概念，从含义、提出时间、提出场景、核心内容、侧重点等维度进行辨析。\n'
              '输出 JSON 格式：{"dimensions": [{"name": "维度名", "a_desc": "概念A描述", "b_desc": "概念B描述"}]}\n'
              '仅输出 JSON，不要输出其他内容。',
        ),
        ChatMessage(
          role: 'user',
          content: '概念 A：${pair.$1}\n概念 B：${pair.$2}',
        ),
      ];

      String? validJson;
      int retries = 0;
      const maxRetries = 2;

      while (retries <= maxRetries) {
        final buffer = StringBuffer();
        await for (final chunk in _llm.streamChat(messages)) {
          buffer.write(chunk);
          _streamingContent = buffer.toString();
          notifyListeners();
        }

        final rawText = buffer.toString();
        validJson = _validateComparisonJson(rawText);
        if (validJson != null) break;

        retries++;
        if (retries <= maxRetries) {
          debugPrint('概念对比 JSON 校验失败，第 $retries 次重试');
          _streamingContent = '';
          notifyListeners();
        }
      }

      // 校验最终结果
      final jsonToStore = validJson ?? _streamingContent;
      final isValid = validJson != null;

      if (!isValid) {
        // 失败展示原始文本，用简单 JSON 包装
        final fallbackJson = jsonEncode({
          'dimensions': [
            {'name': '原始分析', 'a_desc': jsonToStore, 'b_desc': ''},
          ],
        });

        final id = await _db.insertConceptComparison({
          'concept_a': pair.$1,
          'concept_b': pair.$2,
          'comparison_json': fallbackJson,
          'source_document_id': sourceDocumentId,
        });

        final comparison = ConceptComparison(
          id: id,
          conceptA: pair.$1,
          conceptB: pair.$2,
          comparisonJson: fallbackJson,
          sourceDocumentId: sourceDocumentId,
        );

        _comparisons.insert(0, comparison);
        _isGenerating = false;
        _streamingContent = '';
        notifyListeners();
        return comparison;
      }

      final id = await _db.insertConceptComparison({
        'concept_a': pair.$1,
        'concept_b': pair.$2,
        'comparison_json': validJson,
        'source_document_id': sourceDocumentId,
      });

      final comparison = ConceptComparison(
        id: id,
        conceptA: pair.$1,
        conceptB: pair.$2,
        comparisonJson: validJson,
        sourceDocumentId: sourceDocumentId,
      );

      _comparisons.insert(0, comparison);
      _isGenerating = false;
      _streamingContent = '';
      notifyListeners();
      return comparison;
    } catch (e) {
      debugPrint('生成概念对比失败: $e');
      _isGenerating = false;
      _streamingContent = '';
      notifyListeners();
      rethrow;
    }
  }

  // ===== 关联题目 =====

  /// 查找考点关联的常识判断题目 ID
  Future<List<int>> findRelatedQuestionIds(int examPointId) async {
    return await _db.queryQuestionIdsByExamPoint(examPointId);
  }

  // ===== 内部工具方法 =====

  /// 按字典序排列概念对
  (String, String) _sortConceptPair(String a, String b) {
    return a.compareTo(b) <= 0 ? (a, b) : (b, a);
  }

  /// 解析口诀正文
  String _parseMnemonicText(String fullText) {
    // 匹配【口诀】后的内容
    final regex = RegExp(r'【口诀】\s*(.*?)(?=\n【|$)', dotAll: true);
    final match = regex.firstMatch(fullText);
    if (match != null) {
      return match.group(1)?.trim() ?? fullText;
    }
    // 未匹配时返回全文第一段
    final lines = fullText.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isNotEmpty ? lines.first.trim() : fullText;
  }

  /// 解析口诀解释
  String _parseExplanation(String fullText) {
    final regex = RegExp(r'【解释】\s*(.*)', dotAll: true);
    final match = regex.firstMatch(fullText);
    return match?.group(1)?.trim() ?? '';
  }

  /// 校验概念对比 JSON：dimensions 数组存在且每项有 name/a_desc/b_desc
  String? _validateComparisonJson(String rawText) {
    try {
      // 提取 JSON（可能被 markdown 代码块包裹）
      String jsonStr = rawText.trim();
      final codeBlockMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)```',
      ).firstMatch(jsonStr);
      if (codeBlockMatch != null) {
        jsonStr = codeBlockMatch.group(1)!.trim();
      }

      // 提取第一个 { 到最后一个 }
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace < 0 || lastBrace < 0 || lastBrace <= firstBrace) {
        return null;
      }
      jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final dims = map['dimensions'] as List<dynamic>?;
      if (dims == null || dims.isEmpty) return null;

      for (final d in dims) {
        final dm = d as Map<String, dynamic>;
        if (!dm.containsKey('name') ||
            !dm.containsKey('a_desc') ||
            !dm.containsKey('b_desc')) {
          return null;
        }
      }

      return jsonStr;
    } catch (_) {
      return null;
    }
  }
}
