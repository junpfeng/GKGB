import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

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

    // 答题记录表
    await db.execute('''
      CREATE TABLE user_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        user_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        time_spent INTEGER DEFAULT 0,
        answered_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    // 收藏表
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
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

    // LLM 配置表
    await db.execute('''
      CREATE TABLE llm_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_name TEXT NOT NULL,
        api_key_encrypted TEXT,
        base_url TEXT,
        model_name TEXT,
        is_default INTEGER DEFAULT 0,
        is_fallback INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
}
