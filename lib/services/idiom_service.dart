import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../db/database_helper.dart';
import '../models/idiom.dart';
import '../models/idiom_example.dart';
import '../models/question.dart';

/// 成语整理服务
/// 从选词填空题中提取成语，抓取释义和人民日报例句
class IdiomService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Idiom> _idioms = [];
  bool _isLoading = false;
  bool _isCollecting = false;
  double _collectProgress = 0;
  String _collectStatus = '';

  List<Idiom> get idioms => List.unmodifiable(_idioms);
  bool get isLoading => _isLoading;
  bool get isCollecting => _isCollecting;
  double get collectProgress => _collectProgress;
  String get collectStatus => _collectStatus;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
    },
  ));

  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 限速：每次请求间隔 ≥2s（遵守 robots.txt 协议）
  Future<void> _rateLimitWait() async {
    final elapsed = DateTime.now().difference(_lastRequestTime);
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }
    _lastRequestTime = DateTime.now();
  }

  // ===== 一键整理流程 =====

  /// 扫描题库 → 提取成语 → 抓取释义和例句
  Future<void> collectIdioms() async {
    if (_isCollecting) return;
    _isCollecting = true;
    _collectProgress = 0;
    _collectStatus = '正在扫描题库...';
    notifyListeners();

    try {
      // 步骤1：查询所有选词填空题目
      final questions = await _queryXuanCiTianKongQuestions();
      _collectStatus = '找到 ${questions.length} 道选词填空题';
      notifyListeners();

      // 步骤2：提取所有成语 → Map<成语, Set<questionId>>
      final idiomMap = <String, Set<int>>{};
      for (final q in questions) {
        final extracted = _extractIdiomsFromQuestion(q);
        for (final idiom in extracted) {
          idiomMap.putIfAbsent(idiom, () => {});
          if (q.id != null) idiomMap[idiom]!.add(q.id!);
        }
      }
      _collectStatus = '提取到 ${idiomMap.length} 个成语，开始整理...';
      notifyListeners();

      // 步骤3：逐个处理
      int processed = 0;
      final total = idiomMap.length;

      for (final entry in idiomMap.entries) {
        final idiomText = entry.key;
        final questionIds = entry.value;

        _collectProgress = processed / total;
        _collectStatus = '处理中: $idiomText ($processed/$total)';
        notifyListeners();

        // 查找或插入成语
        var existing = await _db.queryIdiomByText(idiomText);
        int idiomId;

        if (existing != null) {
          idiomId = existing['id'] as int;
          // 已有成语，仅补充题目关联
        } else {
          // 抓取释义
          await _rateLimitWait();
          final definition = await _fetchDefinition(idiomText);
          idiomId = await _db.insertIdiom({
            'text': idiomText,
            'definition': definition,
          });
        }

        // 插入题目关联
        for (final qId in questionIds) {
          await _db.insertIdiomQuestionLink(idiomId, qId);
        }

        // 抓取人民日报例句（仅当无例句时）
        final existingCount = await _db.countExamplesByIdiomId(idiomId);
        if (existingCount == 0) {
          await _rateLimitWait();
          final examples = await _scrapePeopleDailyExamples(idiomText);
          for (final ex in examples) {
            await _db.insertIdiomExample({
              'idiom_id': idiomId,
              'sentence': ex.sentence,
              'year': ex.year,
              'source_url': ex.sourceUrl,
            });
          }
        }

        processed++;
      }

      // 步骤4：刷新列表
      await loadIdioms();

      _collectProgress = 1.0;
      _collectStatus = '整理完成！共 $total 个成语';
    } catch (e) {
      _collectStatus = '整理出错: $e';
      debugPrint('成语整理异常: $e');
    } finally {
      _isCollecting = false;
      notifyListeners();
    }
  }

  /// 查询所有选词填空题目
  Future<List<Question>> _queryXuanCiTianKongQuestions() async {
    final db = await _db.database;
    // 言语理解/言语运用类别的题目
    final rows = await db.query(
      'questions',
      where: "category IN ('言语理解', '言语运用')",
      orderBy: 'id ASC',
    );
    // Dart 侧过滤：content 含 ___ 的是选词填空题
    return rows
        .map((r) => Question.fromDb(r))
        .where((q) => q.content.contains('___'))
        .toList();
  }

  /// 从选项中提取四字成语
  List<String> _extractIdiomsFromQuestion(Question question) {
    final idioms = <String>{};
    final fourCharRegex = RegExp(r'^[\u4e00-\u9fff]{4}$');

    for (final option in question.options) {
      // 去掉选项标签 "A. ", "B. " 等
      final text = option.replaceFirst(RegExp(r'^[A-Za-z][.．、]\s*'), '');

      // 按顿号、空格分割（有的选项一个选项含多个词）
      final parts = text.split(RegExp(r'[、\s]+'));
      for (final part in parts) {
        final trimmed = part.trim();
        if (fourCharRegex.hasMatch(trimmed)) {
          idioms.add(trimmed);
        }
      }
    }
    return idioms.toList();
  }

  // ===== 网络抓取 =====

  /// 从百度汉语获取成语释义
  Future<String> _fetchDefinition(String idiom) async {
    try {
      final url = 'https://hanyu.baidu.com/s?wd=${Uri.encodeComponent(idiom)}&ptype=zici';
      final response = await _dio.get(url);
      if (response.statusCode != 200) return '';

      final document = html_parser.parse(response.data);
      // 尝试多种选择器匹配释义区域
      final meaningEl = document.querySelector('#basicmean-wrapper .tab-content')
          ?? document.querySelector('.basicmean-text')
          ?? document.querySelector('#baike-wrapper .tab-content');
      return meaningEl?.text.trim() ?? '';
    } catch (e) {
      debugPrint('获取成语释义失败($idiom): $e');
      return '';
    }
  }

  /// 从人民日报搜索抓取例句（2020-2025 年）
  Future<List<IdiomExample>> _scrapePeopleDailyExamples(String idiom) async {
    final examples = <IdiomExample>[];

    try {
      final url = 'http://search.people.com.cn/cnpeople/search.do'
          '?pageNum=1'
          '&keyword=${Uri.encodeComponent(idiom)}'
          '&siteName=news'
          '&facetFlag=true'
          '&nodeType=belongsId'
          '&nodeId='
          '&beginYear=2020'
          '&endYear=2025';

      final response = await _dio.get(url);
      if (response.statusCode != 200) return examples;

      final document = html_parser.parse(response.data);
      final resultItems = document.querySelectorAll('.search_list li');

      for (final item in resultItems) {
        final summaryEl = item.querySelector('.search_list_c');
        final dateEl = item.querySelector('.search_list_d');
        final linkEl = item.querySelector('a');

        if (summaryEl == null) continue;

        final summary = summaryEl.text.trim();
        final dateText = dateEl?.text.trim() ?? '';
        final link = linkEl?.attributes['href'] ?? '';

        // 提取包含成语的句子
        final sentence = _extractSentenceContaining(summary, idiom);
        if (sentence.isEmpty) continue;

        // 解析年份
        final yearMatch = RegExp(r'(\d{4})').firstMatch(dateText);
        final year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 0;

        if (year >= 2020 && year <= 2025) {
          examples.add(IdiomExample(
            idiomId: 0, // 插入时由调用方设置
            sentence: sentence,
            year: year,
            sourceUrl: link,
          ));
        }
      }
    } catch (e) {
      debugPrint('抓取人民日报例句失败($idiom): $e');
    }

    // 按年份降序排序，最多保留 5 条
    examples.sort((a, b) => b.year.compareTo(a.year));
    return examples.take(5).toList();
  }

  /// 从摘要文本中提取包含成语的完整句子
  String _extractSentenceContaining(String text, String keyword) {
    if (!text.contains(keyword)) return '';

    // 按句号、问号、叹号分割句子
    final sentences = text.split(RegExp(r'[。！？!?]'));
    for (final s in sentences) {
      if (s.contains(keyword) && s.trim().length >= 10) {
        return '${s.trim()}。';
      }
    }
    // 未找到合适句子时返回整段摘要（截断到合理长度）
    final idx = text.indexOf(keyword);
    final start = (idx - 40).clamp(0, text.length);
    final end = (idx + keyword.length + 40).clamp(0, text.length);
    return text.substring(start, end).trim();
  }

  // ===== 查询方法 =====

  /// 加载成语列表
  Future<void> loadIdioms({int? limit, int? offset}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryAllIdioms(limit: limit, offset: offset);
      _idioms = rows.map((r) => Idiom.fromDb(r)).toList();
    } catch (e) {
      debugPrint('加载成语列表失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 根据题目 ID 查询关联的成语
  Future<List<Idiom>> getIdiomsForQuestion(int questionId) async {
    final rows = await _db.queryIdiomsByQuestionId(questionId);
    return rows.map((r) => Idiom.fromDb(r)).toList();
  }

  /// 根据成语 ID 查询例句
  Future<List<IdiomExample>> getExamples(int idiomId) async {
    final rows = await _db.queryExamplesByIdiomId(idiomId);
    return rows.map((r) => IdiomExample.fromDb(r)).toList();
  }

  /// 成语总数
  Future<int> countIdioms() async {
    return await _db.countIdioms();
  }
}
