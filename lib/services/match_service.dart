import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/talent_policy.dart';
import '../models/position.dart';
import '../models/match_result.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';
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

  MatchService(this._profileService, this._llmManager);

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
  Future<void> toggleTarget(int matchResultId) async {
    final index = _matchResults.indexWhere((r) => r.id == matchResultId);
    if (index < 0) return;

    final result = _matchResults[index];
    final newIsTarget = !result.isTarget;
    await _db.updateMatchResult(matchResultId, {'is_target': newIsTarget ? 1 : 0});
    _matchResults[index] = result.copyWith(isTarget: newIsTarget);
    notifyListeners();
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
