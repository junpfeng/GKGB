import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/database_helper.dart';
import '../models/idiom.dart';
import '../models/idiom_example.dart';
import '../models/question.dart';

/// 成语整理服务
/// 从预置 JSON 导入成语数据，动态关联选词填空题目
class IdiomService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Idiom> _idioms = [];
  bool _isLoading = false;

  List<Idiom> get idioms => List.unmodifiable(_idioms);
  bool get isLoading => _isLoading;

  // ===== 预置数据导入（启动时调用，幂等） =====

  /// 导入预置成语数据 + 动态建立题目关联
  Future<void> importPresetIdioms() async {
    final db = await _db.database;

    // 检查数据完整性：成语和例句都有才跳过
    final idiomCount = await _db.countIdioms();
    final exResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM idiom_examples');
    final exCount = (exResult.first['cnt'] as int?) ?? 0;

    if (idiomCount > 0 && exCount > 0) {
      debugPrint('成语预置数据已完整 (成语=$idiomCount, 例句=$exCount)，跳过导入');
      return;
    }

    // 清除不完整的旧数据，重新导入
    if (idiomCount > 0) {
      debugPrint('成语数据不完整 (成语=$idiomCount, 例句=$exCount)，清除重新导入');
      await db.delete('idiom_question_links');
      await db.delete('idiom_examples');
      await db.delete('idioms');
      // 重置 autoincrement 计数器
      await db.delete('sqlite_sequence',
          where: "name IN ('idioms', 'idiom_examples', 'idiom_question_links')");
    }

    try {
      // 1. 从 assets 加载预置 JSON
      final jsonStr = await rootBundle.loadString('assets/data/idioms_preset.json');
      final List<dynamic> items = jsonDecode(jsonStr);
      debugPrint('加载预置成语 JSON: ${items.length} 条');

      if (items.isEmpty) {
        debugPrint('预置成语 JSON 为空，跳过导入');
        return;
      }

      for (final item in items) {
        final text = item['text'] as String? ?? '';
        if (text.isEmpty) continue;

        // 插入成语（用 replace 确保更新）
        final idiomId = await db.insert('idioms', {
          'text': text,
          'definition': item['definition'] ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (idiomId <= 0) {
          debugPrint('插入成语失败: $text, id=$idiomId');
          continue;
        }

        // 插入例句
        final examples = item['examples'] as List<dynamic>? ?? [];
        for (final ex in examples) {
          await db.insert('idiom_examples', {
            'idiom_id': idiomId,
            'sentence': ex['sentence'] ?? '',
            'year': ex['year'] ?? 0,
            'source_url': ex['source_url'] ?? '',
          });
        }
      }

      // 2. 动态建立成语与题目的关联
      await _buildQuestionLinks();

      final finalCount = await _db.countIdioms();
      final finalEx = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM idiom_examples');
      debugPrint('成语导入完成: 成语=$finalCount, 例句=${finalEx.first['cnt']}');
    } catch (e, st) {
      debugPrint('导入预置成语数据失败: $e\n$st');
    }
  }

  /// 扫描选词填空题，建立成语-题目关联
  Future<void> _buildQuestionLinks() async {
    final db = await _db.database;
    final fourCharRegex = RegExp(r'^[\u4e00-\u9fff]{4}$');

    // 查询所有言语理解/言语运用题目
    final rows = await db.query(
      'questions',
      where: "category IN ('言语理解', '言语运用')",
    );

    for (final row in rows) {
      final q = Question.fromDb(row);
      if (!q.content.contains('___') || q.id == null) continue;

      // 从选项中提取四字词
      for (final option in q.options) {
        final text = option.replaceFirst(RegExp(r'^[A-Za-z][.．、]\s*'), '');
        final parts = text.split(RegExp(r'[、\s]+'));
        for (final part in parts) {
          final trimmed = part.trim();
          if (!fourCharRegex.hasMatch(trimmed)) continue;

          // 查找已导入的成语
          final idiomRow = await _db.queryIdiomByText(trimmed);
          if (idiomRow != null) {
            await _db.insertIdiomQuestionLink(idiomRow['id'] as int, q.id!);
          }
        }
      }
    }
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
