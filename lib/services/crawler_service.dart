import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import '../db/database_helper.dart';
import 'match_service.dart';
import 'llm/llm_manager.dart';
import 'crawler_core.dart';

// 从 crawler_core.dart 重新导出，保持现有 import 不变
export 'crawler_core.dart' show CrawlSiteConfig, CrawlReport;

/// 公告抓取服务（Flutter App 层）
/// 委托 CrawlerCore 执行核心抓取逻辑，保留 ChangeNotifier 进度通知
class CrawlerService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llmManager;
  final MatchService _matchService;

  // 站点配置（从 JSON 加载）
  List<CrawlSiteConfig> _allSites = [];
  bool _sitesLoaded = false;

  // 状态
  bool _isCrawling = false;
  String _currentStatus = '';
  double _progress = 0.0;
  int _policiesFound = 0;
  bool _cancelRequested = false;

  bool get isCrawling => _isCrawling;
  String get currentStatus => _currentStatus;
  double get progress => _progress;
  int get policiesFound => _policiesFound;

  CrawlerService(this._llmManager, this._matchService);

  /// 确保站点配置已加载
  Future<void> _ensureSitesLoaded() async {
    if (_sitesLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/config/crawl_sites.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _allSites = jsonList.map((j) => CrawlSiteConfig.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('加载站点配置失败: $e');
      _allSites = [];
    }
    _sitesLoaded = true;
  }

  /// 获取所有省份列表
  static List<String> get provinces => ['江苏', '浙江', '上海', '安徽', '山东'];

  /// 按省份获取站点（需要先调用 ensureSitesLoaded）
  static List<CrawlSiteConfig> getSitesByProvince(String province) {
    // 静态方法无法访问异步加载的站点配置
    // 这里使用硬编码的省份站点数量映射，保持 UI 兼容
    return _staticSitesByProvince[province] ?? [];
  }

  /// 站点总数
  static int get totalSiteCount => 67;

  // 静态站点数据缓存（由 _loadStaticSites 填充）
  static final Map<String, List<CrawlSiteConfig>> _staticSitesByProvince = {};
  static bool _staticLoaded = false;

  /// 加载静态站点数据（App 启动时调用一次）
  static Future<void> loadStaticSites() async {
    if (_staticLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/config/crawl_sites.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final sites = jsonList.map((j) => CrawlSiteConfig.fromJson(j as Map<String, dynamic>)).toList();
      for (final site in sites) {
        _staticSitesByProvince.putIfAbsent(site.province, () => []).add(site);
      }
      _staticLoaded = true;
    } catch (e) {
      debugPrint('加载静态站点配置失败: $e');
    }
  }

  // ===== 初始化站点数据到数据库 =====

  /// 将内置站点配置同步到 crawl_sources 表
  Future<void> initSources() async {
    await _ensureSitesLoaded();
    final count = await _db.countCrawlSources();
    if (count > 0) return; // 已初始化过
    for (final site in _allSites) {
      await _db.insertCrawlSource({
        'name': site.name,
        'province': site.province,
        'city': site.city,
        'base_url': site.baseUrl,
        'list_path': site.listPath,
        'policy_type': site.policyType,
        'status': 'pending',
        'enabled': 1,
      });
    }
  }

  // ===== 抓取入口 =====

  /// 全量抓取五省
  Future<CrawlReport> crawlAllProvinces() async {
    await _ensureSitesLoaded();
    return _crawlWithCore(_allSites);
  }

  /// 抓取指定省份
  Future<CrawlReport> crawlProvince(String province) async {
    await _ensureSitesLoaded();
    final sites = _allSites.where((s) => s.province == province).toList();
    if (sites.isEmpty) {
      return const CrawlReport(errors: ['未找到该省份的站点配置']);
    }
    return _crawlWithCore(sites);
  }

  /// 取消抓取
  Future<void> cancelCrawl() async {
    _cancelRequested = true;
    _core?.cancelCrawl();
    notifyListeners();
  }

  CrawlerCore? _core;

  /// 委托 CrawlerCore 执行抓取
  Future<CrawlReport> _crawlWithCore(List<CrawlSiteConfig> sites) async {
    if (_isCrawling) {
      return const CrawlReport(errors: ['已有抓取任务在进行中']);
    }

    _isCrawling = true;
    _cancelRequested = false;
    _policiesFound = 0;
    _progress = 0.0;
    _currentStatus = '准备开始抓取...';
    notifyListeners();

    // 获取 LLM 配置
    final llmConfig = _llmManager.getActiveProviderConfig();
    final apiKey = llmConfig?['apiKey'] ?? '';
    final baseUrl = llmConfig?['baseUrl'] ?? '';
    final model = llmConfig?['model'] ?? 'gpt-4o-mini';

    // 获取数据库实例
    final db = await _db.database;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ));

    _core = CrawlerCore(
      dio,
      db,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      sites: sites,
    );

    int processedCount = 0;
    final report = await _core!.crawlAll(onProgress: (msg) {
      _currentStatus = msg;
      // 估算进度
      if (msg.startsWith('[')) {
        processedCount++;
        _progress = processedCount / sites.length;
      }
      notifyListeners();
    });

    _isCrawling = false;
    _progress = 1.0;
    _policiesFound = report.newPolicies;
    _currentStatus = _cancelRequested
        ? '已取消 - 已抓取 ${report.newPolicies} 条公告'
        : '抓取完成 - 共 ${report.newPolicies} 条新公告, ${report.newPositions} 个岗位';
    notifyListeners();

    // 刷新 MatchService 中的公告列表
    await _matchService.loadPolicies();

    _core = null;
    return report;
  }
}
