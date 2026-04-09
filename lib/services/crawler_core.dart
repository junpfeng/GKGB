import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sqflite_common/sqlite_api.dart';

/// 站点配置（纯 Dart，无 Flutter 依赖）
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

  /// 从 JSON Map 构造
  factory CrawlSiteConfig.fromJson(Map<String, dynamic> json) {
    return CrawlSiteConfig(
      name: json['name'] as String,
      province: json['province'] as String,
      city: json['city'] as String?,
      baseUrl: json['base_url'] as String,
      listPath: json['list_path'] as String,
      policyType: json['policy_type'] as String? ?? 'rencaiyinjin',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'province': province,
    'city': city,
    'base_url': baseUrl,
    'list_path': listPath,
    'policy_type': policyType,
  };

  /// 完整列表页 URL
  String get listUrl {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final path = listPath.startsWith('/') ? listPath : '/$listPath';
    return '$base$path';
  }
}

/// 抓取报告（纯 Dart，无 Flutter 依赖）
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

/// 公告抓取核心引擎（纯 Dart，无 Flutter 依赖）
///
/// 负责：HTTP 抓取、HTML 解析、链接提取、AI 解析、去重、入库
/// 不依赖 ChangeNotifier / debugPrint / rootBundle / LlmManager
class CrawlerCore {
  final Dio _dio;
  final Database _db;
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  List<CrawlSiteConfig> _sites;
  bool _cancelRequested = false;

  CrawlerCore(
    this._dio,
    this._db, {
    required String apiKey,
    required String baseUrl,
    String model = 'gpt-4o-mini',
    List<CrawlSiteConfig>? sites,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _model = model,
        _sites = sites ?? [];

  /// 从 JSON 文件加载站点配置
  Future<void> loadSitesFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('站点配置文件不存在: $filePath');
    }
    final jsonStr = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    _sites = jsonList.map((j) => CrawlSiteConfig.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 直接设置站点列表
  void setSites(List<CrawlSiteConfig> sites) {
    _sites = sites;
  }

  /// 获取所有站点
  List<CrawlSiteConfig> get sites => List.unmodifiable(_sites);

  /// 获取所有省份
  List<String> get provinces {
    final set = <String>{};
    for (final s in _sites) {
      set.add(s.province);
    }
    return set.toList();
  }

  /// 按省份获取站点
  List<CrawlSiteConfig> getSitesByProvince(String province) {
    return _sites.where((s) => s.province == province).toList();
  }

  /// 取消抓取
  void cancelCrawl() {
    _cancelRequested = true;
  }

  // ===== 抓取入口 =====

  /// 抓取全部站点
  Future<CrawlReport> crawlAll({Function(String)? onProgress}) async {
    return _crawlSites(_sites, onProgress: onProgress);
  }

  /// 抓取指定省份
  Future<CrawlReport> crawlProvince(String province, {Function(String)? onProgress}) async {
    final sites = getSitesByProvince(province);
    if (sites.isEmpty) {
      return const CrawlReport(errors: ['未找到该省份的站点配置']);
    }
    return _crawlSites(sites, onProgress: onProgress);
  }

  // ===== 核心抓取逻辑 =====

  Future<CrawlReport> _crawlSites(
    List<CrawlSiteConfig> sites, {
    Function(String)? onProgress,
  }) async {
    _cancelRequested = false;
    int successSources = 0;
    int failedSources = 0;
    int newPolicies = 0;
    int newPositions = 0;
    final errors = <String>[];

    for (int i = 0; i < sites.length; i++) {
      if (_cancelRequested) {
        onProgress?.call('已取消抓取');
        break;
      }

      final site = sites[i];
      final statusMsg = '[${i + 1}/${sites.length}] 正在抓取: ${site.province} ${site.city ?? ''} - ${site.name}';
      onProgress?.call(statusMsg);
      print(statusMsg);

      try {
        final result = await _crawlSingleSite(site, onProgress: onProgress);
        newPolicies += result['policies'] as int;
        newPositions += result['positions'] as int;
        successSources++;

        await _updateSourceStatus(site, 'success');
      } catch (e) {
        failedSources++;
        final errorMsg = '${site.name}: $e';
        errors.add(errorMsg);
        print('  抓取失败 - $errorMsg');

        await _updateSourceStatus(site, 'failed');
      }

      // 请求间隔 ≥2s（宪法要求）
      if (i < sites.length - 1 && !_cancelRequested) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    final summary = '抓取完成 - 成功 $successSources/${sites.length} 站点, '
        '新增 $newPolicies 条公告, $newPositions 个岗位';
    onProgress?.call(summary);
    print(summary);

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
  Future<Map<String, int>> _crawlSingleSite(
    CrawlSiteConfig site, {
    Function(String)? onProgress,
  }) async {
    int policiesAdded = 0;
    int positionsAdded = 0;

    // 1. 获取列表页 HTML
    final listHtml = await fetchPage(site.listUrl);
    if (listHtml.isEmpty) {
      throw Exception('列表页内容为空');
    }

    // 2. 提取公告链接
    final links = extractAnnouncementLinks(listHtml, site.baseUrl);

    // 3. 如果启发式提取失败，用 AI 回退
    final announcementLinks = links.isNotEmpty ? links : await aiExtractLinks(listHtml, site.baseUrl);

    if (announcementLinks.isEmpty) {
      print('  ${site.name}: 未找到公告链接');
      return {'policies': 0, 'positions': 0};
    }

    onProgress?.call('  找到 ${announcementLinks.length} 条公告链接');

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
        }

        // 请求间隔 ≥2s
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('  处理公告链接失败 ${link['url']}: $e');
      }
    }

    return {'policies': policiesAdded, 'positions': positionsAdded};
  }

  /// 获取页面 HTML
  Future<String> fetchPage(String url) async {
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
      print('  页面获取失败 $url: $e');
      return '';
    }
  }

  /// 启发式提取公告链接（关键词匹配 <a> 标签）
  List<Map<String, String>> extractAnnouncementLinks(String html, String baseUrl) {
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
      final fullUrl = normalizeUrl(href, baseUrl);
      if (fullUrl == null) continue;

      // 去重
      if (seen.contains(fullUrl)) continue;
      seen.add(fullUrl);

      links.add({'url': fullUrl, 'title': text});
    }

    return links;
  }

  /// AI 回退：分析页面结构提取公告链接
  Future<List<Map<String, String>>> aiExtractLinks(String html, String baseUrl) async {
    try {
      // 截断 HTML 防止超限
      final document = html_parser.parse(html);
      document.querySelectorAll('script, style').forEach((el) => el.remove());
      final cleanHtml = document.body?.innerHtml ?? '';
      final truncated = cleanHtml.length > 4000
          ? cleanHtml.substring(0, 4000)
          : cleanHtml;

      final prompt = '从以下政府网站HTML片段中，提取所有与人才引进、事业单位招聘、公开招录相关的公告链接。\n'
          '以 JSON 数组格式返回，每项包含 url 和 title 字段。\n'
          '只返回 JSON 数组，不要其他文字。\n'
          '如果没有找到相关链接，返回空数组 []。\n\n'
          '基础 URL: $baseUrl\n\n'
          'HTML 片段:\n$truncated';

      final result = await _callLlm(prompt);

      final jsonStart = result.indexOf('[');
      final jsonEnd = result.lastIndexOf(']') + 1;
      if (jsonStart < 0 || jsonEnd <= jsonStart) return [];

      final List<dynamic> items = jsonDecode(result.substring(jsonStart, jsonEnd));
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final url = normalizeUrl(map['url'] as String? ?? '', baseUrl);
        return {
          'url': url ?? '',
          'title': map['title'] as String? ?? '',
        };
      }).where((m) => m['url']!.isNotEmpty).toList();
    } catch (e) {
      print('  AI 提取链接失败: $e');
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
    final existingPolicies = await _db.query('talent_policies',
      where: 'source_url = ?',
      whereArgs: [url],
    );
    if (existingPolicies.isNotEmpty) return null;

    // 获取详情页 HTML
    final detailHtml = await fetchPage(url);
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
      final infoPrompt = '从以下政府公告网页内容中提取基本信息，以 JSON 格式返回：\n'
          '{\n'
          '  "title": "公告标题（完整标题）",\n'
          '  "province": "省份",\n'
          '  "city": "城市",\n'
          '  "policy_type": "公告类型（人才引进/事业编招聘/选调生/其他）",\n'
          '  "deadline": "报名截止日期（如有，格式YYYY-MM-DD）"\n'
          '}\n'
          '只返回 JSON，不要其他文字。\n\n'
          '网页内容：\n$truncated';

      final infoResult = await _callLlm(infoPrompt);
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
      print('  AI 解析公告基本信息失败: $e');
    }

    // 去重检查（按 title+province+city）
    final duplicateCheck = await _db.query('talent_policies',
      where: 'title = ? AND province = ? AND city = ?',
      whereArgs: [title, province ?? '', city ?? ''],
    );
    if (duplicateCheck.isNotEmpty) return null;

    // 入库
    final now = DateTime.now().toIso8601String();
    final policyId = await _db.insert('talent_policies', {
      'title': title,
      'province': province,
      'city': city,
      'policy_type': policyType,
      'content': truncated,
      'source_url': url,
      'deadline': deadline,
      'created_at': now,
      'updated_at': now,
    });

    if (policyId <= 0) return null;

    print('  新增公告: $title');
    return {'policies': 1, 'positions': 0};
  }

  /// URL 规范化：处理相对路径
  String? normalizeUrl(String href, String baseUrl) {
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
      final sources = await _db.query('crawl_sources',
        where: 'base_url = ? AND list_path = ?',
        whereArgs: [site.baseUrl, site.listPath],
      );
      for (final source in sources) {
        await _db.update('crawl_sources', {
          'status': status,
          'last_crawled_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [source['id']]);
      }
    } catch (e) {
      print('  更新站点状态失败: $e');
    }
  }

  /// 通过 Dio 直调 OpenAI 兼容 API
  Future<String> _callLlm(String prompt) async {
    final response = await _dio.post(
      '$_baseUrl/chat/completions',
      data: {
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List;
    if (choices.isEmpty) throw Exception('LLM 返回空结果');
    final message = choices[0]['message'] as Map<String, dynamic>;
    return message['content'] as String;
  }

  // ===== 查看/统计/导出 =====

  /// 查询已抓取公告
  Future<List<Map<String, dynamic>>> queryPolicies({String? province, String? city}) async {
    String? where;
    List<Object?>? whereArgs;
    if (province != null && city != null) {
      where = 'province = ? AND city = ?';
      whereArgs = [province, city];
    } else if (province != null) {
      where = 'province = ?';
      whereArgs = [province];
    }
    return _db.query('talent_policies', where: where, whereArgs: whereArgs, orderBy: 'created_at DESC');
  }

  /// 统计概览
  Future<Map<String, dynamic>> getStats() async {
    final total = (await _db.rawQuery('SELECT COUNT(*) as cnt FROM talent_policies')).first['cnt'] as int;
    final byProvince = await _db.rawQuery(
      'SELECT province, COUNT(*) as cnt FROM talent_policies GROUP BY province ORDER BY cnt DESC',
    );
    final byType = await _db.rawQuery(
      'SELECT policy_type, COUNT(*) as cnt FROM talent_policies GROUP BY policy_type ORDER BY cnt DESC',
    );
    final sourcesTotal = (await _db.rawQuery('SELECT COUNT(*) as cnt FROM crawl_sources')).first['cnt'] as int;
    final sourcesSuccess = (await _db.rawQuery(
      "SELECT COUNT(*) as cnt FROM crawl_sources WHERE status = 'success'",
    )).first['cnt'] as int;

    return {
      'total_policies': total,
      'by_province': byProvince,
      'by_type': byType,
      'total_sources': sourcesTotal,
      'success_sources': sourcesSuccess,
    };
  }

  /// 导出 JSON
  Future<String> exportJson({String? province}) async {
    final policies = await queryPolicies(province: province);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(policies);
  }

  /// 导出 CSV
  Future<String> exportCsv({String? province}) async {
    final policies = await queryPolicies(province: province);
    final buf = StringBuffer();
    buf.writeln('id,title,province,city,policy_type,source_url,deadline,created_at');
    for (final p in policies) {
      final fields = [
        p['id']?.toString() ?? '',
        _csvEscape(p['title'] as String? ?? ''),
        _csvEscape(p['province'] as String? ?? ''),
        _csvEscape(p['city'] as String? ?? ''),
        _csvEscape(p['policy_type'] as String? ?? ''),
        _csvEscape(p['source_url'] as String? ?? ''),
        _csvEscape(p['deadline'] as String? ?? ''),
        _csvEscape(p['created_at'] as String? ?? ''),
      ];
      buf.writeln(fields.join(','));
    }
    return buf.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
