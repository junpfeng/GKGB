import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/database_helper.dart';

/// 速算训练服务
/// 管理速算练习题导入、训练会话记录、每日挑战状态
class SpeedTrainingService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ===== 预置数据导入（启动时调用，幂等） =====

  /// 导入预置速算练习数据
  Future<void> importPresetExercises() async {
    final db = await _db.database;

    // 幂等检查：已有数据则跳过
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM speed_calc_exercises');
    final count = (result.first['cnt'] as int?) ?? 0;
    if (count > 0) {
      debugPrint('速算练习预置数据已存在 ($count 条)，跳过导入');
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString(
          'assets/data/speed_calc_preset.json');
      final List<dynamic> items = jsonDecode(jsonStr);
      debugPrint('加载预置速算练习 JSON: ${items.length} 条');

      if (items.isEmpty) return;

      final batch = db.batch();
      for (final item in items) {
        batch.insert('speed_calc_exercises', {
          'calc_type': item['calc_type'] ?? '',
          'expression': item['expression'] ?? '',
          'display_text': item['display_text'] ?? '',
          'correct_answer': item['correct_answer'] ?? '',
          'tolerance': (item['tolerance'] as num?)?.toDouble() ?? 0.01,
          'difficulty': item['difficulty'] ?? 3,
          'shortcut_hint': item['shortcut_hint'] ?? '',
          'explanation': item['explanation'] ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);

      final finalResult = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM speed_calc_exercises');
      debugPrint('速算练习导入完成: ${finalResult.first['cnt']} 条');
    } catch (e, st) {
      debugPrint('导入预置速算练习数据失败: $e\n$st');
    }
  }

  // ===== 每日挑战 =====

  /// 检查今天是否已完成每日挑战
  Future<bool> hasTodayChallenge() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM speed_training_sessions WHERE session_date = ? AND session_type = ?',
      [today, 'daily_challenge'],
    );
    return ((result.first['cnt'] as int?) ?? 0) > 0;
  }

  // ===== 练习题查询 =====

  /// 按类型和难度获取练习题
  Future<List<Map<String, dynamic>>> getExercises({
    String? calcType,
    int? difficulty,
    int limit = 20,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (calcType != null) {
      where.add('calc_type = ?');
      args.add(calcType);
    }
    if (difficulty != null) {
      where.add('difficulty = ?');
      args.add(difficulty);
    }

    return db.query(
      'speed_calc_exercises',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'RANDOM()',
      limit: limit,
    );
  }

  /// 获取所有计算类型
  Future<List<String>> getCalcTypes() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT calc_type FROM speed_calc_exercises ORDER BY calc_type');
    return rows.map((r) => r['calc_type'] as String).toList();
  }

  // ===== 训练会话 =====

  /// 创建训练会话，返回会话 ID
  Future<int> createSession({
    required String sessionType,
    String calcType = '',
    required int totalQuestions,
  }) async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.insert('speed_training_sessions', {
      'session_date': today,
      'session_type': sessionType,
      'calc_type': calcType,
      'total_questions': totalQuestions,
    });
  }

  /// 记录答题
  Future<void> recordAnswer({
    required int sessionId,
    required int exerciseId,
    required String userAnswer,
    required bool isCorrect,
    required int timeMs,
  }) async {
    final db = await _db.database;
    await db.insert('speed_training_answers', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'user_answer': userAnswer,
      'is_correct': isCorrect ? 1 : 0,
      'time_ms': timeMs,
    });
  }

  /// 完成会话，更新统计数据
  Future<void> finishSession({
    required int sessionId,
    required int correctCount,
    required int totalTimeMs,
    required int avgTimeMs,
    required double accuracy,
  }) async {
    final db = await _db.database;
    await db.update(
      'speed_training_sessions',
      {
        'correct_count': correctCount,
        'total_time_ms': totalTimeMs,
        'avg_time_ms': avgTimeMs,
        'accuracy': accuracy,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    notifyListeners();
  }

  /// 获取历史会话列表
  Future<List<Map<String, dynamic>>> getSessionHistory({int limit = 20}) async {
    final db = await _db.database;
    return db.query(
      'speed_training_sessions',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
