// 成语数据采集脚本（开发阶段使用）
//
// 从题库 JSON 文件中提取选词填空题的四字成语，
// 然后爬取百度汉语释义和人民日报 2020-2025 例句，
// 输出到 assets/data/idioms_preset.json。
//
// 用法：
//   dart run tools/collect_idioms.dart
//
// 注意：需要联网，爬取间隔 ≥2s（遵守 robots.txt）
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
  },
));

DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

/// 限速：每次请求间隔 ≥2s
Future<void> _rateLimitWait() async {
  final elapsed = DateTime.now().difference(_lastRequestTime);
  if (elapsed < const Duration(seconds: 2)) {
    await Future.delayed(const Duration(seconds: 2) - elapsed);
  }
  _lastRequestTime = DateTime.now();
}

/// 从百度汉语获取成语释义
Future<String> fetchDefinition(String idiom) async {
  await _rateLimitWait();
  try {
    final url = 'https://hanyu.baidu.com/s?wd=${Uri.encodeComponent(idiom)}&ptype=zici';
    final response = await _dio.get(url);
    if (response.statusCode != 200) return '';

    final document = html_parser.parse(response.data);
    final meaningEl = document.querySelector('#basicmean-wrapper .tab-content')
        ?? document.querySelector('.basicmean-text')
        ?? document.querySelector('#baike-wrapper .tab-content');
    return meaningEl?.text.trim() ?? '';
  } catch (e) {
    stderr.writeln('  [WARN] 获取释义失败($idiom): $e');
    return '';
  }
}

/// 从人民日报搜索抓取例句（2020-2025 年）
Future<List<Map<String, dynamic>>> fetchPeopleDailyExamples(String idiom) async {
  await _rateLimitWait();
  final examples = <Map<String, dynamic>>[];

  try {
    final url = 'http://search.people.com.cn/cnpeople/search.do'
        '?pageNum=1'
        '&keyword=${Uri.encodeComponent(idiom)}'
        '&siteName=news'
        '&facetFlag=true'
        '&nodeType=belongsId'
        '&nodeId='
        '&beginYear=2020'
        '&endYear=2025';

    final response = await _dio.get(url);
    if (response.statusCode != 200) return examples;

    final document = html_parser.parse(response.data);
    final resultItems = document.querySelectorAll('.search_list li');

    for (final item in resultItems) {
      final summaryEl = item.querySelector('.search_list_c');
      final dateEl = item.querySelector('.search_list_d');
      final linkEl = item.querySelector('a');

      if (summaryEl == null) continue;

      final summary = summaryEl.text.trim();
      final dateText = dateEl?.text.trim() ?? '';
      final link = linkEl?.attributes['href'] ?? '';

      // 提取包含成语的句子
      final sentence = _extractSentenceContaining(summary, idiom);
      if (sentence.isEmpty) continue;

      // 解析年份
      final yearMatch = RegExp(r'(\d{4})').firstMatch(dateText);
      final year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 0;

      if (year >= 2020 && year <= 2025) {
        examples.add({
          'sentence': sentence,
          'year': year,
          'source_url': link,
        });
      }
    }
  } catch (e) {
    stderr.writeln('  [WARN] 抓取人民日报例句失败($idiom): $e');
  }

  // 按年份降序，最多 5 条
  examples.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));
  return examples.take(5).toList();
}

/// 从摘要文本中提取包含成语的完整句子
String _extractSentenceContaining(String text, String keyword) {
  if (!text.contains(keyword)) return '';

  final sentences = text.split(RegExp(r'[。！？!?]'));
  for (final s in sentences) {
    if (s.contains(keyword) && s.trim().length >= 10) {
      return '${s.trim()}。';
    }
  }
  final idx = text.indexOf(keyword);
  final start = (idx - 40).clamp(0, text.length);
  final end = (idx + keyword.length + 40).clamp(0, text.length);
  return text.substring(start, end).trim();
}

/// 从选项中提取四字成语
Set<String> extractIdiomsFromOptions(List<dynamic> options) {
  final idioms = <String>{};
  final fourCharRegex = RegExp(r'^[\u4e00-\u9fff]{4}$');

  for (final option in options) {
    final text = option.toString().replaceFirst(RegExp(r'^[A-Za-z][.．、]\s*'), '');
    final parts = text.split(RegExp(r'[、\s]+'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (fourCharRegex.hasMatch(trimmed)) {
        idioms.add(trimmed);
      }
    }
  }
  return idioms;
}

/// 判断是否为选词填空题
bool isXuanCiTianKong(Map<String, dynamic> question) {
  final category = question['category'] as String? ?? '';
  final content = question['content'] as String? ?? '';
  return ['言语理解', '言语运用'].contains(category) && content.contains('___');
}

Future<void> main() async {
  stdout.writeln('=== 成语数据采集脚本 ===\n');

  // 1. 扫描所有题库 JSON 文件，提取选词填空题中的成语
  final idiomSet = <String>{};
  final questionDirs = [
    'assets/questions',
    'assets/questions/real_exam/guokao',
    'assets/questions/real_exam/shengkao',
    'assets/questions/real_exam/shiyebian',
  ];

  for (final dir in questionDirs) {
    final directory = Directory(dir);
    if (!directory.existsSync()) continue;

    await for (final file in directory.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr);
        final questions = data is List ? data : (data['questions'] as List? ?? []);

        for (final q in questions) {
          if (q is! Map<String, dynamic>) continue;
          if (!isXuanCiTianKong(q)) continue;

          final options = q['options'];
          if (options is List) {
            idiomSet.addAll(extractIdiomsFromOptions(options));
          }
        }
      } catch (e) {
        stderr.writeln('[WARN] 解析文件跳过 ${file.path}: $e');
      }
    }
  }

  stdout.writeln('从题库中提取到 ${idiomSet.length} 个四字成语\n');

  if (idiomSet.isEmpty) {
    stdout.writeln('未找到成语，请检查题库文件。');
    // 生成空 JSON
    final outputFile = File('assets/data/idioms_preset.json');
    await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert([]));
    return;
  }

  // 2. 加载已有预置数据（增量更新）
  final outputFile = File('assets/data/idioms_preset.json');
  final existingMap = <String, Map<String, dynamic>>{};
  if (outputFile.existsSync()) {
    try {
      final existing = jsonDecode(await outputFile.readAsString()) as List;
      for (final item in existing) {
        existingMap[item['text'] as String] = item as Map<String, dynamic>;
      }
      stdout.writeln('已有预置数据 ${existingMap.length} 条，增量更新...\n');
    } catch (_) {}
  }

  // 3. 逐个采集释义和例句
  final results = <Map<String, dynamic>>[];
  int processed = 0;
  final total = idiomSet.length;

  for (final idiom in idiomSet.toList()..sort()) {
    processed++;
    stdout.write('[$processed/$total] $idiom ... ');

    // 已有数据直接复用
    if (existingMap.containsKey(idiom)) {
      results.add(existingMap[idiom]!);
      stdout.writeln('已有，跳过');
      continue;
    }

    // 采集释义
    final definition = await fetchDefinition(idiom);

    // 采集人民日报例句
    final examples = await fetchPeopleDailyExamples(idiom);

    results.add({
      'text': idiom,
      'definition': definition,
      'examples': examples,
    });

    stdout.writeln('释义${definition.isNotEmpty ? "OK" : "空"}, 例句${examples.length}条');
  }

  // 4. 按拼音排序后写入 JSON
  results.sort((a, b) => (a['text'] as String).compareTo(b['text'] as String));
  final jsonOutput = const JsonEncoder.withIndent('  ').convert(results);
  await outputFile.writeAsString(jsonOutput);

  stdout.writeln('\n完成！共 ${results.length} 个成语，已写入 ${outputFile.path}');
}
