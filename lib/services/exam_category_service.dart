import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/exam_category.dart';
import '../models/exam_category_registry.dart';
import '../models/user_exam_target.dart';

/// 考试类型中心服务：管理用户备考目标，提供活跃科目/参数/过滤条件
class ExamCategoryService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 状态
  UserExamTarget? _primaryTarget;
  ExamCategory? _activeCategory;
  ExamSubType? _activeSubType;
  bool _isExploreMode = false;

  // getter
  bool get hasTarget => _primaryTarget != null && _activeCategory != null;
  bool get isExploreMode => _isExploreMode;
  UserExamTarget? get primaryTarget => _primaryTarget;
  ExamCategory? get activeCategory => _activeCategory;
  ExamSubType? get activeSubType => _activeSubType;

  /// 当前活跃科目列表（优先子类型，回退到默认科目）
  List<ExamSubject> get activeSubjects {
    if (_activeSubType != null && _activeSubType!.subjects.isNotEmpty) {
      return _activeSubType!.subjects;
    }
    return _activeCategory?.defaultSubjects ?? [];
  }

  /// 用于 DB WHERE 过滤的 exam_type 值列表
  List<String> get activeExamTypeValues =>
      _activeCategory?.dbExamTypeValues ?? [];

  /// activeSubjects 中是否有申论或综合应用能力类写作科目
  bool get hasEssay => activeSubjects.any(
      (s) => s.subject == '申论' || s.subject == '综合');

  /// 检查功能是否可用
  bool isFeatureSupported(Feature feature) =>
      _activeCategory?.supportedFeatures.contains(feature) ?? false;

  /// 启动时加载已保存的目标
  Future<void> loadTargets() async {
    final rows = await _db.queryExamTargets();
    if (rows.isEmpty) {
      _primaryTarget = null;
      _activeCategory = null;
      _activeSubType = null;
      _isExploreMode = false;
      return;
    }

    final target = UserExamTarget.fromDb(rows.first);

    // 优先检测探索模式标记（在 Registry 匹配之前）
    if (target.isExploreMarker) {
      _isExploreMode = true;
      _primaryTarget = null;
      _activeCategory = ExamCategoryRegistry.guokao; // 探索模式默认国考配置
      _activeSubType = null;
      notifyListeners();
      return;
    }

    // 尝试匹配 Registry
    final category = ExamCategoryRegistry.findById(target.examCategoryId);
    if (category == null) {
      // Registry 中不存在（如 app 更新移除了某类型）→ 清除 + 进入探索模式
      debugPrint('ExamCategoryService: 未找到 ${target.examCategoryId}，清除并进入探索模式');
      await _db.deleteAllExamTargets();
      await enterExploreMode();
      return;
    }

    _primaryTarget = target;
    _activeCategory = category;
    _activeSubType = target.subTypeId.isNotEmpty
        ? ExamCategoryRegistry.findSubType(target.examCategoryId, target.subTypeId)
        : null;
    _isExploreMode = false;
    notifyListeners();
  }

  /// 设置/替换当前目标（事务包裹全部 DB 写入，事务提交后再更新内存字段）
  Future<void> setTarget(UserExamTarget target) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // 清除旧目标
      await txn.delete('user_exam_targets');
      // 插入新目标
      await txn.insert('user_exam_targets', target.toDb());
    });

    // 事务成功后一次性更新内存
    final category = ExamCategoryRegistry.findById(target.examCategoryId);
    _primaryTarget = target;
    _activeCategory = category;
    _activeSubType = target.subTypeId.isNotEmpty
        ? ExamCategoryRegistry.findSubType(target.examCategoryId, target.subTypeId)
        : null;
    _isExploreMode = false;
    notifyListeners();
  }

  /// 进入探索模式（写入特殊标记到 DB，默认国考配置）
  Future<void> enterExploreMode() async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('user_exam_targets');
      await txn.insert('user_exam_targets', {
        'exam_category_id': '__explore__',
        'sub_type_id': '',
        'province': '',
        'is_primary': 1,
      });
    });

    _isExploreMode = true;
    _primaryTarget = null;
    _activeCategory = ExamCategoryRegistry.guokao;
    _activeSubType = null;
    notifyListeners();
  }

  /// 移除目标
  Future<void> removeTarget() async {
    await _db.deleteAllExamTargets();
    _primaryTarget = null;
    _activeCategory = null;
    _activeSubType = null;
    _isExploreMode = false;
    notifyListeners();
  }

  /// 更新目标详情（省份、子类型、目标日期）
  Future<void> updateTargetDetails({
    String? province,
    String? subTypeId,
    String? targetExamDate,
  }) async {
    if (_primaryTarget == null) return;
    final updated = _primaryTarget!.copyWith(
      province: province,
      subTypeId: subTypeId,
      targetExamDate: targetExamDate,
    );
    await setTarget(updated);
  }

  /// 测试用：直接设置探索模式内存状态（不写 DB）
  void setExploreModeSync() {
    _isExploreMode = true;
    _primaryTarget = null;
    _activeCategory = ExamCategoryRegistry.guokao;
    _activeSubType = null;
  }

  /// 获取指定科目的考试配置（题量/时间/总分）
  Map<String, dynamic> getExamConfig(String subject) {
    for (final s in activeSubjects) {
      if (s.subject == subject) {
        return {
          'questionCount': s.defaultQuestionCount,
          'timeLimit': s.defaultTimeLimitSeconds,
          'totalScore': s.totalScore,
        };
      }
    }
    // 默认值
    return {'questionCount': 100, 'timeLimit': 7200, 'totalScore': 100};
  }

  /// 获取活跃科目名列表（用于学习计划）
  List<String> getSubjectsForPlan() =>
      activeSubjects.map((s) => s.subject).toList();

  /// 检查切换目标是否与当前活跃学习计划冲突
  /// 返回 null 表示无冲突，否则返回冲突信息 Map
  Future<Map<String, dynamic>?> checkTargetConflict(String newCategoryId, {String newSubTypeId = ''}) async {
    final db = await _db.database;
    final plans = await db.query('study_plans',
        where: "status = 'active'", limit: 1);
    if (plans.isEmpty) return null;

    final plan = plans.first;
    final planSubjects = (plan['subjects'] as String?)?.split(',').toSet() ?? {};

    // 获取新目标的科目
    final newCategory = ExamCategoryRegistry.findById(newCategoryId);
    if (newCategory == null) return null;

    List<ExamSubject> newSubjects;
    if (newSubTypeId.isNotEmpty) {
      final subType = ExamCategoryRegistry.findSubType(newCategoryId, newSubTypeId);
      newSubjects = subType?.subjects ?? newCategory.defaultSubjects;
    } else {
      newSubjects = newCategory.defaultSubjects;
    }
    final newSubjectNames = newSubjects.map((s) => s.subject).toSet();

    if (planSubjects.difference(newSubjectNames).isEmpty &&
        newSubjectNames.difference(planSubjects).isEmpty) {
      return null; // 科目集合相同，无冲突
    }

    return {
      'planId': plan['id'],
      'planSubjects': planSubjects.toList(),
      'newSubjects': newSubjectNames.toList(),
    };
  }

  /// 暂停活跃学习计划
  Future<void> pauseActivePlans() async {
    final db = await _db.database;
    await db.rawUpdate(
      "UPDATE study_plans SET status = 'paused' WHERE status = 'active'",
    );
  }

  /// 获取当前目标的显示文本
  String get targetDisplayText {
    if (_isExploreMode) return '探索模式';
    if (_activeCategory == null) return '';
    final parts = [_activeCategory!.label];
    if (_activeSubType != null) parts.add(_activeSubType!.label);
    if (_primaryTarget?.province.isNotEmpty == true) {
      parts.add(_primaryTarget!.province);
    }
    return parts.join(' · ');
  }
}
