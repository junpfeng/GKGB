import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/database_helper.dart';
import '../models/master_question_type.dart';
import '../models/question.dart';

/// 母题标签服务：管理母题类型和题目标签关联
class MasterQuestionService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<MasterQuestionType> _types = [];
  List<MasterQuestionType> get types => List.unmodifiable(_types);

  /// 安全通知，避免在 build 阶段调用
  void _safeNotify() {
    scheduleMicrotask(notifyListeners);
  }

  // 支持"数量关系"/"数量分析"和"资料分析"的别名
  static const _masterCategories = {
    '数量关系': ['数量关系', '数量分析'],
    '数量分析': ['数量关系', '数量分析'],
    '资料分析': ['资料分析'],
  };

  /// 判断某分类是否支持母题标签
  static bool isMasterTagSupported(String category) {
    return _masterCategories.containsKey(category);
  }

  /// 获取规范化的母题分类名（用于存储）
  static String _normalizeCategory(String category) {
    if (category == '数量分析') return '数量关系';
    return category;
  }

  // ===== 母题类型 CRUD =====

  /// 加载某分类下的母题类型列表
  Future<List<MasterQuestionType>> loadTypes(String category) async {
    final db = await _db.database;
    final normalized = _normalizeCategory(category);
    final maps = await db.query(
      'master_question_types',
      where: 'category = ?',
      whereArgs: [normalized],
      orderBy: 'sort_order ASC, id ASC',
    );
    _types = maps.map(MasterQuestionType.fromDb).toList();
    _safeNotify();
    return _types;
  }

  /// 创建自定义母题类型
  Future<MasterQuestionType> createType(
    String category,
    String name, {
    String description = '',
  }) async {
    final db = await _db.database;
    final normalized = _normalizeCategory(category);
    // 排序值取最大值 +1
    final maxOrder = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM master_question_types WHERE category = ?',
      [normalized],
    );
    final nextOrder = ((maxOrder.first['max_order'] as int?) ?? 0) + 1;

    final id = await db.insert('master_question_types', {
      'category': normalized,
      'name': name,
      'description': description,
      'sort_order': nextOrder,
      'is_preset': 0,
    });

    final created = MasterQuestionType(
      id: id,
      category: normalized,
      name: name,
      description: description,
      sortOrder: nextOrder,
      isPreset: 0,
    );
    _types.add(created);
    _safeNotify();
    return created;
  }

  /// 编辑母题类型
  Future<void> updateType(int id, {String? name, String? description}) async {
    final db = await _db.database;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (updates.isEmpty) return;

    await db.update(
      'master_question_types',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    final idx = _types.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _types[idx] = _types[idx].copyWith(
        name: name ?? _types[idx].name,
        description: description ?? _types[idx].description,
      );
    }
    _safeNotify();
  }

  /// 删除自定义母题类型（预置不可删）
  Future<bool> deleteType(int id) async {
    final db = await _db.database;
    // 检查是否预置
    final rows = await db.query(
      'master_question_types',
      where: 'id = ? AND is_preset = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) return false;

    // 删除关联的标签
    await db.delete(
      'question_master_tags',
      where: 'master_type_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'master_question_types',
      where: 'id = ?',
      whereArgs: [id],
    );
    _types.removeWhere((t) => t.id == id);
    _safeNotify();
    return true;
  }

  // ===== 题目标签关联 =====

  /// 给题目打母题标签
  Future<void> tagQuestion(int questionId, int masterTypeId, {bool isRoot = false}) async {
    final db = await _db.database;
    await db.insert(
      'question_master_tags',
      {
        'question_id': questionId,
        'master_type_id': masterTypeId,
        'is_root': isRoot ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _safeNotify();
  }

  /// 移除标签
  Future<void> untagQuestion(int questionId, int masterTypeId) async {
    final db = await _db.database;
    await db.delete(
      'question_master_tags',
      where: 'question_id = ? AND master_type_id = ?',
      whereArgs: [questionId, masterTypeId],
    );
    _safeNotify();
  }

  /// 切换根源母题/变体
  Future<void> toggleRoot(int questionId, int masterTypeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'question_master_tags',
      where: 'question_id = ? AND master_type_id = ?',
      whereArgs: [questionId, masterTypeId],
    );
    if (rows.isEmpty) return;
    final current = (rows.first['is_root'] as int?) ?? 0;
    await db.update(
      'question_master_tags',
      {'is_root': current == 1 ? 0 : 1},
      where: 'question_id = ? AND master_type_id = ?',
      whereArgs: [questionId, masterTypeId],
    );
    _safeNotify();
  }

  /// 获取题目的母题标签列表
  Future<List<Map<String, dynamic>>> getTagsForQuestion(int questionId) async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT t.*, mt.name as type_name, mt.category as type_category
      FROM question_master_tags t
      JOIN master_question_types mt ON t.master_type_id = mt.id
      WHERE t.question_id = ?
      ORDER BY mt.sort_order ASC
    ''', [questionId]);
  }

  /// 按母题类型查询题目列表，根源母题排前
  Future<List<Question>> getQuestionsByType(
    int masterTypeId, {
    bool isRootOnly = false,
  }) async {
    final db = await _db.database;
    final rootCondition = isRootOnly ? ' AND t.is_root = 1' : '';
    final rows = await db.rawQuery('''
      SELECT q.*, t.is_root
      FROM questions q
      JOIN question_master_tags t ON q.id = t.question_id
      WHERE t.master_type_id = ?$rootCondition
      ORDER BY t.is_root DESC, q.id ASC
    ''', [masterTypeId]);
    return rows.map(Question.fromDb).toList();
  }

  /// 各母题类型的题目数量统计
  Future<List<Map<String, dynamic>>> getTypeStats(String category) async {
    final db = await _db.database;
    final normalized = _normalizeCategory(category);
    // 使用别名查询，因为题目的 category 可能是"数量分析"
    final aliases = _masterCategories[normalized] ?? [normalized];
    final placeholders = aliases.map((_) => '?').join(', ');

    return await db.rawQuery('''
      SELECT
        mt.id,
        mt.name,
        mt.description,
        mt.sort_order,
        mt.is_preset,
        COUNT(t.id) as total_count,
        SUM(CASE WHEN t.is_root = 1 THEN 1 ELSE 0 END) as root_count
      FROM master_question_types mt
      LEFT JOIN question_master_tags t ON mt.id = t.master_type_id
      LEFT JOIN questions q ON t.question_id = q.id AND q.category IN ($placeholders)
      WHERE mt.category = ?
      GROUP BY mt.id
      ORDER BY mt.sort_order ASC, mt.id ASC
    ''', [...aliases, normalized]);
  }
}
