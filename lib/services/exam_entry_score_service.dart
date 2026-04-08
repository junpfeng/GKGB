import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/exam_entry_score.dart';

/// 进面分数线服务
class ExamEntryScoreService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 可用省份列表
  static const provinces = ['江苏', '浙江', '上海', '山东'];
  // 考试类型
  static const examTypes = ['国考', '省考', '事业编'];

  // 状态字段
  bool _isLoading = false;
  bool _isImporting = false;
  String? _error;
  List<ExamEntryScore> _scores = [];
  List<ExamEntryScore> _heatRanking = [];
  int _totalCount = 0;

  // 当前筛选条件
  String? _selectedProvince;
  String? _selectedCity;
  int? _selectedYear;
  String? _selectedExamType;
  List<String> _availableCities = [];
  List<int> _availableYears = [];

  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  String? get error => _error;
  List<ExamEntryScore> get scores => _scores;
  List<ExamEntryScore> get heatRanking => _heatRanking;
  int get totalCount => _totalCount;

  String? get selectedProvince => _selectedProvince;
  String? get selectedCity => _selectedCity;
  int? get selectedYear => _selectedYear;
  String? get selectedExamType => _selectedExamType;
  List<String> get availableCities => _availableCities;
  List<int> get availableYears => _availableYears;

  /// 设置省份筛选（联动刷新城市列表和年份列表）
  Future<void> setProvince(String? province) async {
    _selectedProvince = province;
    _selectedCity = null;
    notifyListeners();
    if (province != null) {
      _availableCities = await _db.queryEntryScoreCities(province);
      _availableYears = await _db.queryEntryScoreYears(
        province: province,
        examType: _selectedExamType,
      );
    } else {
      _availableCities = [];
      _availableYears = [];
    }
    notifyListeners();
    await loadScores();
  }

  /// 设置城市筛选
  Future<void> setCity(String? city) async {
    _selectedCity = city;
    notifyListeners();
    await loadScores();
  }

  /// 设置年份筛选
  Future<void> setYear(int? year) async {
    _selectedYear = year;
    notifyListeners();
    await loadScores();
  }

  /// 设置考试类型筛选（联动刷新年份列表）
  Future<void> setExamType(String? examType) async {
    _selectedExamType = examType;
    notifyListeners();
    _availableYears = await _db.queryEntryScoreYears(
      province: _selectedProvince,
      examType: examType,
    );
    notifyListeners();
    await loadScores();
  }

  /// 本地分页查询
  Future<void> loadScores({int offset = 0, int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.queryEntryScores(
        province: _selectedProvince,
        city: _selectedCity,
        year: _selectedYear,
        examType: _selectedExamType,
        offset: offset,
        limit: limit,
      );
      if (offset == 0) {
        _scores = rows.map((r) => ExamEntryScore.fromDb(r)).toList();
      } else {
        _scores.addAll(rows.map((r) => ExamEntryScore.fromDb(r)));
      }
      _totalCount = await _db.queryEntryScoreCount(
        province: _selectedProvince,
        city: _selectedCity,
        year: _selectedYear,
        examType: _selectedExamType,
      );
    } catch (e) {
      _error = '加载分数线数据失败: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 热度排行 TOP N
  Future<void> getHeatRanking({int topN = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.queryEntryScoreHeatRanking(
        province: _selectedProvince,
        year: _selectedYear,
        examType: _selectedExamType,
        topN: topN,
      );
      _heatRanking = rows.map((r) => ExamEntryScore.fromDb(r)).toList();
    } catch (e) {
      _error = '加载热度排行失败: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 年度趋势数据
  Future<List<ExamEntryScore>> getScoreTrend({
    required String positionName,
    String? province,
    String? department,
  }) async {
    try {
      final rows = await _db.queryEntryScoreTrend(
        positionName: positionName,
        province: province,
        department: department,
      );
      return rows.map((r) => ExamEntryScore.fromDb(r)).toList();
    } catch (e) {
      debugPrint('加载年度趋势失败: $e');
      return [];
    }
  }

  // ===== 预置数据导入 =====

  /// 检查 SQLite 是否已有数据（避免重复导入）
  Future<bool> _isDataLoaded() async {
    final count = await _db.queryEntryScoreCount();
    return count > 0;
  }

  /// 从 assets 导入预置分数线数据（幂等：已有数据则跳过）
  Future<void> loadFromAssets() async {
    if (await _isDataLoaded()) return;

    _isImporting = true;
    notifyListeners();

    try {
      // 读取 index.json 获取文件列表
      final indexStr = await rootBundle.loadString(
        'assets/data/exam_entry_scores/index.json',
      );
      final indexData = json.decode(indexStr) as Map<String, dynamic>;
      final files = (indexData['files'] as List).cast<String>();

      int totalImported = 0;

      for (final filePath in files) {
        try {
          final jsonStr = await rootBundle.loadString(filePath);
          final items = (json.decode(jsonStr) as List).cast<Map<String, dynamic>>();

          // 补充 fetched_at 时间戳
          final now = DateTime.now().toIso8601String();
          final rows = items.map((item) {
            item['fetched_at'] = now;
            item['updated_at'] = now;
            return item;
          }).toList();

          await _db.batchUpsertEntryScores(rows);
          totalImported += rows.length;
        } catch (e) {
          debugPrint('导入 $filePath 失败: $e');
        }
      }

      debugPrint('进面分数线数据导入完成，共 $totalImported 条');
    } catch (e) {
      debugPrint('导入预置分数线数据失败: $e');
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }
}
