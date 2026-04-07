import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/study_plan.dart';
import '../models/daily_task.dart';
import 'question_service.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 学习计划服务：AI 生成计划、每日任务、动态调整
class StudyPlanService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final QuestionService _questionService;
  final LlmManager _llmManager;

  StudyPlan? _activePlan;
  List<DailyTask> _todayTasks = [];
  List<StudyPlan> _allPlans = [];
  bool _isLoading = false;
  bool _isGenerating = false;

  StudyPlan? get activePlan => _activePlan;
  List<DailyTask> get todayTasks => List.unmodifiable(_todayTasks);
  List<StudyPlan> get allPlans => List.unmodifiable(_allPlans);
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get hasPlan => _activePlan != null;

  StudyPlanService(this._questionService, this._llmManager);

  /// 加载活跃计划和今日任务
  Future<void> loadActivePlan() async {
    _isLoading = true;
    notifyListeners();

    try {
      final planRow = await _db.queryActivePlan();
      if (planRow != null) {
        _activePlan = StudyPlan.fromDb(planRow);
        await _loadTodayTasks();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTodayTasks() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _db.queryDailyTasksByDate(today);
    _todayTasks = rows.map((r) => DailyTask.fromDb(r)).toList();
  }

  /// 加载所有计划
  Future<void> loadAllPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryStudyPlans();
      _allPlans = rows.map((r) => StudyPlan.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// AI 生成学习计划
  Future<StudyPlan> generatePlan({
    int? targetPositionId,
    String? examDate,
    List<String> subjects = const ['行测', '申论'],
    Map<String, double> baselineScores = const {},
    String? userContext,
  }) async {
    _isGenerating = true;
    notifyListeners();

    try {
      // 计算可用天数
      int availableDays = 90; // 默认 90 天
      if (examDate != null) {
        final exam = DateTime.tryParse(examDate);
        if (exam != null) {
          availableDays = exam.difference(DateTime.now()).inDays.clamp(7, 365);
        }
      }

      // 分析薄弱点
      final accuracyBySubject = await _questionService.getAccuracyBySubject();
      final weakSubjects = _identifyWeakSubjects(accuracyBySubject, subjects);

      // 构建 AI 提示词
      final prompt = _buildPlanPrompt(
        subjects: subjects,
        availableDays: availableDays,
        baselineScores: baselineScores,
        weakSubjects: weakSubjects,
        userContext: userContext,
        examDate: examDate,
      );

      final planContent = await _llmManager.chat([
        ChatMessage(role: 'user', content: prompt),
      ]);

      // 生成基础每日任务
      final tasks = _generateDailyTasks(
        subjects: subjects,
        availableDays: availableDays,
        weakSubjects: weakSubjects,
      );

      // 保存计划
      final plan = StudyPlan(
        targetPositionId: targetPositionId,
        examDate: examDate,
        subjects: subjects,
        baselineScores: baselineScores,
        planData: planContent,
        status: 'active',
      );

      // 将之前活跃计划设为 completed
      if (_activePlan != null && _activePlan!.id != null) {
        await _db.updateStudyPlan(_activePlan!.id!, {'status': 'completed'});
      }

      final planId = await _db.insertStudyPlan(plan.toDb());
      _activePlan = plan.copyWith(id: planId);

      // 保存每日任务
      for (final task in tasks) {
        final taskWithPlan = task.copyWith(planId: planId);
        await _db.insertDailyTask(taskWithPlan.toDb());
      }

      await _loadTodayTasks();
      notifyListeners();
      return _activePlan!;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 更新任务状态
  Future<void> updateTaskStatus(int taskId, String status, {int? completedCount}) async {
    final updates = <String, dynamic>{'status': status};
    if (completedCount != null) updates['completed_count'] = completedCount;
    await _db.updateDailyTask(taskId, updates);

    // 更新本地状态
    final index = _todayTasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      _todayTasks[index] = _todayTasks[index].copyWith(
        status: status,
        completedCount: completedCount ?? _todayTasks[index].completedCount,
      );
    }
    notifyListeners();
  }

  /// 动态调整计划（根据近期错题分布）
  Future<String> adjustPlan() async {
    final accuracyBySubject = await _questionService.getAccuracyBySubject();
    if (_activePlan == null) throw Exception('没有活跃的学习计划');

    final prompt = '''
根据以下学习数据，给出针对性的学习调整建议：
各科目正确率：${accuracyBySubject.map((r) => '${r['subject']}：${((r['correct'] as int? ?? 0) / ((r['total'] as int?) ?? 1) * 100).toStringAsFixed(1)}%').join('，')}
当前学习计划包含科目：${_activePlan!.subjects.join('，')}

请给出：
1. 薄弱科目分析（正确率低于60%的科目）
2. 下周学习重点调整建议
3. 具体练习题量建议

简洁回答，不超过300字。
''';

    return await _llmManager.chat([
      ChatMessage(role: 'user', content: prompt),
    ]);
  }

  /// 生成面试题（基础版）
  Future<String> generateInterviewQuestions(String positionName) async {
    final prompt = '''
我要报考"$positionName"岗位，请生成5道面试常考题，并提供简要答题框架。
格式：每题标注难度（★-★★★★★），附参考答题思路。
''';

    return await _llmManager.chat([
      ChatMessage(role: 'user', content: prompt),
    ]);
  }

  // ===== 内部方法 =====

  List<String> _identifyWeakSubjects(
    List<Map<String, dynamic>> accuracyData,
    List<String> subjects,
  ) {
    final weak = <String>[];
    for (final row in accuracyData) {
      final subject = row['subject'] as String;
      final total = (row['total'] as int?) ?? 0;
      final correct = (row['correct'] as int?) ?? 0;
      if (total > 0 && correct / total < 0.6) {
        weak.add(subject);
      }
    }
    return weak;
  }

  String _buildPlanPrompt({
    required List<String> subjects,
    required int availableDays,
    required Map<String, double> baselineScores,
    required List<String> weakSubjects,
    String? userContext,
    String? examDate,
  }) {
    return '''
请为我生成一份考公学习计划。

基本信息：
- 考试科目：${subjects.join('、')}
- 距考试天数：$availableDays 天${examDate != null ? '（考试日期：$examDate）' : ''}
- 各科基线分数：${baselineScores.isEmpty ? '未做摸底测试' : baselineScores.entries.map((e) => '${e.key}：${e.value.toStringAsFixed(0)}分').join('，')}
- 薄弱科目：${weakSubjects.isEmpty ? '暂无数据' : weakSubjects.join('、')}
${userContext != null ? '- 补充信息：$userContext' : ''}

请按以下结构生成计划：
1. 阶段划分（基础夯实→专项突破→刷题强化→冲刺模考）
2. 各阶段时间分配和重点
3. 每日学习建议（学习时长、科目分配）
4. 薄弱点强化策略

字数控制在500字以内，重点突出，可操作性强。
''';
  }

  List<DailyTask> _generateDailyTasks({
    required List<String> subjects,
    required int availableDays,
    required List<String> weakSubjects,
  }) {
    final tasks = <DailyTask>[];
    final today = DateTime.now();

    // 生成未来 7 天的任务
    final daysToGenerate = availableDays.clamp(1, 7);
    for (int day = 0; day < daysToGenerate; day++) {
      final date = today.add(Duration(days: day));
      final dateStr = date.toIso8601String().substring(0, 10);

      for (final subject in subjects) {
        final isWeak = weakSubjects.contains(subject);
        tasks.add(DailyTask(
          taskDate: dateStr,
          subject: subject,
          topic: isWeak ? '专项强化练习' : '日常练习',
          taskType: 'practice',
          targetCount: isWeak ? 30 : 20, // 薄弱科目多做题
          status: 'pending',
        ));
      }
    }
    return tasks;
  }
}
