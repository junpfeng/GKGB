import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../db/database_helper.dart';
import '../models/exam_entry_score.dart';

/// 进面分数线服务
class ExamEntryScoreService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 可用省份列表
  static const provinces = ['江苏', '浙江', '上海', '山东'];
  // 考试类型
  static const examTypes = ['国考', '省考'];

  // 状态字段
  bool _isLoading = false;
  bool _isFetching = false;
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
  bool get isFetching => _isFetching;
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

  /// 从网络爬取进面分数线数据
  /// _isFetching 防重入锁，爬取进行中拒绝新请求
  Future<String?> fetchScores({
    required String province,
    required String examType,
    int? year,
  }) async {
    if (_isFetching) return '正在爬取中，请稍候...';

    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      // 构建爬取目标 URL（根据省份和考试类型确定数据源）
      final urls = _getDataSourceUrls(province, examType, year);
      if (urls.isEmpty) {
        return '暂不支持该省份/考试类型的数据爬取';
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': 'ExamPrepApp/1.0 (exam-entry-scores-crawler)',
        },
      ));

      int totalInserted = 0;

      for (final url in urls) {
        // 强制节流 ≥2s/request（宪法要求）
        await Future.delayed(const Duration(seconds: 2));

        try {
          final response = await dio.get(url);
          if (response.statusCode == 200) {
            final parsed = _parseScoreData(response.data, province, examType, year, url);
            if (parsed.isNotEmpty) {
              await _db.batchUpsertEntryScores(parsed);
              totalInserted += parsed.length;
            }
          }
        } on DioException catch (e) {
          debugPrint('爬取 $url 失败: ${e.message}');
        }
      }

      // 爬取完成后刷新本地数据
      await loadScores();
      await getHeatRanking();

      if (totalInserted > 0) {
        return null; // 成功无错误
      }
      return '未能从数据源获取到有效数据，请稍后重试';
    } catch (e) {
      _error = '爬取失败: $e';
      return _error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// 获取数据源 URL 列表（根据省份和考试类型）
  /// 具体 URL 和解析规则需根据实际网站结构确定
  List<String> _getDataSourceUrls(String province, String examType, int? year) {
    // 数据源 URL 配置
    // 各省人事考试网 / 国家公务员局公开数据
    // 实际爬取时需根据目标站点结构动态构建
    final targetYear = year ?? DateTime.now().year;
    final urls = <String>[];

    if (examType == '国考') {
      // 国家公务员局公示数据
      urls.add('https://www.scs.gov.cn/ywzl/jlgwy/$targetYear/');
    } else {
      // 各省人事考试网
      switch (province) {
        case '江苏':
          urls.add('https://www.jshrss.gov.cn/gwy/$targetYear/');
          break;
        case '浙江':
          urls.add('https://www.zjks.gov.cn/gwy/$targetYear/');
          break;
        case '上海':
          urls.add('https://www.shacs.gov.cn/gwy/$targetYear/');
          break;
        case '山东':
          urls.add('https://hrss.shandong.gov.cn/gwy/$targetYear/');
          break;
      }
    }
    return urls;
  }

  /// 解析爬取到的 HTML/JSON 数据
  /// 需根据实际数据源的页面结构编写具体解析逻辑
  List<Map<String, dynamic>> _parseScoreData(
    dynamic responseData,
    String province,
    String examType,
    int? year,
    String sourceUrl,
  ) {
    final results = <Map<String, dynamic>>[];
    // 实际解析逻辑需根据目标网站结构实现
    // 此处为框架代码，具体解析规则待目标站点分析后补充
    try {
      if (responseData is String) {
        // HTML 解析逻辑（需结合 html 包的 Document.parse）
        debugPrint('待实现：HTML 解析 ${sourceUrl.substring(0, 50.clamp(0, sourceUrl.length))}...');
      } else if (responseData is Map) {
        // JSON 数据直接解析
        debugPrint('待实现：JSON 解析');
      }
    } catch (e) {
      debugPrint('解析数据失败: $e');
    }
    return results;
  }

  /// 手动导入分数线数据（支持用户粘贴或导入 JSON）
  Future<int> importScores(List<ExamEntryScore> data) async {
    final rows = data.map((s) => s.toDb()).toList();
    await _db.batchUpsertEntryScores(rows);
    await loadScores();
    return rows.length;
  }
}
