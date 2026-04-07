import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

/// SQLite 数据库管理器（单例）
/// Windows 端使用 FFI，Android 端使用原生 sqflite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('exam_prep.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// 初始建库（version=2 全量建表）
  Future<void> _createDB(Database db, int version) async {
    // 题库表
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        options TEXT,
        answer TEXT NOT NULL,
        explanation TEXT,
        difficulty INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 答题记录表（含 exam_id 区分刷题 vs 模考）
    await db.execute('''
      CREATE TABLE user_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        exam_id INTEGER,
        user_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        time_spent INTEGER DEFAULT 0,
        answered_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (question_id) REFERENCES questions (id),
        FOREIGN KEY (exam_id) REFERENCES exams (id)
      )
    ''');

    // 收藏表
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL UNIQUE,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    // 用户画像表
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        education TEXT,
        degree TEXT,
        major TEXT,
        major_code TEXT,
        university TEXT,
        is_985 INTEGER DEFAULT 0,
        is_211 INTEGER DEFAULT 0,
        work_years INTEGER DEFAULT 0,
        has_grassroots_exp INTEGER DEFAULT 0,
        political_status TEXT,
        certificates TEXT,
        age INTEGER,
        gender TEXT,
        hukou_province TEXT,
        target_cities TEXT,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 人才引进公告表
    await db.execute('''
      CREATE TABLE talent_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        source_url TEXT,
        province TEXT,
        city TEXT,
        policy_type TEXT,
        publish_date TEXT,
        deadline TEXT,
        content TEXT,
        attachment_urls TEXT,
        fetched_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 岗位表
    await db.execute('''
      CREATE TABLE positions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        policy_id INTEGER,
        position_name TEXT NOT NULL,
        position_code TEXT,
        department TEXT,
        recruit_count INTEGER DEFAULT 1,
        education_req TEXT,
        degree_req TEXT,
        major_req TEXT,
        age_req TEXT,
        political_req TEXT,
        work_exp_req TEXT,
        certificate_req TEXT,
        gender_req TEXT,
        hukou_req TEXT,
        other_req TEXT,
        exam_subjects TEXT,
        exam_date TEXT,
        FOREIGN KEY (policy_id) REFERENCES talent_policies (id)
      )
    ''');

    // 匹配结果表
    await db.execute('''
      CREATE TABLE match_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        position_id INTEGER NOT NULL,
        match_score INTEGER DEFAULT 0,
        matched_items TEXT,
        risk_items TEXT,
        unmatched_items TEXT,
        advice TEXT,
        is_target INTEGER DEFAULT 0,
        matched_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (position_id) REFERENCES positions (id)
      )
    ''');

    // 学习计划表
    await db.execute('''
      CREATE TABLE study_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_position_id INTEGER,
        exam_date TEXT,
        subjects TEXT,
        baseline_scores TEXT,
        plan_data TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (target_position_id) REFERENCES positions (id)
      )
    ''');

    // 每日任务表
    await db.execute('''
      CREATE TABLE daily_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        task_date TEXT NOT NULL,
        subject TEXT NOT NULL,
        topic TEXT,
        task_type TEXT,
        target_count INTEGER DEFAULT 0,
        completed_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        FOREIGN KEY (plan_id) REFERENCES study_plans (id)
      )
    ''');

    // LLM 配置表（API Key 存 flutter_secure_storage，此处不存明文）
    await db.execute('''
      CREATE TABLE llm_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_name TEXT NOT NULL,
        base_url TEXT,
        model_name TEXT,
        is_default INTEGER DEFAULT 0,
        is_fallback INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 模拟考试表
    await db.execute('''
      CREATE TABLE exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        total_questions INTEGER NOT NULL,
        score REAL DEFAULT 0,
        time_limit INTEGER NOT NULL,
        started_at TEXT,
        finished_at TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // 建立索引
    await _createIndexes(db);
  }

  /// 版本升级迁移
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加 exam_id 到 user_answers
      try {
        await db.execute('ALTER TABLE user_answers ADD COLUMN exam_id INTEGER');
      } catch (e) {
        debugPrint('迁移 user_answers.exam_id 跳过: $e');
      }

      // 删除 llm_config.api_key_encrypted 字段（SQLite 不支持 DROP COLUMN，重建表）
      try {
        await db.execute('''
          CREATE TABLE llm_config_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            provider_name TEXT NOT NULL,
            base_url TEXT,
            model_name TEXT,
            is_default INTEGER DEFAULT 0,
            is_fallback INTEGER DEFAULT 0,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute('''
          INSERT INTO llm_config_new (id, provider_name, base_url, model_name, is_default, is_fallback, updated_at)
          SELECT id, provider_name, base_url, model_name, is_default, is_fallback, updated_at FROM llm_config
        ''');
        await db.execute('DROP TABLE llm_config');
        await db.execute('ALTER TABLE llm_config_new RENAME TO llm_config');
      } catch (e) {
        debugPrint('迁移 llm_config 表跳过: $e');
      }

      // 添加 exams 表
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exams (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject TEXT NOT NULL,
            total_questions INTEGER NOT NULL,
            score REAL DEFAULT 0,
            time_limit INTEGER NOT NULL,
            started_at TEXT,
            finished_at TEXT,
            status TEXT DEFAULT 'pending'
          )
        ''');
      } catch (e) {
        debugPrint('迁移 exams 表跳过: $e');
      }

      // 添加 favorites.question_id UNIQUE 约束（重建）
      try {
        await db.execute('''
          CREATE TABLE favorites_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id INTEGER NOT NULL UNIQUE,
            note TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (question_id) REFERENCES questions (id)
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO favorites_new (id, question_id, note, created_at)
          SELECT id, question_id, note, created_at FROM favorites
        ''');
        await db.execute('DROP TABLE favorites');
        await db.execute('ALTER TABLE favorites_new RENAME TO favorites');
      } catch (e) {
        debugPrint('迁移 favorites 表跳过: $e');
      }

      // 建立索引
      await _createIndexes(db);
    }
  }

  /// 创建所有索引
  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_questions_subject_category ON questions(subject, category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_user_answers_question_id ON user_answers(question_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_user_answers_answered_at ON user_answers(answered_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_user_answers_exam_id ON user_answers(exam_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_tasks_plan_date ON daily_tasks(plan_id, task_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_positions_policy_id ON positions(policy_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_match_results_position_id ON match_results(position_id)');
  }

  // ===== questions CRUD =====

  Future<int> insertQuestion(Map<String, dynamic> question) async {
    final db = await database;
    return await db.insert('questions', question);
  }

  Future<List<Map<String, dynamic>>> queryQuestions({
    String? subject,
    String? category,
    String? type,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (subject != null) {
      conditions.add('subject = ?');
      args.add(subject);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    return await db.query(
      'questions',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      limit: limit,
      offset: offset,
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, dynamic>?> queryQuestionById(int id) async {
    final db = await database;
    final rows = await db.query('questions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countQuestions({String? subject, String? category}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (subject != null) {
      conditions.add('subject = ?');
      args.add(subject);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM questions${where != null ? ' WHERE $where' : ''}',
      args.isEmpty ? null : args,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// 按科目随机抽题（用于组卷）
  Future<List<Map<String, dynamic>>> randomQuestions({
    required String subject,
    String? category,
    required int count,
  }) async {
    final db = await database;
    final conditions = ['subject = ?'];
    final args = <dynamic>[subject];
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    return await db.query(
      'questions',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'RANDOM()',
      limit: count,
    );
  }

  // ===== user_answers CRUD =====

  Future<int> insertAnswer(Map<String, dynamic> answer) async {
    final db = await database;
    return await db.insert('user_answers', answer);
  }

  Future<List<Map<String, dynamic>>> queryAnswersByQuestion(int questionId) async {
    final db = await database;
    return await db.query(
      'user_answers',
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'answered_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> queryAnswersByExam(int examId) async {
    final db = await database;
    return await db.query(
      'user_answers',
      where: 'exam_id = ?',
      whereArgs: [examId],
    );
  }

  /// 查询错题（答错的题目 ID 列表，去重）
  Future<List<int>> queryWrongQuestionIds({String? subject}) async {
    final db = await database;
    String sql = '''
      SELECT DISTINCT q.id
      FROM user_answers ua
      JOIN questions q ON ua.question_id = q.id
      WHERE ua.is_correct = 0
    ''';
    final args = <dynamic>[];
    if (subject != null) {
      sql += ' AND q.subject = ?';
      args.add(subject);
    }
    final rows = await db.rawQuery(sql, args.isEmpty ? null : args);
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<Map<String, dynamic>> queryTotalStats() async {
    final db = await database;
    final total = await db.rawQuery('SELECT COUNT(*) as cnt FROM user_answers');
    final correct = await db.rawQuery('SELECT COUNT(*) as cnt FROM user_answers WHERE is_correct = 1');
    final favCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM favorites');
    return {
      'total': (total.first['cnt'] as int?) ?? 0,
      'correct': (correct.first['cnt'] as int?) ?? 0,
      'favorites': (favCount.first['cnt'] as int?) ?? 0,
    };
  }

  Future<Map<String, dynamic>> queryTodayStats() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final total = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM user_answers WHERE answered_at LIKE ?",
      ['$today%'],
    );
    final correct = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM user_answers WHERE is_correct = 1 AND answered_at LIKE ?",
      ['$today%'],
    );
    return {
      'total': (total.first['cnt'] as int?) ?? 0,
      'correct': (correct.first['cnt'] as int?) ?? 0,
    };
  }

  /// 按科目查询正确率
  Future<List<Map<String, dynamic>>> queryAccuracyBySubject() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT q.subject,
             COUNT(*) as total,
             SUM(ua.is_correct) as correct
      FROM user_answers ua
      JOIN questions q ON ua.question_id = q.id
      GROUP BY q.subject
    ''');
  }

  // ===== favorites CRUD =====

  Future<int> insertFavorite(Map<String, dynamic> favorite) async {
    final db = await database;
    return await db.insert('favorites', favorite, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteFavorite(int questionId) async {
    final db = await database;
    return await db.delete('favorites', where: 'question_id = ?', whereArgs: [questionId]);
  }

  Future<bool> isFavorite(int questionId) async {
    final db = await database;
    final rows = await db.query('favorites', where: 'question_id = ?', whereArgs: [questionId]);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> queryFavorites() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT f.*, q.subject, q.category, q.type, q.content, q.options, q.answer, q.explanation, q.difficulty
      FROM favorites f
      JOIN questions q ON f.question_id = q.id
      ORDER BY f.created_at DESC
    ''');
  }

  // ===== user_profile CRUD =====

  Future<int> upsertProfile(Map<String, dynamic> profile) async {
    final db = await database;
    final existing = await db.query('user_profile', limit: 1);
    if (existing.isEmpty) {
      return await db.insert('user_profile', profile);
    } else {
      final id = existing.first['id'] as int;
      await db.update('user_profile', profile..['updated_at'] = DateTime.now().toIso8601String(),
          where: 'id = ?', whereArgs: [id]);
      return id;
    }
  }

  Future<Map<String, dynamic>?> queryProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // ===== talent_policies CRUD =====

  Future<int> insertPolicy(Map<String, dynamic> policy) async {
    final db = await database;
    return await db.insert('talent_policies', policy);
  }

  Future<List<Map<String, dynamic>>> queryPolicies({String? province, String? city}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (province != null) {
      conditions.add('province = ?');
      args.add(province);
    }
    if (city != null) {
      conditions.add('city = ?');
      args.add(city);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    return await db.query(
      'talent_policies',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fetched_at DESC',
    );
  }

  Future<int> updatePolicy(int id, Map<String, dynamic> policy) async {
    final db = await database;
    return await db.update('talent_policies', policy, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePolicy(int id) async {
    final db = await database;
    return await db.delete('talent_policies', where: 'id = ?', whereArgs: [id]);
  }

  // ===== positions CRUD =====

  Future<int> insertPosition(Map<String, dynamic> position) async {
    final db = await database;
    return await db.insert('positions', position);
  }

  Future<List<Map<String, dynamic>>> queryPositionsByPolicy(int policyId) async {
    final db = await database;
    return await db.query('positions', where: 'policy_id = ?', whereArgs: [policyId]);
  }

  Future<Map<String, dynamic>?> queryPositionById(int id) async {
    final db = await database;
    final rows = await db.query('positions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> deletePosition(int id) async {
    final db = await database;
    return await db.delete('positions', where: 'id = ?', whereArgs: [id]);
  }

  // ===== match_results CRUD =====

  Future<int> insertMatchResult(Map<String, dynamic> result) async {
    final db = await database;
    return await db.insert('match_results', result);
  }

  Future<List<Map<String, dynamic>>> queryMatchResults({bool? isTarget}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT mr.*, p.position_name, p.department, p.recruit_count,
             tp.title as policy_title, tp.city, tp.province
      FROM match_results mr
      JOIN positions p ON mr.position_id = p.id
      JOIN talent_policies tp ON p.policy_id = tp.id
      ${isTarget != null ? 'WHERE mr.is_target = ${isTarget ? 1 : 0}' : ''}
      ORDER BY mr.match_score DESC
    ''');
  }

  Future<int> updateMatchResult(int id, Map<String, dynamic> result) async {
    final db = await database;
    return await db.update('match_results', result, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMatchResultByPosition(int positionId) async {
    final db = await database;
    return await db.delete('match_results', where: 'position_id = ?', whereArgs: [positionId]);
  }

  // ===== exams CRUD =====

  Future<int> insertExam(Map<String, dynamic> exam) async {
    final db = await database;
    return await db.insert('exams', exam);
  }

  Future<List<Map<String, dynamic>>> queryExams({int? limit}) async {
    final db = await database;
    return await db.query('exams', orderBy: 'started_at DESC', limit: limit);
  }

  Future<Map<String, dynamic>?> queryExamById(int id) async {
    final db = await database;
    final rows = await db.query('exams', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateExam(int id, Map<String, dynamic> exam) async {
    final db = await database;
    return await db.update('exams', exam, where: 'id = ?', whereArgs: [id]);
  }

  // ===== study_plans CRUD =====

  Future<int> insertStudyPlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.insert('study_plans', plan);
  }

  Future<List<Map<String, dynamic>>> queryStudyPlans({String? status}) async {
    final db = await database;
    return await db.query(
      'study_plans',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> queryActivePlan() async {
    final db = await database;
    final rows = await db.query(
      'study_plans',
      where: 'status = ?',
      whereArgs: ['active'],
      limit: 1,
      orderBy: 'created_at DESC',
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateStudyPlan(int id, Map<String, dynamic> plan) async {
    final db = await database;
    return await db.update('study_plans', plan, where: 'id = ?', whereArgs: [id]);
  }

  // ===== daily_tasks CRUD =====

  Future<int> insertDailyTask(Map<String, dynamic> task) async {
    final db = await database;
    return await db.insert('daily_tasks', task);
  }

  Future<List<Map<String, dynamic>>> queryDailyTasksByDate(String date) async {
    final db = await database;
    return await db.query(
      'daily_tasks',
      where: 'task_date = ?',
      whereArgs: [date],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> queryDailyTasksByPlan(int planId) async {
    final db = await database;
    return await db.query(
      'daily_tasks',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'task_date ASC, id ASC',
    );
  }

  Future<int> updateDailyTask(int id, Map<String, dynamic> task) async {
    final db = await database;
    return await db.update('daily_tasks', task, where: 'id = ?', whereArgs: [id]);
  }

  // ===== llm_config CRUD =====

  Future<int> insertLlmConfig(Map<String, dynamic> config) async {
    final db = await database;
    return await db.insert('llm_config', config);
  }

  Future<List<Map<String, dynamic>>> queryLlmConfigs() async {
    final db = await database;
    return await db.query('llm_config', orderBy: 'is_default DESC, id ASC');
  }

  Future<int> updateLlmConfig(int id, Map<String, dynamic> config) async {
    final db = await database;
    return await db.update('llm_config', config, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteLlmConfig(int id) async {
    final db = await database;
    return await db.delete('llm_config', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDefaultLlmConfig() async {
    final db = await database;
    await db.update('llm_config', {'is_default': 0});
  }

  Future<void> clearFallbackLlmConfig() async {
    final db = await database;
    await db.update('llm_config', {'is_fallback': 0});
  }
}

/// Windows 平台 FFI 初始化（在 main.dart 调用）
void initSqfliteForWindows() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
