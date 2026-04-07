import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/mastery_score.dart';
import '../models/question.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// AI 自适应智能出题服务
/// 薄弱优先 + 遗忘曲线 + 难度递进 + AI 动态生成
class AdaptiveQuizService extends ChangeNotifier {
  final LlmManager _llm;
  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _initialized = false;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;

  /// 遗忘曲线间隔（天）
  static const List<int> _reviewIntervals = [1, 2, 4, 7, 15, 30];

  AdaptiveQuizService(this._llm);

  // ===== 知识点初始化 =====

  /// 幂等初始化：根据 questions 表的 subject+category 自动生成知识点
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final db = await _db.database;
    final count = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM knowledge_points',
    );
    if ((count.first['cnt'] as int) > 0) {
      _initialized = true;
      return;
    }
    await _initKnowledgePoints();
    _initialized = true;
  }

  Future<void> _initKnowledgePoints() async {
    final db = await _db.database;
    // 从 questions 表获取所有 subject+category 组合
    final combos = await db.rawQuery(
      'SELECT DISTINCT subject, category FROM questions',
    );
    if (combos.isEmpty) return;

    await db.transaction((txn) async {
      for (final row in combos) {
        final subject = row['subject'] as String;
        final category = row['category'] as String;
        // 用 category 作为知识点名称
        await txn.rawInsert(
          'INSERT OR IGNORE INTO knowledge_points (name, subject, category) VALUES (?, ?, ?)',
          [category, subject, category],
        );
      }
    });

    // 为每个知识点初始化掌握度记录
    final points = await db.query('knowledge_points');
    await db.transaction((txn) async {
      for (final p in points) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO mastery_scores (knowledge_point_id) VALUES (?)',
          [p['id']],
        );
      }
    });
  }

  // ===== 智能选题 =====

  /// 智能选题算法：薄弱优先 → 遗忘曲线 → 难度递进 → fallback 随机
  Future<List<Question>> getNextQuestions({
    int count = 10,
    String? subject,
  }) async {
    await ensureInitialized();
    _isLoading = true;
    _safeNotify();

    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();
      final questions = <Question>[];
      final usedIds = <int>{};

      // 1. 薄弱知识点（score < 60）
      final weakPoints = await _getWeakKnowledgePoints(
        db, subject: subject, limit: count,
      );
      for (final kp in weakPoints) {
        if (questions.length >= count) break;
        final qs = await _getQuestionsForKnowledgePoint(
          db, kp, usedIds, count: 2,
        );
        questions.addAll(qs);
        usedIds.addAll(qs.map((q) => q.id!));
      }

      // 2. 需要复习的知识点（next_review_at <= now）
      if (questions.length < count) {
        final reviewPoints = await _getReviewKnowledgePoints(
          db, now, subject: subject, limit: count,
        );
        for (final kp in reviewPoints) {
          if (questions.length >= count) break;
          final qs = await _getQuestionsForKnowledgePoint(
            db, kp, usedIds, count: 2,
          );
          questions.addAll(qs);
          usedIds.addAll(qs.map((q) => q.id!));
        }
      }

      // 3. fallback：随机补齐
      if (questions.length < count) {
        final remaining = count - questions.length;
        final randomQs = await _getRandomQuestions(
          db, usedIds, subject: subject, count: remaining,
        );
        questions.addAll(randomQs);
      }

      // 4. 同知识点内按 difficulty 递进排序
      questions.sort((a, b) {
        final cmp = a.category.compareTo(b.category);
        if (cmp != 0) return cmp;
        return a.difficulty.compareTo(b.difficulty);
      });

      return questions.take(count).toList();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<List<Map<String, dynamic>>> _getWeakKnowledgePoints(
    dynamic db, {
    String? subject,
    required int limit,
  }) async {
    String sql = '''
      SELECT kp.*, ms.score FROM knowledge_points kp
      JOIN mastery_scores ms ON kp.id = ms.knowledge_point_id
      WHERE ms.score < 60
    ''';
    final args = <dynamic>[];
    if (subject != null) {
      sql += ' AND kp.subject = ?';
      args.add(subject);
    }
    sql += ' ORDER BY ms.score ASC LIMIT ?';
    args.add(limit);
    return await db.rawQuery(sql, args);
  }

  Future<List<Map<String, dynamic>>> _getReviewKnowledgePoints(
    dynamic db,
    String now, {
    String? subject,
    required int limit,
  }) async {
    String sql = '''
      SELECT kp.*, ms.score FROM knowledge_points kp
      JOIN mastery_scores ms ON kp.id = ms.knowledge_point_id
      WHERE ms.next_review_at IS NOT NULL AND ms.next_review_at <= ?
    ''';
    final args = <dynamic>[now];
    if (subject != null) {
      sql += ' AND kp.subject = ?';
      args.add(subject);
    }
    sql += ' ORDER BY ms.next_review_at ASC LIMIT ?';
    args.add(limit);
    return await db.rawQuery(sql, args);
  }

  Future<List<Question>> _getQuestionsForKnowledgePoint(
    dynamic db,
    Map<String, dynamic> kp,
    Set<int> usedIds, {
    required int count,
  }) async {
    final subject = kp['subject'] as String;
    final category = kp['category'] as String;
    String sql = '''
      SELECT * FROM questions
      WHERE subject = ? AND category = ?
    ''';
    final args = <dynamic>[subject, category];
    if (usedIds.isNotEmpty) {
      sql += ' AND id NOT IN (${usedIds.join(',')})';
    }
    sql += ' ORDER BY difficulty ASC LIMIT ?';
    args.add(count);
    final rows = await db.rawQuery(sql, args);
    return (rows as List<Map<String, dynamic>>)
        .map((r) => Question.fromDb(r))
        .toList();
  }

  Future<List<Question>> _getRandomQuestions(
    dynamic db,
    Set<int> usedIds, {
    String? subject,
    required int count,
  }) async {
    String sql = 'SELECT * FROM questions WHERE 1=1';
    final args = <dynamic>[];
    if (subject != null) {
      sql += ' AND subject = ?';
      args.add(subject);
    }
    if (usedIds.isNotEmpty) {
      sql += ' AND id NOT IN (${usedIds.join(',')})';
    }
    sql += ' ORDER BY RANDOM() LIMIT ?';
    args.add(count);
    final rows = await db.rawQuery(sql, args);
    return (rows as List<Map<String, dynamic>>)
        .map((r) => Question.fromDb(r))
        .toList();
  }

  // ===== 掌握度更新 =====

  /// 更新掌握度（原子事务）
  /// 正确：score += (100 - score) * 0.1
  /// 错误：score -= score * 0.2
  Future<void> updateMastery(int knowledgePointId, bool isCorrect) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT * FROM mastery_scores WHERE knowledge_point_id = ?',
        [knowledgePointId],
      );
      if (rows.isEmpty) return;
      final ms = MasteryScore.fromDb(rows.first);

      final newScore = isCorrect
          ? ms.score + (100 - ms.score) * 0.1
          : ms.score - ms.score * 0.2;
      final clampedScore = newScore.clamp(0.0, 100.0);
      final newTotal = ms.totalAttempts + 1;
      final newCorrect = ms.correctAttempts + (isCorrect ? 1 : 0);

      // 计算连续正确次数（用于遗忘曲线间隔）
      final correctStreak = isCorrect ? _calcCorrectStreak(ms, true) : 0;
      final reviewIndex = min(correctStreak, _reviewIntervals.length - 1);
      final nextReview = DateTime.now()
          .add(Duration(days: _reviewIntervals[reviewIndex]))
          .toIso8601String();

      await txn.rawUpdate(
        '''UPDATE mastery_scores SET
           score = ?, total_attempts = ?, correct_attempts = ?,
           last_practiced_at = ?, next_review_at = ?, updated_at = ?
           WHERE knowledge_point_id = ?''',
        [
          clampedScore,
          newTotal,
          newCorrect,
          DateTime.now().toIso8601String(),
          nextReview,
          DateTime.now().toIso8601String(),
          knowledgePointId,
        ],
      );
    });
    notifyListeners();
  }

  int _calcCorrectStreak(MasteryScore ms, bool currentCorrect) {
    if (!currentCorrect) return 0;
    // 简化：基于 correctAttempts / totalAttempts 估算连续正确
    if (ms.totalAttempts == 0) return 1;
    final ratio = ms.correctAttempts / ms.totalAttempts;
    if (ratio >= 0.9) return 5;
    if (ratio >= 0.8) return 4;
    if (ratio >= 0.7) return 3;
    if (ratio >= 0.5) return 2;
    return 1;
  }

  /// 根据题目获取对应知识点 ID
  Future<int?> getKnowledgePointId(String subject, String category) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT id FROM knowledge_points WHERE subject = ? AND category = ?',
      [subject, category],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  // ===== 掌握度总览 =====

  /// 获取掌握度总览列表
  Future<List<Map<String, dynamic>>> getMasteryOverview({
    String? subject,
  }) async {
    await ensureInitialized();
    final db = await _db.database;
    String sql = '''
      SELECT kp.*, ms.score, ms.total_attempts, ms.correct_attempts,
             ms.last_practiced_at, ms.next_review_at
      FROM knowledge_points kp
      LEFT JOIN mastery_scores ms ON kp.id = ms.knowledge_point_id
    ''';
    final args = <dynamic>[];
    if (subject != null) {
      sql += ' WHERE kp.subject = ?';
      args.add(subject);
    }
    sql += ' ORDER BY COALESCE(ms.score, 50) ASC';
    return await db.rawQuery(sql, args);
  }

  /// 获取科目列表
  Future<List<String>> getSubjects() async {
    await ensureInitialized();
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT subject FROM knowledge_points ORDER BY subject',
    );
    return rows.map((r) => r['subject'] as String).toList();
  }

  // ===== 学习效率分析 =====

  /// 近 N 天学习效率曲线
  Future<List<Map<String, dynamic>>> getLearningEfficiency({
    int days = 7,
  }) async {
    final db = await _db.database;
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    return await db.rawQuery('''
      SELECT DATE(answered_at) as date,
             COUNT(*) as total,
             SUM(is_correct) as correct
      FROM user_answers
      WHERE answered_at >= ?
      GROUP BY DATE(answered_at)
      ORDER BY date ASC
    ''', ['$since%']);
  }

  /// 预测达标日期
  Future<String?> getPredictedReadyDate(
    String subject,
    double targetScore,
  ) async {
    final overview = await getMasteryOverview(subject: subject);
    if (overview.isEmpty) return null;
    final avgScore = overview.fold<double>(
          0,
          (sum, r) => sum + ((r['score'] as num?)?.toDouble() ?? 50),
        ) /
        overview.length;
    if (avgScore >= targetScore) return '已达标';
    // 简化预测：按每天提升 1-2 分估算
    final gap = targetScore - avgScore;
    final estimatedDays = (gap / 1.5).ceil();
    final readyDate = DateTime.now().add(Duration(days: estimatedDays));
    return readyDate.toIso8601String().substring(0, 10);
  }

  // ===== AI 动态生成题目 =====

  /// 用 LLM 生成题目并存入 questions 表
  Future<Question?> generateQuestion(
    String subject,
    String category,
    int difficulty,
  ) async {
    if (!_llm.hasProvider) return null;

    final prompt = '''
请生成一道考公考编题目，要求：
- 科目：$subject
- 分类：$category
- 难度：$difficulty（1-5，1最简单）
- 题型：单选题

请严格按以下 JSON 格式返回（不要包含其他文字）：
```json
{
  "content": "题目内容",
  "options": ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
  "answer": "A",
  "explanation": "解析内容"
}
```
''';

    try {
      final response = await _llm.chat([
        ChatMessage(role: 'user', content: prompt),
      ]);
      return _parseGeneratedQuestion(response, subject, category, difficulty);
    } catch (e) {
      debugPrint('AI 生成题目失败: $e');
      return null;
    }
  }

  Question? _parseGeneratedQuestion(
    String response,
    String subject,
    String category,
    int difficulty,
  ) {
    try {
      // 提取 JSON 块
      String jsonStr = response;
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)```').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!.trim();
      } else {
        // 尝试直接找 { ... }
        final braceMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
        if (braceMatch != null) {
          jsonStr = braceMatch.group(0)!;
        }
      }
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final content = data['content'] as String?;
      final options = (data['options'] as List?)?.cast<String>();
      final answer = data['answer'] as String?;
      final explanation = data['explanation'] as String?;

      if (content == null || options == null || answer == null) return null;
      if (options.length < 2) return null;

      // difficulty 校验
      final clampedDiff = difficulty.clamp(1, 5);

      final question = Question(
        subject: subject,
        category: category,
        type: 'single',
        content: content,
        options: options,
        answer: answer,
        explanation: explanation,
        difficulty: clampedDiff,
      );

      // 异步存入 questions 表
      _saveGeneratedQuestion(question);

      return question;
    } catch (e) {
      debugPrint('解析 AI 生成题目失败: $e');
      return null;
    }
  }

  Future<void> _saveGeneratedQuestion(Question question) async {
    try {
      final db = await _db.database;
      await db.insert('questions', question.toDb());
    } catch (e) {
      debugPrint('保存 AI 生成题目失败: $e');
    }
  }

  void _safeNotify() {
    scheduleMicrotask(notifyListeners);
  }
}
