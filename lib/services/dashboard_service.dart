import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import 'question_service.dart';
import 'exam_service.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';
import 'exam_category_service.dart';

/// 看板数据模型
class DashboardData {
  final Map<String, dynamic> todayOverview;
  final Map<String, double> radarData;
  final Map<DateTime, int> heatmapData;
  final Map<String, Map<String, dynamic>> weekComparison;
  final List<Map<String, dynamic>> scoreTrend;
  final int studyStreak;
  final double overallProgress;

  const DashboardData({
    required this.todayOverview,
    required this.radarData,
    required this.heatmapData,
    required this.weekComparison,
    required this.scoreTrend,
    required this.studyStreak,
    required this.overallProgress,
  });
}

/// 看板服务：聚合所有仪表板数据，缓存 5 分钟
class DashboardService extends ChangeNotifier {
  final QuestionService _questionService;
  final ExamService _examService;
  final LlmManager _llmManager;
  final ExamCategoryService _examCategoryService;
  final DatabaseHelper _db = DatabaseHelper.instance;

  DashboardData? _cachedData;
  DateTime? _cacheTime;
  bool _isLoading = false;
  static const _cacheDuration = Duration(minutes: 5);

  DashboardData? get data => _cachedData;
  bool get isLoading => _isLoading;
  bool get hasData => _cachedData != null;

  DashboardService(this._questionService, this._examService, this._llmManager, this._examCategoryService);

  /// 一次性加载所有仪表板数据（带 5 分钟缓存）
  Future<void> refreshDashboard({bool force = false}) async {
    // 缓存未过期且非强制刷新
    if (!force && _cachedData != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final examTypes = _examCategoryService.activeExamTypeValues;
      final etArg = examTypes.isEmpty ? null : examTypes;

      // 各查询独立容错，任何单个失败都使用默认值，确保看板始终能渲染
      final todayOverview = await _safeLoad(
        () => _loadTodayOverview(),
        fallback: const {'answeredToday': 0, 'correctToday': 0, 'streak': 0},
        label: '今日概览',
      );
      final radarData = await _safeLoad(
        () => _loadRadarData(),
        fallback: const <String, double>{},
        label: '雷达图',
      );
      final heatmapData = await _safeLoad(
        () => _loadHeatmapData(),
        fallback: const <DateTime, int>{},
        label: '热力图',
      );
      final weekComparison = await _safeLoad(
        () => _db.queryWeeklyComparison(examTypes: etArg),
        fallback: <String, Map<String, dynamic>>{
          'thisWeek': {'total': 0, 'correct': 0},
          'lastWeek': {'total': 0, 'correct': 0},
        },
        label: '周对比',
      );
      final scoreTrend = await _safeLoad(
        () => _examService.getScoreTrend(limit: 10),
        fallback: const <Map<String, dynamic>>[],
        label: '成绩趋势',
      );
      final studyStreak = await _safeLoad(
        () => _db.queryStudyStreak(),
        fallback: 0,
        label: '连续打卡',
      );
      final overallProgress = await _safeLoad(
        () => _db.queryOverallProgress(),
        fallback: 0.0,
        label: '备考进度',
      );

      _cachedData = DashboardData(
        todayOverview: todayOverview,
        radarData: radarData,
        heatmapData: heatmapData,
        weekComparison: weekComparison,
        scoreTrend: scoreTrend,
        studyStreak: studyStreak,
        overallProgress: overallProgress,
      );
      _cacheTime = DateTime.now();
    } catch (e) {
      debugPrint('看板数据加载失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 安全加载：单个查询失败时返回 fallback，不影响其他查询
  Future<T> _safeLoad<T>(Future<T> Function() loader, {required T fallback, required String label}) async {
    try {
      return await loader();
    } catch (e) {
      debugPrint('看板[$label]加载失败: $e');
      return fallback;
    }
  }

  /// 今日概览
  Future<Map<String, dynamic>> _loadTodayOverview() async {
    final todayStats = await _questionService.getTodayStats();
    final streak = await _db.queryStudyStreak();
    return {
      'answeredToday': (todayStats['total'] as int?) ?? 0,
      'correctToday': (todayStats['correct'] as int?) ?? 0,
      'streak': streak,
    };
  }

  /// 各科正确率（雷达图）
  Future<Map<String, double>> _loadRadarData() async {
    final examTypes = _examCategoryService.activeExamTypeValues;
    final rows = await _db.querySubjectRadarData(
      examTypes: examTypes.isEmpty ? null : examTypes,
    );
    final result = <String, double>{};
    for (final row in rows) {
      final category = row['category'] as String? ?? '未知';
      final total = (row['total'] as int?) ?? 0;
      final correct = (row['correct'] as int?) ?? 0;
      result[category] = total == 0 ? 0.0 : correct / total;
    }
    return result;
  }

  /// 热力图数据（近 90 天）
  Future<Map<DateTime, int>> _loadHeatmapData({int days = 90}) async {
    final rows = await _db.queryDailyActivityHeatmap(days);
    final result = <DateTime, int>{};
    for (final row in rows) {
      final dateStr = row['date'] as String;
      final count = (row['count'] as int?) ?? 0;
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        result[DateTime(date.year, date.month, date.day)] = count;
      }
    }
    return result;
  }

  /// 生成 AI 周报（流式）
  Stream<String> generateWeeklyReport() {
    if (_cachedData == null) {
      return Stream.value('暂无数据，请先完成一些练习后再生成周报。');
    }

    final data = _cachedData!;
    final overview = data.todayOverview;
    final week = data.weekComparison;
    final thisWeek = week['thisWeek'] ?? {};
    final lastWeek = week['lastWeek'] ?? {};
    final radarStr = data.radarData.entries
        .map((e) => '${e.key}: ${(e.value * 100).round()}%')
        .join('、');

    final prompt = '''
你是一位专业的公考备考辅导老师，请根据以下学习数据，为考生生成一份简洁实用的周报。

【本周数据】
- 做题量: ${thisWeek['total'] ?? 0} 题，正确: ${thisWeek['correct'] ?? 0} 题
- 上周做题量: ${lastWeek['total'] ?? 0} 题，正确: ${lastWeek['correct'] ?? 0} 题
- 连续打卡: ${overview['streak'] ?? 0} 天
- 备考进度: ${(data.overallProgress * 100).round()}%
- 各科正确率: $radarStr

请从以下维度分析：
1. 本周学习概况（与上周对比）
2. 强项与薄弱科目
3. 下周建议（具体、可操作）

语言简洁，适度鼓励，控制在 300 字以内。
''';

    return _llmManager.streamChat([
      ChatMessage(role: 'user', content: prompt),
    ]);
  }
}
