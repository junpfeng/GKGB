import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:exam_prep_app/services/crawler_core.dart';

/// 公告抓取 CLI 工具
/// 用法: dart run bin/crawler_tool.dart [选项]
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('all', abbr: 'a', help: '抓取全部五省站点', negatable: false)
    ..addOption('province', abbr: 'p', help: '指定省份抓取（逗号分隔，如：江苏,浙江）')
    ..addFlag('list', abbr: 'l', help: '列出所有站点配置', negatable: false)
    ..addFlag('show', abbr: 's', help: '查看已抓取的公告', negatable: false)
    ..addFlag('stats', help: '统计概览', negatable: false)
    ..addOption('export', abbr: 'e', help: '导出数据（json 或 csv）', allowed: ['json', 'csv'])
    ..addOption('db-path', help: '数据库文件路径（默认自动检测）')
    ..addFlag('help', abbr: 'h', help: '显示帮助', negatable: false);

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('参数错误: $e');
    _printUsage(parser);
    exit(1);
  }

  if (args['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  // 站点配置 JSON 路径
  final scriptDir = _getScriptDir();
  final sitesJsonPath = _findSitesJson(scriptDir);
  if (sitesJsonPath == null) {
    print('错误: 找不到 crawl_sites.json 配置文件');
    exit(1);
  }

  // --list: 仅列出站点，不需要数据库
  if (args['list'] as bool) {
    await _listSites(sitesJsonPath);
    exit(0);
  }

  // 初始化 sqflite_common_ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 数据库路径
  final dbPath = args['db-path'] as String? ?? _detectDbPath();
  if (dbPath == null) {
    print('错误: 无法自动检测数据库路径，请使用 --db-path 指定');
    exit(1);
  }
  print('数据库路径: $dbPath');

  // 检查数据库文件是否存在
  if (!File(dbPath).existsSync()) {
    print('警告: 数据库文件不存在，将创建新数据库: $dbPath');
  }

  // 打开数据库
  final db = await databaseFactoryFfi.openDatabase(dbPath);

  // 确保表存在
  await _ensureTables(db);

  // 需要 LLM 的命令检查环境变量
  final needsLlm = (args['all'] as bool) || (args['province'] != null);

  String apiKey = '';
  String llmBaseUrl = '';
  String model = '';

  if (needsLlm) {
    apiKey = Platform.environment['LLM_API_KEY'] ?? '';
    llmBaseUrl = Platform.environment['LLM_BASE_URL'] ?? '';
    model = Platform.environment['LLM_MODEL'] ?? 'gpt-4o-mini';

    if (apiKey.isEmpty || llmBaseUrl.isEmpty) {
      print('错误: 抓取功能需要设置环境变量:');
      print('  LLM_API_KEY  — LLM API Key');
      print('  LLM_BASE_URL — LLM API Base URL (如 https://api.deepseek.com/v1)');
      print('  LLM_MODEL    — 模型名（可选，默认 gpt-4o-mini）');
      await db.close();
      exit(1);
    }
  }

  // 创建 Dio 实例
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  // 创建 CrawlerCore
  final core = CrawlerCore(
    dio,
    db,
    apiKey: apiKey,
    baseUrl: llmBaseUrl,
    model: model,
  );

  // 加载站点配置
  await core.loadSitesFromFile(sitesJsonPath);

  try {
    if (args['all'] as bool) {
      // 抓取全部
      print('开始抓取全部 ${core.sites.length} 个站点...\n');
      final report = await core.crawlAll(onProgress: (msg) {
        // onProgress 回调，print 已在 core 内部做了
      });
      _printReport(report);
    } else if (args['province'] != null) {
      // 抓取指定省份
      final provinces = (args['province'] as String).split(',').map((s) => s.trim()).toList();
      for (final province in provinces) {
        print('开始抓取: $province\n');
        final report = await core.crawlProvince(province, onProgress: (msg) {});
        _printReport(report);
        print('');
      }
    } else if (args['show'] as bool) {
      // 查看公告
      final province = args['province'] as String?;
      final policies = await core.queryPolicies(province: province);
      if (policies.isEmpty) {
        print('暂无公告数据');
      } else {
        print('共 ${policies.length} 条公告:\n');
        for (final p in policies) {
          print('  [${p['id']}] ${p['title']}');
          print('      省份: ${p['province'] ?? '-'}  城市: ${p['city'] ?? '-'}  类型: ${p['policy_type'] ?? '-'}');
          if (p['source_url'] != null) {
            print('      链接: ${p['source_url']}');
          }
          print('      时间: ${p['created_at'] ?? '-'}');
          print('');
        }
      }
    } else if (args['stats'] as bool) {
      // 统计
      final stats = await core.getStats();
      print('=== 抓取统计 ===');
      print('公告总数: ${stats['total_policies']}');
      print('站点总数: ${stats['total_sources']}（成功: ${stats['success_sources']}）');
      print('\n按省份分布:');
      for (final row in stats['by_province'] as List) {
        print('  ${row['province']}: ${row['cnt']} 条');
      }
      print('\n按类型分布:');
      for (final row in stats['by_type'] as List) {
        print('  ${row['policy_type'] ?? '未知'}: ${row['cnt']} 条');
      }
    } else if (args['export'] != null) {
      // 导出
      final format = args['export'] as String;
      final province = args['province'] as String?;
      if (format == 'json') {
        final json = await core.exportJson(province: province);
        final fileName = 'policies_export_${DateTime.now().millisecondsSinceEpoch}.json';
        File(fileName).writeAsStringSync(json);
        print('已导出到: $fileName');
      } else {
        final csv = await core.exportCsv(province: province);
        final fileName = 'policies_export_${DateTime.now().millisecondsSinceEpoch}.csv';
        File(fileName).writeAsStringSync(csv);
        print('已导出到: $fileName');
      }
    } else {
      _printUsage(parser);
    }
  } finally {
    await db.close();
  }
}

void _printUsage(ArgParser parser) {
  print('公告抓取 CLI 工具\n');
  print('用法: dart run bin/crawler_tool.dart [选项]\n');
  print('环境变量:');
  print('  LLM_API_KEY   LLM API Key（抓取时必须）');
  print('  LLM_BASE_URL  LLM API Base URL（抓取时必须）');
  print('  LLM_MODEL     模型名（可选，默认 gpt-4o-mini）\n');
  print('选项:');
  print(parser.usage);
  print('\n示例:');
  print('  dart run bin/crawler_tool.dart --list');
  print('  dart run bin/crawler_tool.dart --all');
  print('  dart run bin/crawler_tool.dart --province 江苏,浙江');
  print('  dart run bin/crawler_tool.dart --show');
  print('  dart run bin/crawler_tool.dart --stats');
  print('  dart run bin/crawler_tool.dart --export json');
}

void _printReport(CrawlReport report) {
  print('\n=== 抓取报告 ===');
  print('站点总数: ${report.totalSources}');
  print('成功: ${report.successSources}');
  print('失败: ${report.failedSources}');
  print('新增公告: ${report.newPolicies}');
  print('新增岗位: ${report.newPositions}');
  if (report.errors.isNotEmpty) {
    print('\n错误列表:');
    for (final e in report.errors) {
      print('  - $e');
    }
  }
}

/// 获取脚本所在目录
String _getScriptDir() {
  // 运行 dart run bin/crawler_tool.dart 时，当前目录是项目根目录
  return Directory.current.path;
}

/// 查找 crawl_sites.json
String? _findSitesJson(String projectDir) {
  // 优先查找 tool/crawl_sites.json
  final toolPath = '$projectDir/tool/crawl_sites.json';
  if (File(toolPath).existsSync()) return toolPath;

  // 备选：assets/config/crawl_sites.json
  final assetsPath = '$projectDir/assets/config/crawl_sites.json';
  if (File(assetsPath).existsSync()) return assetsPath;

  return null;
}

/// 自动检测 App 数据库路径
String? _detectDbPath() {
  if (Platform.isWindows) {
    // Windows: %APPDATA%\com.example\exam_prep_app\databases\exam_prep.db
    // 或 sqflite_common_ffi 默认路径
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      // 尝试多种可能路径
      final candidates = [
        '$appData/com.example/exam_prep_app/databases/exam_prep.db',
        '$appData/../exam_prep_app/databases/exam_prep.db',
        '${Directory.current.path}/exam_prep.db',
      ];
      for (final path in candidates) {
        final normalized = path.replaceAll('\\', '/');
        if (File(normalized).existsSync()) {
          return normalized;
        }
      }

      // 使用 sqflite_common_ffi 默认路径（当前目录）
      final defaultPath = '${Directory.current.path}/exam_prep.db';
      return defaultPath;
    }
  } else if (Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final candidates = [
        '$home/.local/share/exam_prep_app/exam_prep.db',
        '${Directory.current.path}/exam_prep.db',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
      return '${Directory.current.path}/exam_prep.db';
    }
  }

  return '${Directory.current.path}/exam_prep.db';
}

/// 列出所有站点
Future<void> _listSites(String sitesJsonPath) async {
  final jsonStr = File(sitesJsonPath).readAsStringSync();
  final List<dynamic> sites = jsonDecode(jsonStr);

  // 按省份分组
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final site in sites) {
    final province = site['province'] as String;
    grouped.putIfAbsent(province, () => []).add(site as Map<String, dynamic>);
  }

  print('共 ${sites.length} 个站点:\n');
  for (final entry in grouped.entries) {
    print('=== ${entry.key}（${entry.value.length}个站点） ===');
    for (final site in entry.value) {
      final city = site['city'] as String?;
      final cityStr = city != null ? ' ($city)' : '';
      print('  ${site['name']}$cityStr');
      print('    ${site['base_url']}${site['list_path']}');
      print('    类型: ${site['policy_type']}');
    }
    print('');
  }
}

/// 确保数据库表存在
Future<void> _ensureTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS talent_policies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      province TEXT,
      city TEXT,
      policy_type TEXT,
      content TEXT,
      source_url TEXT,
      deadline TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS crawl_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      province TEXT,
      city TEXT,
      base_url TEXT,
      list_path TEXT,
      policy_type TEXT,
      status TEXT DEFAULT 'pending',
      enabled INTEGER DEFAULT 1,
      last_crawled_at TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
}
