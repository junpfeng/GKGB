import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/database_helper.dart';
import '../models/spatial_visualization.dart';

/// 空间可视化服务
/// 管理题目的立体拼合/折叠可视化数据，从预置 JSON 导入
class SpatialVizService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ===== 预置数据导入（启动时调用，幂等） =====

  /// 导入预置空间可视化数据
  Future<void> importPresetData() async {
    final db = await _db.database;

    // 幂等检查：已有数据则跳过
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM spatial_visualizations');
    final count = (result.first['cnt'] as int?) ?? 0;
    if (count > 0) {
      debugPrint('空间可视化预置数据已存在 ($count 条)，跳过导入');
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString(
          'assets/data/spatial_visualizations.json');
      final List<dynamic> items = jsonDecode(jsonStr);
      debugPrint('加载预置空间可视化 JSON: ${items.length} 条');

      if (items.isEmpty) return;

      final batch = db.batch();
      for (final item in items) {
        final questionId = item['question_id'] as int?;
        if (questionId == null) continue;

        batch.insert('spatial_visualizations', {
          'question_id': questionId,
          'viz_type': item['viz_type'] ?? 'cube_fold',
          'config_json': jsonEncode(item['config']),
          'solving_approach': item['solving_approach'] ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);

      final finalResult = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM spatial_visualizations');
      debugPrint('空间可视化导入完成: ${finalResult.first['cnt']} 条');
    } catch (e, st) {
      debugPrint('导入预置空间可视化数据失败: $e\n$st');
    }
  }

  // ===== 查询方法 =====

  /// 获取某题的可视化配置
  Future<SpatialVisualization?> getVisualization(int questionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'spatial_visualizations',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SpatialVisualization.fromDb(rows.first);
  }

  /// 检查某题是否有可视化数据
  Future<bool> hasVisualization(int questionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM spatial_visualizations WHERE question_id = ?',
      [questionId],
    );
    return ((result.first['cnt'] as int?) ?? 0) > 0;
  }
}
