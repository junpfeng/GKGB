import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/hot_topic.dart';
import '../models/essay_material.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 时政热点 + 素材管理服务
class HotTopicService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llm;

  List<HotTopic> _topics = [];
  List<EssayMaterial> _materials = [];
  List<EssayMaterial> _favoriteMaterials = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;

  List<HotTopic> get topics => List.unmodifiable(_topics);
  List<EssayMaterial> get materials => List.unmodifiable(_materials);
  List<EssayMaterial> get favoriteMaterials =>
      List.unmodifiable(_favoriteMaterials);
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;

  HotTopicService(this._llm);

  /// 6 大主题
  static const List<String> themes = [
    '经济发展',
    '社会治理',
    '生态环保',
    '文化教育',
    '科技创新',
    '乡村振兴',
  ];

  /// 4 种素材类型
  static const List<String> materialTypes = [
    '名言金句',
    '典型案例',
    '政策表述',
    '数据支撑',
  ];

  /// 热点分类（同 themes）
  static const List<String> categories = [
    '经济发展',
    '社会治理',
    '生态环保',
    '文化教育',
    '科技创新',
    '乡村振兴',
  ];

  // ===== 热点管理 =====

  /// 加载热点列表（分页）
  Future<void> loadTopics({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryHotTopics(
        category: category,
        limit: limit,
        offset: offset,
      );
      final loaded = rows.map((r) => HotTopic.fromDb(r)).toList();
      if (offset == 0) {
        _topics = loaded;
      } else {
        _topics.addAll(loaded);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 手动添加热点，AI 自动生成摘要/考点/申论角度
  Future<HotTopic?> addTopic(String title, String content) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 先插入基础数据
      final topicData = <String, dynamic>{
        'title': title,
        'summary': content,
        'publish_date': DateTime.now().toIso8601String().substring(0, 10),
      };

      // AI 生成摘要/考点/角度（chat + 30s 超时 + 容错）
      try {
        final messages = [
          const ChatMessage(
            role: 'system',
            content: '你是公务员考试辅导专家。请分析以下时政热点，返回 JSON 格式：\n'
                '{"summary":"100字内摘要","exam_points":"考试考点分析(200字内)","essay_angles":"申论可用角度(200字内)","category":"分类(经济发展/社会治理/生态环保/文化教育/科技创新/乡村振兴)","relevance_score":1-10考试关联度}\n'
                '仅输出 JSON，不要输出其他内容。',
          ),
          ChatMessage(
            role: 'user',
            content: '标题：$title\n内容：$content',
          ),
        ];

        final response = await _llm
            .chat(messages)
            .timeout(const Duration(seconds: 30));

        final parsed = _parseAiResponse(response);
        topicData.addAll(parsed);
      } catch (e) {
        debugPrint('AI 生成热点分析失败: $e');
        // 容错：仅保存基础数据
      }

      final id = await _db.insertHotTopic(topicData);
      final row = await _db.queryHotTopicById(id);
      if (row != null) {
        final topic = HotTopic.fromDb(row);
        _topics.insert(0, topic);
        notifyListeners();
        return topic;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  /// AI 流式考点分析
  Stream<String> aiAnalyzeTopic(int topicId) {
    final controller = StreamController<String>();

    Future(() async {
      _isAnalyzing = true;
      notifyListeners();

      try {
        final row = await _db.queryHotTopicById(topicId);
        if (row == null) {
          controller.addError(Exception('热点不存在'));
          controller.close();
          return;
        }
        final topic = HotTopic.fromDb(row);

        final messages = [
          const ChatMessage(
            role: 'system',
            content: '你是公务员考试辅导专家。请对以下时政热点进行深度考点分析，包括：\n'
                '1. 核心考点梳理\n'
                '2. 可能出题方向（选择题/申论/面试）\n'
                '3. 申论写作可用角度和论据\n'
                '4. 关联历年真题考点\n'
                '使用 markdown 格式，500 字以内。',
          ),
          ChatMessage(
            role: 'user',
            content: '标题：${topic.title}\n摘要：${topic.summary}\n'
                '已有考点：${topic.examPoints}',
          ),
        ];

        final analysisBuffer = StringBuffer();
        await for (final chunk in _llm.streamChat(messages)) {
          analysisBuffer.write(chunk);
          controller.add(chunk);
        }

        // 更新到数据库
        await _db.updateHotTopic(topicId, {
          'exam_points': analysisBuffer.toString(),
        });

        final idx = _topics.indexWhere((t) => t.id == topicId);
        if (idx >= 0) {
          _topics[idx] = _topics[idx].copyWith(
            examPoints: analysisBuffer.toString(),
          );
        }

        _isAnalyzing = false;
        notifyListeners();
        controller.close();
      } catch (e) {
        _isAnalyzing = false;
        notifyListeners();
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 删除热点
  Future<void> deleteTopic(int id) async {
    await _db.deleteHotTopic(id);
    _topics.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ===== 素材管理 =====

  /// 加载素材列表（分页）
  Future<void> loadMaterials({
    String? theme,
    String? materialType,
    int limit = 50,
    int offset = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryEssayMaterials(
        theme: theme,
        materialType: materialType,
        limit: limit,
        offset: offset,
      );
      final loaded = rows.map((r) => EssayMaterial.fromDb(r)).toList();
      if (offset == 0) {
        _materials = loaded;
      } else {
        _materials.addAll(loaded);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 切换收藏
  Future<void> toggleMaterialFavorite(int id) async {
    final idx = _materials.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final current = _materials[idx];
    final newVal = current.favorited ? 0 : 1;
    await _db.updateEssayMaterial(id, {'is_favorited': newVal});
    _materials[idx] = current.copyWith(isFavorited: newVal);
    notifyListeners();
  }

  /// 加载收藏素材
  Future<void> loadFavoriteMaterials() async {
    final rows = await _db.queryFavoriteMaterials();
    _favoriteMaterials = rows.map((r) => EssayMaterial.fromDb(r)).toList();
    notifyListeners();
  }

  // ===== 预置数据导入 =====

  /// 幂等导入预置热点数据
  Future<void> importPresetTopics() async {
    final count = await _db.countHotTopics();
    if (count > 0) return;

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/hot_topics_sample.json',
      );
      final List<dynamic> items = jsonDecode(jsonStr);
      for (final item in items) {
        await _db.insertHotTopic({
          'title': item['title'],
          'summary': item['summary'] ?? '',
          'source': item['source'] ?? '',
          'source_url': item['source_url'] ?? '',
          'publish_date': item['publish_date'],
          'relevance_score': item['relevance_score'] ?? 5,
          'exam_points': item['exam_points'] ?? '',
          'essay_angles': item['essay_angles'] ?? '',
          'category': item['category'] ?? '',
        });
      }
    } catch (e) {
      debugPrint('导入预置热点数据失败: $e');
    }
  }

  /// 幂等导入预置素材数据
  Future<void> importPresetMaterials() async {
    final count = await _db.countEssayMaterials();
    if (count > 0) return;

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/essay_materials_sample.json',
      );
      final List<dynamic> items = jsonDecode(jsonStr);
      for (final item in items) {
        await _db.insertEssayMaterial({
          'theme': item['theme'],
          'material_type': item['material_type'],
          'content': item['content'],
          'source': item['source'] ?? '',
        });
      }
    } catch (e) {
      debugPrint('导入预置素材数据失败: $e');
    }
  }

  // ===== 工具方法 =====

  Map<String, dynamic> _parseAiResponse(String response) {
    final result = <String, dynamic>{};
    try {
      var jsonStr = response;
      final jsonMatch = RegExp(r'\{[^}]+\}', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (json.containsKey('summary')) result['summary'] = json['summary'];
      if (json.containsKey('exam_points')) {
        result['exam_points'] = json['exam_points'];
      }
      if (json.containsKey('essay_angles')) {
        result['essay_angles'] = json['essay_angles'];
      }
      if (json.containsKey('category')) result['category'] = json['category'];
      if (json.containsKey('relevance_score')) {
        result['relevance_score'] =
            (json['relevance_score'] as num).toInt().clamp(1, 10);
      }
    } catch (_) {
      debugPrint('AI 返回 JSON 解析失败');
    }
    return result;
  }
}
