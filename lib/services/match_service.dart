import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/parser.dart' as html_parser;
import '../db/database_helper.dart';
import '../models/talent_policy.dart';
import '../models/position.dart';
import '../models/match_result.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';
import 'exam_category_service.dart';
import 'llm/llm_manager.dart';
import 'llm/llm_provider.dart';

/// 公告匹配服务：公告管理、两级匹配引擎、AI 解析
class MatchService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ProfileService _profileService;
  final LlmManager _llmManager;

  List<TalentPolicy> _policies = [];
  List<MatchResult> _matchResults = [];
  bool _isLoading = false;
  bool _isMatching = false;

  List<TalentPolicy> get policies => List.unmodifiable(_policies);
  List<MatchResult> get matchResults => List.unmodifiable(_matchResults);
  List<MatchResult> get targetPositions =>
      _matchResults.where((r) => r.isTarget).toList();
  bool get isLoading => _isLoading;
  bool get isMatching => _isMatching;

  // Dio 实例（公告抓取用）
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0',
    },
  ));

  ExamCategoryService? _examCategoryService;

  MatchService(this._profileService, this._llmManager);

  /// 注入 ExamCategoryService（避免循环依赖，延迟注入）
  void setExamCategoryService(ExamCategoryService service) {
    _examCategoryService = service;
  }

  // ===== 公告管理 =====

  Future<void> loadPolicies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryPolicies();
      _policies = rows.map((r) => TalentPolicy.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TalentPolicy> addPolicy({
    required String title,
    String? province,
    String? city,
    String? policyType,
    String? content,
    String? deadline,
  }) async {
    final policy = TalentPolicy(
      title: title,
      province: province,
      city: city,
      policyType: policyType,
      content: content,
      deadline: deadline,
    );
    final id = await _db.insertPolicy(policy.toDb());
    final newPolicy = TalentPolicy(
      id: id,
      title: title,
      province: province,
      city: city,
      policyType: policyType,
      content: content,
      deadline: deadline,
    );
    _policies.insert(0, newPolicy);
    notifyListeners();
    return newPolicy;
  }

  Future<void> deletePolicy(int policyId) async {
    await _db.deletePolicy(policyId);
    _policies.removeWhere((p) => p.id == policyId);
    _matchResults.removeWhere((r) {
      // 找到属于该公告的岗位
      return false; // 简化处理
    });
    notifyListeners();
  }

  /// 加载预置人才引进公告及岗位数据（增量合并，不覆盖已有数据）
  ///
  /// 以 title+province+city 为去重键，仅插入本地不存在的公告。
  /// 同时插入每条公告关联的预解析岗位（positions）。
  Future<int> loadPresetPolicies() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/rencaiyinjin_policies_preset.json',
      );
      final List<dynamic> items = jsonDecode(jsonStr);

      // 构建预置数据的去重键集合和城市集合
      final presetKeys = <String>{};
      final presetCities = <String, String>{}; // city -> province
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        final province = map['province'] as String?;
        final city = map['city'] as String?;
        presetKeys.add(_policyDeduplicationKey(title, province, city));
        if (city != null && province != null) {
          presetCities[city] = province;
        }
      }

      // 获取已有公告
      final existingRows = await _db.queryPolicies();

      // 清理旧预置数据：同城市同省份但标题不匹配的条目（已被替换的虚假公告）
      for (final row in existingRows) {
        final title = row['title'] as String;
        final province = row['province'] as String?;
        final city = row['city'] as String?;
        final key = _policyDeduplicationKey(title, province, city);

        // 如果该城市在预置数据中，但这条记录的标题不在预置数据里，说明是旧版预置数据
        if (city != null && province != null &&
            presetCities[city] == province &&
            !presetKeys.contains(key)) {
          final policyId = row['id'] as int;
          // 删除关联的匹配结果、岗位、公告
          final positions = await _db.queryPositionsByPolicy(policyId);
          for (final pos in positions) {
            final posId = pos['id'] as int;
            await _db.deleteMatchResultByPosition(posId);
            await _db.deletePosition(posId);
          }
          await _db.deletePolicy(policyId);
          debugPrint('清理旧预置公告: $title ($city)');
        }
      }

      // 重新获取清理后的公告列表
      final cleanedRows = await _db.queryPolicies();
      final existingKeys = <String>{};
      for (final row in cleanedRows) {
        final key = _policyDeduplicationKey(
          row['title'] as String,
          row['province'] as String?,
          row['city'] as String?,
        );
        existingKeys.add(key);
      }

      // 构建已有公告 id 映射（用于存量刷新）
      final existingIdByKey = <String, int>{};
      for (final row in cleanedRows) {
        final key = _policyDeduplicationKey(
          row['title'] as String,
          row['province'] as String?,
          row['city'] as String?,
        );
        existingIdByKey[key] = row['id'] as int;
      }

      int added = 0;
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        final province = map['province'] as String?;
        final city = map['city'] as String?;
        final key = _policyDeduplicationKey(title, province, city);

        if (existingKeys.contains(key)) {
          // 存量数据刷新：补充 source_url 等缺失字段
          final existingId = existingIdByKey[key];
          if (existingId != null) {
            await _refreshExistingPresetPolicy(existingId, map);
          }
          continue;
        }

        final policyId = await _db.insertPolicy({
          'title': title,
          'source_url': map['source_url'] as String?,
          'province': province,
          'city': city,
          'policy_type': map['policy_type'] as String?,
          'publish_date': map['publish_date'] as String?,
          'deadline': map['deadline'] as String?,
          'content': map['content'] as String?,
          'attachment_urls': '[]',
        });

        // 插入预解析的岗位数据
        final positions = map['positions'] as List<dynamic>? ?? [];
        for (final pos in positions) {
          final p = pos as Map<String, dynamic>;
          await _db.insertPosition({
            'policy_id': policyId,
            'position_name': p['position_name'] as String? ?? '未知岗位',
            'department': p['department'] as String?,
            'recruit_count': p['recruit_count'] as int? ?? 1,
            'education_req': p['education_req'] as String?,
            'degree_req': p['degree_req'] as String?,
            'major_req': p['major_req'] as String?,
            'age_req': p['age_req'] as String?,
            'political_req': p['political_req'] as String?,
            'work_exp_req': p['work_exp_req'] as String?,
            'certificate_req': p['certificate_req'] as String?,
            'gender_req': p['gender_req'] as String?,
            'hukou_req': p['hukou_req'] as String?,
            'other_req': p['other_req'] as String?,
            'exam_subjects': p['exam_subjects'] as String?,
            'exam_date': p['exam_date'] as String?,
          });
        }

        existingKeys.add(key);
        added++;
      }

      await loadPolicies(); // 刷新内存列表（含存量刷新后的数据）
      return added;
    } catch (e) {
      debugPrint('加载预置公告失败: $e');
      return 0;
    }
  }

  /// 刷新已有预置公告：补充 source_url 等缺失字段 + 更新关联岗位的缺失字段
  Future<void> _refreshExistingPresetPolicy(int policyId, Map<String, dynamic> presetMap) async {
    // 补充公告的 source_url（仅当 DB 中为空时更新）
    final sourceUrl = presetMap['source_url'] as String?;
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      final existing = await _db.queryPolicyById(policyId);
      if (existing != null && (existing['source_url'] == null || (existing['source_url'] as String).isEmpty)) {
        await _db.updatePolicy(policyId, {'source_url': sourceUrl});
      }
    }

    // 补充岗位的 hukou_req 等缺失字段
    final presetPositions = presetMap['positions'] as List<dynamic>? ?? [];
    final dbPositions = await _db.queryPositionsByPolicy(policyId);

    for (final dbPos in dbPositions) {
      final dbPosId = dbPos['id'] as int;
      final dbPosName = dbPos['position_name'] as String;

      // 按岗位名匹配预置数据
      final matchingPreset = presetPositions.cast<Map<String, dynamic>>().where(
        (p) => (p['position_name'] as String?) == dbPosName,
      );
      if (matchingPreset.isEmpty) continue;
      final preset = matchingPreset.first;

      final updates = <String, dynamic>{};
      // 补充 hukou_req
      if ((dbPos['hukou_req'] == null || (dbPos['hukou_req'] as String).isEmpty) &&
          preset['hukou_req'] != null) {
        updates['hukou_req'] = preset['hukou_req'];
      }
      if (updates.isNotEmpty) {
        final db = await _db.database;
        await db.update('positions', updates, where: 'id = ?', whereArgs: [dbPosId]);
      }
    }
  }

  /// 增量添加公告（先去重检查）
  /// 返回 null 表示重复未入库，返回 TalentPolicy 表示成功入库
  Future<TalentPolicy?> addPolicyIfNotExists({
    required String title,
    String? province,
    String? city,
    String? policyType,
    String? content,
    String? deadline,
  }) async {
    // 去重检查
    final existingRows = await _db.queryPolicies();
    final key = _policyDeduplicationKey(title, province, city);
    for (final row in existingRows) {
      final existingKey = _policyDeduplicationKey(
        row['title'] as String,
        row['province'] as String?,
        row['city'] as String?,
      );
      if (existingKey == key) return null; // 已存在
    }
    return addPolicy(
      title: title,
      province: province,
      city: city,
      policyType: policyType,
      content: content,
      deadline: deadline,
    );
  }

  /// 公告去重键：title + province + city 的规范化拼接
  static String _policyDeduplicationKey(String title, String? province, String? city) {
    return '${title.trim()}|${(province ?? '').trim()}|${(city ?? '').trim()}'.toLowerCase();
  }

  // ===== 智能获取公告 =====

  /// AI 联网搜索公告（生成搜索词 → 搜索 → AI解析结果）
  Future<List<TalentPolicy>> searchPoliciesOnline(
    List<String> targetCities,
  ) async {
    // 第一步：让 LLM 生成搜索关键词
    final keywordPrompt = '''
我在寻找以下城市的人才引进/招聘公告：${targetCities.join('、')}
请生成3-5个适合搜索的关键词组合（每个关键词组合1行），用于在搜索引擎上查找最新公告。
只返回关键词，不要其他文字。格式如：
${targetCities.isNotEmpty ? targetCities.first : "北京"}人才引进公告2024
${targetCities.isNotEmpty ? targetCities.first : "北京"}事业单位招聘2024
''';

    final keywords = await _llmManager.chat([
      ChatMessage(role: 'user', content: keywordPrompt),
    ]);

    // 提取关键词列表
    final keywordList = keywords
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .toList();

    if (keywordList.isEmpty) {
      throw Exception('AI 未能生成有效的搜索关键词');
    }

    // 第二步：使用第一个关键词搜索（遵守 robots.txt，设置间隔）
    final searchQuery = Uri.encodeComponent(keywordList.first);
    final searchUrl =
        'https://cn.bing.com/search?q=$searchQuery&setlang=zh-CN';

    String searchHtml = '';
    try {
      final response = await _dio.get(searchUrl);
      searchHtml = response.data.toString();
    } catch (e) {
      debugPrint('搜索请求失败: $e');
      throw Exception('网络搜索失败，请检查网络连接: $e');
    }

    // 提取搜索结果纯文本（用 html 包）
    final document = html_parser.parse(searchHtml);
    final snippets = document.querySelectorAll('.b_algo').take(5).map((el) {
      return el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    }).join('\n\n');

    if (snippets.isEmpty) {
      throw Exception('未找到相关搜索结果');
    }

    // 第三步：让 AI 解析搜索结果，提取公告摘要
    final parsePrompt = '''
以下是搜索"${keywordList.first}"的网页摘要结果，请提取其中的人才引进/招聘公告信息，
以 JSON 数组格式返回，每条包含字段：
- title: 公告标题
- city: 城市
- province: 省份
- policy_type: 类型（人才引进/事业编/高校招聘等）
- deadline: 截止日期（如有）
- source_url: 原文链接（如有）

仅返回 JSON 数组，不要其他文字。若无相关公告，返回 []。

搜索结果：
$snippets
''';

    final parseResult = await _llmManager.chat([
      ChatMessage(role: 'user', content: parsePrompt),
    ]);

    // 解析 AI 返回的 JSON
    try {
      final jsonStart = parseResult.indexOf('[');
      final jsonEnd = parseResult.lastIndexOf(']') + 1;
      if (jsonStart < 0 || jsonEnd <= jsonStart) return [];

      final jsonStr = parseResult.substring(jsonStart, jsonEnd);
      final List<dynamic> items = jsonDecode(jsonStr);

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        return TalentPolicy(
          title: map['title'] as String? ?? '未知公告',
          city: map['city'] as String?,
          province: map['province'] as String?,
          policyType: map['policy_type'] as String?,
          deadline: map['deadline'] as String?,
          sourceUrl: map['source_url'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('解析搜索结果失败: $e');
      return [];
    }
  }

  /// 从 URL 导入公告（抓取网页 → html 解析正文 → AI 解析）
  Future<TalentPolicy> importFromUrl(String url) async {
    // 请求间隔遵守 robots.txt 规范（≥2s）
    await Future.delayed(const Duration(seconds: 2));

    String htmlContent = '';
    try {
      final response = await _dio.get(url);
      htmlContent = response.data.toString();
    } catch (e) {
      throw Exception('网页抓取失败，请检查链接是否有效: $e');
    }

    // 使用 html 包提取正文文本
    final document = html_parser.parse(htmlContent);
    // 移除 script/style 节点
    document.querySelectorAll('script, style, nav, header, footer').forEach(
          (el) => el.remove(),
        );
    final bodyText = document.body?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';

    if (bodyText.isEmpty) {
      throw Exception('网页内容为空或无法解析');
    }

    // 截断防止 token 超限（取前 3000 字）
    final truncated =
        bodyText.length > 3000 ? bodyText.substring(0, 3000) : bodyText;

    // 先创建基础公告
    final policy = TalentPolicy(
      title: '从链接导入的公告',
      sourceUrl: url,
      content: truncated,
    );

    // 用 AI 补充解析标题和基本信息
    final infoPrompt = '''
从以下网页内容中提取公告的基本信息，以 JSON 格式返回：
{
  "title": "公告标题",
  "province": "省份",
  "city": "城市",
  "policy_type": "公告类型",
  "deadline": "报名截止日期"
}
只返回 JSON，不要其他文字。

网页内容：
$truncated
''';

    try {
      final infoResult = await _llmManager.chat([
        ChatMessage(role: 'user', content: infoPrompt),
      ]);
      final jsonStart = infoResult.indexOf('{');
      final jsonEnd = infoResult.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final map =
            jsonDecode(infoResult.substring(jsonStart, jsonEnd)) as Map;
        return TalentPolicy(
          title: map['title'] as String? ?? policy.title,
          sourceUrl: url,
          province: map['province'] as String?,
          city: map['city'] as String?,
          policyType: map['policy_type'] as String?,
          deadline: map['deadline'] as String?,
          content: truncated,
        );
      }
    } catch (e) {
      debugPrint('AI 解析公告基本信息失败: $e');
    }

    return policy;
  }

  /// 从剪贴板文本导入公告
  Future<TalentPolicy> importFromClipboard(String text) async {
    if (text.trim().isEmpty) {
      throw Exception('剪贴板文本为空');
    }

    // 截断防止超限
    final truncated =
        text.length > 4000 ? text.substring(0, 4000) : text;

    // 用 AI 解析基本信息
    final infoPrompt = '''
从以下公告文本中提取基本信息，以 JSON 格式返回：
{
  "title": "公告标题",
  "province": "省份",
  "city": "城市",
  "policy_type": "公告类型",
  "deadline": "报名截止日期"
}
只返回 JSON，不要其他文字。

公告内容：
$truncated
''';

    String title = '从文本导入的公告';
    String? province, city, policyType, deadline;

    try {
      final result = await _llmManager.chat([
        ChatMessage(role: 'user', content: infoPrompt),
      ]);
      final jsonStart = result.indexOf('{');
      final jsonEnd = result.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final map =
            jsonDecode(result.substring(jsonStart, jsonEnd)) as Map;
        title = map['title'] as String? ?? title;
        province = map['province'] as String?;
        city = map['city'] as String?;
        policyType = map['policy_type'] as String?;
        deadline = map['deadline'] as String?;
      }
    } catch (e) {
      debugPrint('AI 解析剪贴板公告失败: $e');
    }

    return TalentPolicy(
      title: title,
      province: province,
      city: city,
      policyType: policyType,
      deadline: deadline,
      content: truncated,
    );
  }

  // ===== AI 解析公告 =====

  /// 用 AI 解析公告文本，提取结构化岗位信息
  Future<List<Position>> aiParsePolicy(TalentPolicy policy) async {
    if (policy.content == null || policy.content!.isEmpty) {
      throw Exception('公告内容为空，无法解析');
    }

    final prompt = '''
请从以下人才引进公告中提取所有岗位信息，以JSON数组格式返回。
每个岗位包含字段：
- position_name: 岗位名称
- department: 所属部门
- recruit_count: 招聘人数（整数）
- education_req: 学历要求（如"本科及以上"）
- degree_req: 学位要求（如"学士学位"）
- major_req: 专业要求
- age_req: 年龄要求
- political_req: 政治面貌要求
- work_exp_req: 工作经验要求
- certificate_req: 证书要求
- gender_req: 性别限制
- hukou_req: 户籍要求
- other_req: 其他要求
- exam_subjects: 考试科目
- exam_date: 考试时间

仅返回 JSON 数组，不要其他文字。

公告内容：
${policy.content}
''';

    final response = await _llmManager.chat([
      ChatMessage(role: 'user', content: prompt),
    ]);

    // 尝试解析返回的 JSON
    try {
      // 提取 JSON 数组部分
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      if (jsonStart < 0 || jsonEnd <= jsonStart) {
        throw Exception('AI 返回格式不正确');
      }
      final jsonStr = response.substring(jsonStart, jsonEnd);
      final List<dynamic> positionsJson = jsonDecode(jsonStr);

      final positions = <Position>[];
      for (final p in positionsJson) {
        final map = p as Map<String, dynamic>;
        final position = Position(
          policyId: policy.id,
          positionName: map['position_name'] as String? ?? '未知岗位',
          department: map['department'] as String?,
          recruitCount: (map['recruit_count'] as int?) ?? 1,
          educationReq: map['education_req'] as String?,
          degreeReq: map['degree_req'] as String?,
          majorReq: map['major_req'] as String?,
          ageReq: map['age_req'] as String?,
          politicalReq: map['political_req'] as String?,
          workExpReq: map['work_exp_req'] as String?,
          certificateReq: map['certificate_req'] as String?,
          genderReq: map['gender_req'] as String?,
          hukouReq: map['hukou_req'] as String?,
          otherReq: map['other_req'] as String?,
          examSubjects: map['exam_subjects'] as String?,
          examDate: map['exam_date'] as String?,
        );
        final id = await _db.insertPosition(position.toDb());
        positions.add(Position(
          id: id,
          policyId: position.policyId,
          positionName: position.positionName,
          department: position.department,
          recruitCount: position.recruitCount,
          educationReq: position.educationReq,
          degreeReq: position.degreeReq,
          majorReq: position.majorReq,
          ageReq: position.ageReq,
          politicalReq: position.politicalReq,
          workExpReq: position.workExpReq,
          certificateReq: position.certificateReq,
          genderReq: position.genderReq,
          hukouReq: position.hukouReq,
          otherReq: position.otherReq,
          examSubjects: position.examSubjects,
          examDate: position.examDate,
        ));
      }
      return positions;
    } catch (e) {
      throw Exception('AI 解析公告失败：$e');
    }
  }

  // ===== 匹配引擎 =====

  /// 执行两级匹配（粗筛→精确匹配）
  Future<void> runMatching() async {
    final profile = _profileService.profile;
    if (profile == null) throw Exception('请先完善个人信息');

    _isMatching = true;
    notifyListeners();

    try {
      final allPolicyRows = await _db.queryPolicies();
      final policies = allPolicyRows.map((r) => TalentPolicy.fromDb(r)).toList();

      // 第一级：公告粗筛（批量查询所有岗位，避免 N+1）
      final filteredPolicies = _filterPolicies(policies, profile);

      // 清理旧的匹配结果
      for (final policy in filteredPolicies) {
        if (policy.id == null) continue;
        final positionRows = await _db.queryPositionsByPolicy(policy.id!);

        // 第二级：精确岗位匹配
        for (final posRow in positionRows) {
          final position = Position.fromDb(posRow);
          final result = _matchPosition(position, profile, policy);

          // 保存匹配结果
          await _db.deleteMatchResultByPosition(position.id!);
          final id = await _db.insertMatchResult(result.toDb());
          _matchResults.removeWhere((r) => r.positionId == position.id);
          _matchResults.add(result.copyWith(id: id));
        }
      }

      // 重新加载匹配结果（含关联字段）
      final rows = await _db.queryMatchResults();
      _matchResults = rows.map((r) => MatchResult.fromDb(r)).toList();
    } finally {
      _isMatching = false;
      notifyListeners();
    }
  }

  Future<void> loadMatchResults() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.queryMatchResults();
      _matchResults = rows.map((r) => MatchResult.fromDb(r)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 标记/取消目标岗位
  ///
  /// 设为目标时，同步通知 ExamCategoryService 根据岗位考试科目动态调整功能。
  Future<void> toggleTarget(int matchResultId) async {
    final index = _matchResults.indexWhere((r) => r.id == matchResultId);
    if (index < 0) return;

    final result = _matchResults[index];
    final newIsTarget = !result.isTarget;
    await _db.updateMatchResult(matchResultId, {'is_target': newIsTarget ? 1 : 0});
    _matchResults[index] = result.copyWith(isTarget: newIsTarget);
    notifyListeners();

    // 通知 ExamCategoryService 更新动态科目（仅人才引进目标生效）
    if (_examCategoryService != null) {
      if (newIsTarget) {
        // 查询目标岗位的考试科目
        final posRow = await _db.queryPositionById(result.positionId);
        if (posRow != null) {
          final examSubjects = posRow['exam_subjects'] as String?;
          _examCategoryService!.updateSubjectsFromExamText(examSubjects);
        }
      } else {
        // 取消目标时，清除动态覆盖
        _examCategoryService!.updateSubjectsFromExamText(null);
      }
    }
  }

  // ===== 匹配算法（内部） =====

  /// 第一级：公告粗筛
  List<TalentPolicy> _filterPolicies(List<TalentPolicy> policies, UserProfile profile) {
    return policies.where((policy) {
      // 城市偏好过滤
      if (profile.targetCities.isNotEmpty && policy.city != null) {
        final cityMatch = profile.targetCities.any(
          (city) => policy.city!.contains(city) || city.contains(policy.city!),
        );
        if (!cityMatch) return false;
      }
      return true;
    }).toList();
  }

  /// 第二级：岗位精确匹配，返回 MatchResult（含评分理由）
  MatchResult _matchPosition(Position position, UserProfile profile, TalentPolicy policy) {
    final matched = <String>[];
    final risks = <String>[];
    final unmatched = <String>[];
    int score = 0;
    const int totalWeight = 100;

    // 学历匹配（权重 25）
    if (position.educationReq != null && position.educationReq!.isNotEmpty) {
      final result = _matchEducation(profile.education, position.educationReq!);
      if (result > 0) {
        score += (25 * result).round();
        matched.add('学历：${profile.education ?? "未填写"} 符合要求（${position.educationReq}）');
      } else {
        unmatched.add('学历：${profile.education ?? "未填写"} 不符合要求（${position.educationReq}）');
      }
    } else {
      score += 25;
      matched.add('学历：无特定要求');
    }

    // 专业匹配（权重 30）
    if (position.majorReq != null && position.majorReq!.isNotEmpty) {
      final result = _matchMajor(profile.major, profile.majorCode, position.majorReq!);
      if (result > 0.8) {
        score += (30 * result).round();
        matched.add('专业：${profile.major ?? "未填写"} 符合要求（${position.majorReq}）');
      } else if (result > 0.3) {
        score += (30 * result).round();
        risks.add('专业：${profile.major ?? "未填写"} 与要求（${position.majorReq}）可能相关，建议核实');
      } else {
        unmatched.add('专业：${profile.major ?? "未填写"} 不符合要求（${position.majorReq}）');
      }
    } else {
      score += 30;
      matched.add('专业：无特定要求');
    }

    // 年龄匹配（权重 15）
    if (position.ageReq != null && position.ageReq!.isNotEmpty && profile.age != null) {
      final result = _matchAge(profile.age!, position.ageReq!);
      if (result) {
        score += 15;
        matched.add('年龄：${profile.age}岁 符合要求（${position.ageReq}）');
      } else {
        unmatched.add('年龄：${profile.age}岁 不符合要求（${position.ageReq}）');
      }
    } else {
      score += 15;
      matched.add('年龄：${profile.age == null ? "未填写，无法验证" : "无特定要求"}');
    }

    // 政治面貌（权重 10）
    if (position.politicalReq != null && position.politicalReq!.isNotEmpty) {
      if (profile.politicalStatus != null &&
          position.politicalReq!.contains(profile.politicalStatus!)) {
        score += 10;
        matched.add('政治面貌：${profile.politicalStatus} 符合要求');
      } else if (position.politicalReq!.contains('不限') || position.politicalReq!.isEmpty) {
        score += 10;
        matched.add('政治面貌：不限');
      } else {
        risks.add('政治面貌：${profile.politicalStatus ?? "未填写"} 与要求（${position.politicalReq}）需核实');
        score += 5;
      }
    } else {
      score += 10;
      matched.add('政治面貌：无特定要求');
    }

    // 性别匹配（权重 10）
    if (position.genderReq != null && position.genderReq!.isNotEmpty &&
        !position.genderReq!.contains('不限')) {
      if (profile.gender != null && position.genderReq!.contains(profile.gender!)) {
        score += 10;
        matched.add('性别：${profile.gender} 符合要求');
      } else {
        unmatched.add('性别：${profile.gender ?? "未填写"} 不符合要求（${position.genderReq}）');
      }
    } else {
      score += 10;
      matched.add('性别：不限');
    }

    // 工作经验（权重 10）
    if (position.workExpReq != null && position.workExpReq!.isNotEmpty) {
      risks.add('工作经验要求：${position.workExpReq}，您工作年限：${profile.workYears}年，请核实');
      score += 5;
    } else {
      score += 10;
      matched.add('工作经验：无特定要求');
    }

    // 生成建议
    final advice = _generateAdvice(score, matched, risks, unmatched, position);

    return MatchResult(
      positionId: position.id!,
      matchScore: score.clamp(0, totalWeight),
      matchedItems: matched,
      riskItems: risks,
      unmatchedItems: unmatched,
      advice: advice,
    );
  }

  double _matchEducation(String? userEdu, String requirement) {
    if (userEdu == null) return 0;
    const eduOrder = ['大专', '本科', '硕士', '博士'];
    final reqLower = requirement.toLowerCase();
    int reqLevel = -1;
    int userLevel = -1;

    for (int i = 0; i < eduOrder.length; i++) {
      if (reqLower.contains(eduOrder[i])) reqLevel = i;
      if (userEdu.contains(eduOrder[i])) userLevel = i;
    }
    if (reqLevel < 0 || userLevel < 0) return 0.5; // 无法判断，给中间分
    return userLevel >= reqLevel ? 1.0 : 0.0;
  }

  double _matchMajor(String? userMajor, String? userMajorCode, String requirement) {
    if (userMajor == null) return 0;
    if (requirement.contains('不限') || requirement.contains('专业不限')) return 1.0;
    if (requirement.contains('相关专业')) return 0.5; // 模糊条件，给中间分
    if (requirement.contains(userMajor)) return 1.0;
    if (userMajorCode != null && requirement.contains(userMajorCode)) return 1.0;
    // 检查大类
    final majorFirstChar = userMajor.isNotEmpty ? userMajor[0] : '';
    if (majorFirstChar.isNotEmpty && requirement.contains(majorFirstChar)) return 0.6;
    return 0.0;
  }

  bool _matchAge(int userAge, String requirement) {
    // 解析"35岁以下"、"18-35岁"等格式
    final rangeMatch = RegExp(r'(\d+)\s*[-~至]\s*(\d+)').firstMatch(requirement);
    if (rangeMatch != null) {
      final min = int.parse(rangeMatch.group(1)!);
      final max = int.parse(rangeMatch.group(2)!);
      return userAge >= min && userAge <= max;
    }
    final upperMatch = RegExp(r'(\d+)\s*岁以下').firstMatch(requirement);
    if (upperMatch != null) {
      return userAge <= int.parse(upperMatch.group(1)!);
    }
    return true; // 无法解析，默认通过
  }

  String _generateAdvice(int score, List<String> matched, List<String> risks,
      List<String> unmatched, Position position) {
    final buffer = StringBuffer();
    if (score >= 80) {
      buffer.write('综合匹配度高（$score分），强烈建议报考。');
    } else if (score >= 60) {
      buffer.write('综合匹配度良好（$score分），可以报考。');
    } else if (score >= 40) {
      buffer.write('综合匹配度一般（$score分），建议作为备选岗位。');
    } else {
      buffer.write('综合匹配度较低（$score分），存在明显不符条件，谨慎报考。');
    }
    if (risks.isNotEmpty) {
      buffer.write(' 注意以下风险项需进一步核实。');
    }
    return buffer.toString();
  }
}
