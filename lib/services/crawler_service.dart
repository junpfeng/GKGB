import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../db/database_helper.dart';
import 'match_service.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 抓取报告
class CrawlReport {
  final int totalSources;
  final int successSources;
  final int failedSources;
  final int newPolicies;
  final int newPositions;
  final List<String> errors;

  const CrawlReport({
    this.totalSources = 0,
    this.successSources = 0,
    this.failedSources = 0,
    this.newPolicies = 0,
    this.newPositions = 0,
    this.errors = const [],
  });
}

/// 目标站点配置（硬编码常量）
class CrawlSiteConfig {
  final String name;
  final String province;
  final String? city;
  final String baseUrl;
  final String listPath;
  final String policyType;

  const CrawlSiteConfig({
    required this.name,
    required this.province,
    this.city,
    required this.baseUrl,
    required this.listPath,
    this.policyType = 'rencaiyinjin',
  });

  /// 完整列表页 URL
  String get listUrl {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final path = listPath.startsWith('/') ? listPath : '/$listPath';
    return '$base$path';
  }
}

/// 公告抓取服务
/// 内置江浙沪皖鲁五省 70+ 政府人社网站配置
/// 通用爬虫 + AI 智能解析
class CrawlerService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LlmManager _llmManager;
  final MatchService _matchService;

  // Dio 实例
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

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

  // ===== 站点配置（五省 67+ 站点） =====

  static const List<CrawlSiteConfig> _allSites = [
    // ===== 江苏省（15站） =====
    CrawlSiteConfig(
      name: '江苏省人力资源和社会保障厅',
      province: '江苏',
      baseUrl: 'https://jshrss.jiangsu.gov.cn',
      listPath: '/col/col78503/index.html',
    ),
    CrawlSiteConfig(
      name: '江苏省人事考试网',
      province: '江苏',
      baseUrl: 'https://jshrss.jiangsu.gov.cn',
      listPath: '/col/col57253/index.html',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '南京市人力资源和社会保障局',
      province: '江苏', city: '南京',
      baseUrl: 'https://rsj.nanjing.gov.cn',
      listPath: '/njsrsj/ggtz/index.html',
    ),
    CrawlSiteConfig(
      name: '苏州市人力资源和社会保障局',
      province: '江苏', city: '苏州',
      baseUrl: 'https://hrss.suzhou.gov.cn',
      listPath: '/szrskszl/index.shtml',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '无锡市人力资源和社会保障局',
      province: '江苏', city: '无锡',
      baseUrl: 'https://hrss.wuxi.gov.cn',
      listPath: '/ztzl/wxrskszl/index.shtml',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '常州市人力资源和社会保障局',
      province: '江苏', city: '常州',
      baseUrl: 'https://rsj.changzhou.gov.cn',
      listPath: '/rsj/zwdt/gsgg/index.shtml',
    ),
    CrawlSiteConfig(
      name: '镇江市人力资源和社会保障局',
      province: '江苏', city: '镇江',
      baseUrl: 'https://hrss.zhenjiang.gov.cn',
      listPath: '/hrss/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '扬州市人力资源和社会保障局',
      province: '江苏', city: '扬州',
      baseUrl: 'http://hrss.yangzhou.gov.cn',
      listPath: '/hrss/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '南通市人力资源和社会保障局',
      province: '江苏', city: '南通',
      baseUrl: 'https://rsj.nantong.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '泰州市人力资源和社会保障局',
      province: '江苏', city: '泰州',
      baseUrl: 'https://rsj.taizhou.gov.cn',
      listPath: '/xwzx/gsgg/index.html',
    ),
    CrawlSiteConfig(
      name: '盐城市人力资源和社会保障局',
      province: '江苏', city: '盐城',
      baseUrl: 'https://jsychrss.yancheng.gov.cn',
      listPath: '/jsychrss/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '徐州市人力资源和社会保障局',
      province: '江苏', city: '徐州',
      baseUrl: 'https://hrss.xz.gov.cn',
      listPath: '/xzhrss/tzgg/index.shtml',
    ),
    CrawlSiteConfig(
      name: '淮安市人力资源和社会保障局',
      province: '江苏', city: '淮安',
      baseUrl: 'https://rsj.huaian.gov.cn',
      listPath: '/harsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '连云港市人力资源和社会保障局',
      province: '江苏', city: '连云港',
      baseUrl: 'http://rsj.lyg.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '宿迁市人力资源和社会保障局',
      province: '江苏', city: '宿迁',
      baseUrl: 'http://sqhrss.suqian.gov.cn',
      listPath: '/sqhrss/tzgg/index.html',
    ),

    // ===== 浙江省（13站） =====
    CrawlSiteConfig(
      name: '浙江省人力资源和社会保障厅',
      province: '浙江',
      baseUrl: 'https://rlsbt.zj.gov.cn',
      listPath: '/col/col1229639379/index.html',
    ),
    CrawlSiteConfig(
      name: '浙江省人事考试网',
      province: '浙江',
      baseUrl: 'http://zjks.rlsbt.zj.gov.cn',
      listPath: '/col/col1229635545/index.html',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '杭州市人力资源和社会保障局',
      province: '浙江', city: '杭州',
      baseUrl: 'https://hrss.hangzhou.gov.cn',
      listPath: '/col/col1229440651/index.html',
    ),
    CrawlSiteConfig(
      name: '宁波市人力资源和社会保障局',
      province: '浙江', city: '宁波',
      baseUrl: 'http://rsj.ningbo.gov.cn',
      listPath: '/col/col1229676729/index.html',
    ),
    CrawlSiteConfig(
      name: '温州市人力资源和社会保障局',
      province: '浙江', city: '温州',
      baseUrl: 'https://hrss.wenzhou.gov.cn',
      listPath: '/col/col1229398655/index.html',
    ),
    CrawlSiteConfig(
      name: '嘉兴市人力资源和社会保障局',
      province: '浙江', city: '嘉兴',
      baseUrl: 'https://rlsbj.jiaxing.gov.cn',
      listPath: '/col/col1229850734/index.html',
    ),
    CrawlSiteConfig(
      name: '湖州市人力资源和社会保障局',
      province: '浙江', city: '湖州',
      baseUrl: 'https://hrss.huzhou.gov.cn',
      listPath: '/hzgov/front/s33/col/col6/index.html',
    ),
    CrawlSiteConfig(
      name: '绍兴市人力资源和社会保障局',
      province: '浙江', city: '绍兴',
      baseUrl: 'https://rsj.sx.gov.cn',
      listPath: '/col/col1630531/index.html',
    ),
    CrawlSiteConfig(
      name: '金华市人力资源和社会保障局',
      province: '浙江', city: '金华',
      baseUrl: 'http://rsj.jinhua.gov.cn',
      listPath: '/col/col69914/index.html',
    ),
    CrawlSiteConfig(
      name: '衢州市人力资源和社会保障局',
      province: '浙江', city: '衢州',
      baseUrl: 'http://rsj.qz.gov.cn',
      listPath: '/col/col1229091574/index.html',
    ),
    CrawlSiteConfig(
      name: '舟山市人力资源和社会保障局',
      province: '浙江', city: '舟山',
      baseUrl: 'https://zsrls.zhoushan.gov.cn',
      listPath: '/col/col1229284979/index.html',
    ),
    CrawlSiteConfig(
      name: '台州市人力资源和社会保障局',
      province: '浙江', city: '台州',
      baseUrl: 'https://rsj.zjtz.gov.cn',
      listPath: '/col/col1229396688/index.html',
    ),
    CrawlSiteConfig(
      name: '丽水市人力资源和社会保障局',
      province: '浙江', city: '丽水',
      baseUrl: 'http://rsj.lishui.gov.cn',
      listPath: '/col/col1229330697/index.html',
    ),

    // ===== 上海（3站） =====
    CrawlSiteConfig(
      name: '上海市人力资源和社会保障局',
      province: '上海',
      baseUrl: 'https://rsj.sh.gov.cn',
      listPath: '/trsks_17824/index.html',
    ),
    CrawlSiteConfig(
      name: '上海市职业能力考试院',
      province: '上海',
      baseUrl: 'https://rsj.sh.gov.cn',
      listPath: '/trsks_17824/index.html',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '21世纪人才网',
      province: '上海',
      baseUrl: 'http://www.21cnhr.gov.cn',
      listPath: '/sydwzp/index.html',
    ),

    // ===== 安徽省（18站） =====
    CrawlSiteConfig(
      name: '安徽省人力资源和社会保障厅',
      province: '安徽',
      baseUrl: 'https://hrss.ah.gov.cn',
      listPath: '/zxzx/ztzl/ahssydwgkzp/index.html',
    ),
    CrawlSiteConfig(
      name: '安徽省人事考试网',
      province: '安徽',
      baseUrl: 'http://www.apta.gov.cn',
      listPath: '/pages/RegionalManagement/ExamNotice.html',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '合肥市人力资源和社会保障局',
      province: '安徽', city: '合肥',
      baseUrl: 'http://rsj.hefei.gov.cn',
      listPath: '/xxfb/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '芜湖市人力资源和社会保障局',
      province: '安徽', city: '芜湖',
      baseUrl: 'https://rsj.wuhu.gov.cn',
      listPath: '/zwgk/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '蚌埠市人力资源和社会保障局',
      province: '安徽', city: '蚌埠',
      baseUrl: 'http://rsj.bengbu.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '淮南市人力资源和社会保障局',
      province: '安徽', city: '淮南',
      baseUrl: 'https://rsj.huainan.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '马鞍山市人力资源和社会保障局',
      province: '安徽', city: '马鞍山',
      baseUrl: 'https://rsj.mas.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '淮北市人力资源和社会保障局',
      province: '安徽', city: '淮北',
      baseUrl: 'https://rsj.huaibei.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '铜陵市人力资源和社会保障局',
      province: '安徽', city: '铜陵',
      baseUrl: 'https://rsj.tl.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '安庆市人力资源和社会保障局',
      province: '安徽', city: '安庆',
      baseUrl: 'https://rsj.anqing.gov.cn',
      listPath: '/xxfb/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '黄山市人力资源和社会保障局',
      province: '安徽', city: '黄山',
      baseUrl: 'https://rsj.huangshan.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '阜阳市人力资源和社会保障局',
      province: '安徽', city: '阜阳',
      baseUrl: 'http://rsj.fy.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '宿州市人力资源和社会保障局',
      province: '安徽', city: '宿州',
      baseUrl: 'https://rsj.ahsz.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '滁州市人力资源和社会保障局',
      province: '安徽', city: '滁州',
      baseUrl: 'https://rsj.chuzhou.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '六安市人力资源和社会保障局',
      province: '安徽', city: '六安',
      baseUrl: 'https://rsj.luan.gov.cn',
      listPath: '/rsgz/rsks/index.html',
    ),
    CrawlSiteConfig(
      name: '亳州市人力资源和社会保障局',
      province: '安徽', city: '亳州',
      baseUrl: 'https://rsj.bozhou.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '池州市人力资源和社会保障局',
      province: '安徽', city: '池州',
      baseUrl: 'https://czsrsj.chizhou.gov.cn',
      listPath: '/czsrsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '宣城市人力资源和社会保障局',
      province: '安徽', city: '宣城',
      baseUrl: 'https://rsj.xuancheng.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),

    // ===== 山东省（18站） =====
    CrawlSiteConfig(
      name: '山东省人力资源和社会保障厅',
      province: '山东',
      baseUrl: 'http://hrss.shandong.gov.cn',
      listPath: '/channels/ch03577/',
    ),
    CrawlSiteConfig(
      name: '山东人事考试信息网',
      province: '山东',
      baseUrl: 'http://hrss.shandong.gov.cn',
      listPath: '/rsks/',
      policyType: 'shiyebian',
    ),
    CrawlSiteConfig(
      name: '济南市人力资源和社会保障局',
      province: '山东', city: '济南',
      baseUrl: 'https://jnhrss.jinan.gov.cn',
      listPath: '/col/col41069/',
    ),
    CrawlSiteConfig(
      name: '青岛市人力资源和社会保障局',
      province: '山东', city: '青岛',
      baseUrl: 'https://hrss.qingdao.gov.cn',
      listPath: '/n32561948/index.html',
    ),
    CrawlSiteConfig(
      name: '烟台市人力资源和社会保障局',
      province: '山东', city: '烟台',
      baseUrl: 'https://rshj.yantai.gov.cn',
      listPath: '/col/col11737/index.html',
    ),
    CrawlSiteConfig(
      name: '潍坊市人力资源和社会保障局',
      province: '山东', city: '潍坊',
      baseUrl: 'http://rsj.weifang.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '淄博市人力资源和社会保障局',
      province: '山东', city: '淄博',
      baseUrl: 'https://hrss.zibo.gov.cn',
      listPath: '/col/col2387/index.html',
    ),
    CrawlSiteConfig(
      name: '济宁市人力资源和社会保障局',
      province: '山东', city: '济宁',
      baseUrl: 'http://hrss.jining.gov.cn',
      listPath: '/col/col25917/index.html',
    ),
    CrawlSiteConfig(
      name: '临沂市人力资源和社会保障局',
      province: '山东', city: '临沂',
      baseUrl: 'http://rsj.linyi.gov.cn',
      listPath: '/index/rdjj/25.htm',
    ),
    CrawlSiteConfig(
      name: '泰安市人力资源和社会保障局',
      province: '山东', city: '泰安',
      baseUrl: 'https://rsj.taian.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '威海市人力资源和社会保障局',
      province: '山东', city: '威海',
      baseUrl: 'https://rsj.weihai.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '日照市人力资源和社会保障局',
      province: '山东', city: '日照',
      baseUrl: 'http://hrss.rizhao.gov.cn',
      listPath: '/col/col15629/index.html',
    ),
    CrawlSiteConfig(
      name: '德州市人力资源和社会保障局',
      province: '山东', city: '德州',
      baseUrl: 'http://rsj.dezhou.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '聊城市人力资源和社会保障局',
      province: '山东', city: '聊城',
      baseUrl: 'http://rsj.liaocheng.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '滨州市人力资源和社会保障局',
      province: '山东', city: '滨州',
      baseUrl: 'http://rsj.binzhou.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '菏泽市人力资源和社会保障局',
      province: '山东', city: '菏泽',
      baseUrl: 'http://rsj.heze.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '东营市人力资源和社会保障局',
      province: '山东', city: '东营',
      baseUrl: 'http://rsj.dongying.gov.cn',
      listPath: '/rsj/tzgg/index.html',
    ),
    CrawlSiteConfig(
      name: '枣庄市人力资源和社会保障局',
      province: '山东', city: '枣庄',
      baseUrl: 'http://zzhrss.zaozhuang.gov.cn',
      listPath: '/zzhrss/tzgg/index.html',
    ),
  ];

  /// 获取所有省份列表
  static List<String> get provinces => ['江苏', '浙江', '上海', '安徽', '山东'];

  /// 按省份获取站点
  static List<CrawlSiteConfig> getSitesByProvince(String province) {
    return _allSites.where((s) => s.province == province).toList();
  }

  /// 站点总数
  static int get totalSiteCount => _allSites.length;

  // ===== 初始化站点数据到数据库 =====

  /// 将内置站点配置同步到 crawl_sources 表
  Future<void> initSources() async {
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
    return _crawlSites(_allSites);
  }

  /// 抓取指定省份
  Future<CrawlReport> crawlProvince(String province) async {
    final sites = getSitesByProvince(province);
    if (sites.isEmpty) {
      return const CrawlReport(errors: ['未找到该省份的站点配置']);
    }
    return _crawlSites(sites);
  }

  /// 取消抓取
  Future<void> cancelCrawl() async {
    _cancelRequested = true;
    notifyListeners();
  }

  // ===== 核心抓取逻辑 =====

  Future<CrawlReport> _crawlSites(List<CrawlSiteConfig> sites) async {
    if (_isCrawling) {
      return const CrawlReport(errors: ['已有抓取任务在进行中']);
    }

    _isCrawling = true;
    _cancelRequested = false;
    _policiesFound = 0;
    _progress = 0.0;
    _currentStatus = '准备开始抓取...';
    notifyListeners();

    int successSources = 0;
    int failedSources = 0;
    int newPolicies = 0;
    int newPositions = 0;
    final errors = <String>[];

    for (int i = 0; i < sites.length; i++) {
      if (_cancelRequested) {
        _currentStatus = '已取消抓取';
        break;
      }

      final site = sites[i];
      _progress = i / sites.length;
      _currentStatus = '正在抓取: ${site.province} ${site.city ?? ''} - ${site.name}';
      notifyListeners();

      try {
        final result = await _crawlSingleSite(site);
        newPolicies += result['policies'] as int;
        newPositions += result['positions'] as int;
        _policiesFound = newPolicies;
        successSources++;

        // 更新数据库中站点状态
        await _updateSourceStatus(site, 'success');
      } catch (e) {
        failedSources++;
        final errorMsg = '${site.name}: $e';
        errors.add(errorMsg);
        debugPrint('抓取失败 - $errorMsg');

        // 更新数据库中站点状态
        await _updateSourceStatus(site, 'failed');
      }

      // 请求间隔 ≥2s（宪法要求）
      if (i < sites.length - 1 && !_cancelRequested) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    _isCrawling = false;
    _progress = 1.0;
    _currentStatus = _cancelRequested
        ? '已取消 - 已抓取 $newPolicies 条公告'
        : '抓取完成 - 共 $newPolicies 条新公告, $newPositions 个岗位';
    notifyListeners();

    // 刷新 MatchService 中的公告列表
    await _matchService.loadPolicies();

    return CrawlReport(
      totalSources: sites.length,
      successSources: successSources,
      failedSources: failedSources,
      newPolicies: newPolicies,
      newPositions: newPositions,
      errors: errors,
    );
  }

  /// 抓取单个站点
  Future<Map<String, int>> _crawlSingleSite(CrawlSiteConfig site) async {
    int policiesAdded = 0;
    int positionsAdded = 0;

    // 1. 获取列表页 HTML
    final listHtml = await _fetchPage(site.listUrl);
    if (listHtml.isEmpty) {
      throw Exception('列表页内容为空');
    }

    // 2. 提取公告链接
    final links = _extractAnnouncementLinks(listHtml, site.baseUrl);

    // 3. 如果启发式提取失败，用 AI 回退
    final announcementLinks = links.isNotEmpty ? links : await _aiExtractLinks(listHtml, site.baseUrl);

    if (announcementLinks.isEmpty) {
      debugPrint('${site.name}: 未找到公告链接');
      return {'policies': 0, 'positions': 0};
    }

    // 4. 逐个处理公告链接（最多取前 10 条避免过量）
    final toProcess = announcementLinks.take(10).toList();
    for (final link in toProcess) {
      if (_cancelRequested) break;

      try {
        final result = await _processAnnouncementLink(
          link['url']!,
          link['title'] ?? '',
          site,
        );
        if (result != null) {
          policiesAdded += result['policies'] as int;
          positionsAdded += result['positions'] as int;
          _policiesFound = _policiesFound + (result['policies'] as int);
          notifyListeners();
        }

        // 请求间隔 ≥2s
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('处理公告链接失败 ${link['url']}: $e');
      }
    }

    return {'policies': policiesAdded, 'positions': positionsAdded};
  }

  /// 获取页面 HTML
  Future<String> _fetchPage(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      // 尝试自动检测编码
      final bytes = response.data as List<int>;
      try {
        return utf8.decode(bytes);
      } catch (_) {
        // 尝试 GBK / GB2312（中国政府网站常用）
        return String.fromCharCodes(bytes);
      }
    } catch (e) {
      debugPrint('页面获取失败 $url: $e');
      return '';
    }
  }

  /// 启发式提取公告链接（关键词匹配 <a> 标签）
  List<Map<String, String>> _extractAnnouncementLinks(String html, String baseUrl) {
    final document = html_parser.parse(html);
    final links = <Map<String, String>>[];
    final seen = <String>{};

    // 人才引进/事业编招聘相关关键词
    const keywords = ['公告', '招聘', '引进', '人才', '事业单位', '事业编', '选调', '招录'];

    for (final a in document.querySelectorAll('a')) {
      final href = a.attributes['href'];
      final text = a.text.trim();

      if (href == null || href.isEmpty || text.isEmpty) continue;
      if (text.length < 4 || text.length > 200) continue;

      // 检查标题是否包含关键词
      final hasKeyword = keywords.any((kw) => text.contains(kw));
      if (!hasKeyword) continue;

      // 规范化 URL
      final fullUrl = _normalizeUrl(href, baseUrl);
      if (fullUrl == null) continue;

      // 去重
      if (seen.contains(fullUrl)) continue;
      seen.add(fullUrl);

      links.add({'url': fullUrl, 'title': text});
    }

    return links;
  }

  /// AI 回退：分析页面结构提取公告链接
  Future<List<Map<String, String>>> _aiExtractLinks(String html, String baseUrl) async {
    try {
      // 截断 HTML 防止超限
      final document = html_parser.parse(html);
      document.querySelectorAll('script, style').forEach((el) => el.remove());
      final cleanHtml = document.body?.innerHtml ?? '';
      final truncated = cleanHtml.length > 4000
          ? cleanHtml.substring(0, 4000)
          : cleanHtml;

      final prompt = '''
从以下政府网站HTML片段中，提取所有与人才引进、事业单位招聘、公开招录相关的公告链接。
以 JSON 数组格式返回，每项包含 url 和 title 字段。
只返回 JSON 数组，不要其他文字。
如果没有找到相关链接，返回空数组 []。

基础 URL: $baseUrl

HTML 片段:
$truncated
''';

      final result = await _llmManager.chat([
        ChatMessage(role: 'user', content: prompt),
      ]);

      final jsonStart = result.indexOf('[');
      final jsonEnd = result.lastIndexOf(']') + 1;
      if (jsonStart < 0 || jsonEnd <= jsonStart) return [];

      final List<dynamic> items = jsonDecode(result.substring(jsonStart, jsonEnd));
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final url = _normalizeUrl(map['url'] as String? ?? '', baseUrl);
        return {
          'url': url ?? '',
          'title': map['title'] as String? ?? '',
        };
      }).where((m) => m['url']!.isNotEmpty).toList();
    } catch (e) {
      debugPrint('AI 提取链接失败: $e');
      return [];
    }
  }

  /// 处理单个公告链接
  Future<Map<String, int>?> _processAnnouncementLink(
    String url,
    String linkTitle,
    CrawlSiteConfig site,
  ) async {
    // 去重检查（按 URL）
    final existingPolicies = await _db.queryPolicies();
    for (final row in existingPolicies) {
      if (row['source_url'] == url) return null; // 已存在
    }

    // 获取详情页 HTML
    final detailHtml = await _fetchPage(url);
    if (detailHtml.isEmpty) return null;

    // 提取正文文本
    final document = html_parser.parse(detailHtml);
    document.querySelectorAll('script, style, nav, header, footer').forEach(
      (el) => el.remove(),
    );
    final bodyText = document.body?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';

    if (bodyText.length < 50) return null; // 内容太短，跳过

    // 截断防止超限
    final truncated = bodyText.length > 3000
        ? bodyText.substring(0, 3000)
        : bodyText;

    // AI 解析公告基本信息
    String title = linkTitle.isNotEmpty ? linkTitle : '抓取的公告';
    String? province = site.province;
    String? city = site.city;
    String? policyType = site.policyType == 'shiyebian' ? '事业编招聘' : '人才引进';
    String? deadline;

    try {
      final infoPrompt = '''
从以下政府公告网页内容中提取基本信息，以 JSON 格式返回：
{
  "title": "公告标题（完整标题）",
  "province": "省份",
  "city": "城市",
  "policy_type": "公告类型（人才引进/事业编招聘/选调生/其他）",
  "deadline": "报名截止日期（如有，格式YYYY-MM-DD）"
}
只返回 JSON，不要其他文字。

网页内容：
$truncated
''';

      final infoResult = await _llmManager.chat([
        ChatMessage(role: 'user', content: infoPrompt),
      ]);
      final jsonStart = infoResult.indexOf('{');
      final jsonEnd = infoResult.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final map = jsonDecode(infoResult.substring(jsonStart, jsonEnd)) as Map;
        title = map['title'] as String? ?? title;
        province = map['province'] as String? ?? province;
        city = map['city'] as String? ?? city;
        policyType = map['policy_type'] as String? ?? policyType;
        deadline = map['deadline'] as String?;
      }
    } catch (e) {
      debugPrint('AI 解析公告基本信息失败: $e');
    }

    // 去重检查（按 title+province+city）
    final policy = await _matchService.addPolicyIfNotExists(
      title: title,
      province: province,
      city: city,
      policyType: policyType,
      content: truncated,
      deadline: deadline,
    );

    if (policy == null) return null; // 重复

    // 更新 source_url
    if (policy.id != null) {
      await _db.updatePolicy(policy.id!, {'source_url': url});
    }

    // AI 解析岗位（如果公告内容足够长）
    int positionsCount = 0;
    if (truncated.length > 200) {
      try {
        final positions = await _matchService.aiParsePolicy(policy);
        positionsCount = positions.length;
      } catch (e) {
        debugPrint('AI 解析岗位失败: $e');
      }
    }

    return {'policies': 1, 'positions': positionsCount};
  }

  /// URL 规范化：处理相对路径
  String? _normalizeUrl(String href, String baseUrl) {
    if (href.isEmpty) return null;
    if (href.startsWith('javascript:') || href.startsWith('#') || href.startsWith('mailto:')) {
      return null;
    }
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('//')) {
      return 'http:$href';
    }

    // 相对路径
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (href.startsWith('/')) {
      // 提取 scheme + host
      final uri = Uri.tryParse(base);
      if (uri == null) return null;
      return '${uri.scheme}://${uri.host}$href';
    }

    // 相对当前目录
    return '$base/$href';
  }

  /// 更新站点抓取状态到数据库
  Future<void> _updateSourceStatus(CrawlSiteConfig site, String status) async {
    try {
      final sources = await _db.queryCrawlSources(province: site.province, enabledOnly: false);
      for (final source in sources) {
        if (source['base_url'] == site.baseUrl && source['list_path'] == site.listPath) {
          await _db.updateCrawlSource(source['id'] as int, {
            'status': status,
            'last_crawled_at': DateTime.now().toIso8601String(),
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('更新站点状态失败: $e');
    }
  }
}
