---
generated: 2026-04-07T12:00:00+08:00
git_commit: pending
---

# 验收报告：考试类型差异化服务系统

## 验收标准

[PASS] AC-01: ExamCategory 模型存在 — `grep "class ExamCategory" lib/models/exam_category.dart`
[PASS] AC-02: ExamCategoryRegistry 存在 — `grep "class ExamCategoryRegistry" lib/models/exam_category_registry.dart`
[PASS] AC-03: UserExamTarget 存在 — `grep "class UserExamTarget" lib/models/user_exam_target.dart`
[PASS] AC-04: ExamCategoryService 存在 — `grep "class ExamCategoryService" lib/services/exam_category_service.dart`
[PASS] AC-05: ExamTargetScreen 存在 — `grep "class ExamTargetScreen" lib/screens/exam_target_screen.dart`
[PASS] AC-06: ExamTypeBadge 存在 — `grep "class ExamTypeBadge" lib/widgets/exam_type_badge.dart`
[PASS] AC-07: DB version = 11 — `grep "version: 11" lib/db/database_helper.dart`
[PASS] AC-08: Provider 注册 — `grep "ExamCategoryService" lib/main.dart` (14 处引用)
[PASS] AC-09: "130题" 硬编码移除 — `grep -c "130题" lib/screens/exam_screen.dart` 返回 0
[PASS] AC-10: flutter test 全通过 — 37/37 passed
[PASS] AC-11: flutter analyze 零错误 — No issues found
[MANUAL] AC-12: 首次启动→引导页→选国考→刷题显示行测5类+申论 — 待手动验证
[MANUAL] AC-13: 切换事业编A类→显示"职测"/"综合"，申论训练入口隐藏 — 待手动验证
[MANUAL] AC-14: 选"先看看"→探索模式→引导Banner — 待手动验证

## 实现概要

- 新增文件:
  - lib/models/exam_category.dart — 考试类型模型族
  - lib/models/exam_category_registry.dart — 静态注册表
  - lib/models/user_exam_target.dart + .g.dart — 用户备考目标模型
  - lib/services/exam_category_service.dart — 中心服务
  - lib/screens/exam_target_screen.dart — 引导页
  - lib/widgets/exam_type_badge.dart — 全局指示器
  - lib/widgets/subject_category_ui.dart — SubjectCategory UI 扩展

- 修改文件:
  - lib/db/database_helper.dart — v10→v11 迁移 + 查询增强
  - lib/main.dart — Provider 注册
  - lib/app.dart — 条件路由
  - lib/screens/practice_screen.dart — 动态科目
  - lib/screens/exam_screen.dart — 动态参数
  - lib/screens/profile_screen.dart — 备考目标管理
  - lib/screens/home_screen.dart — 指示器 + 刷新
  - lib/screens/baseline_test_screen.dart — 硬编码移除
  - lib/screens/study_plan_screen.dart — 硬编码移除 + 冲突处理
  - lib/screens/exam_calendar_screen.dart — 硬编码移除
  - lib/screens/dashboard_screen.dart — 倒计时 + 过滤
  - lib/services/dashboard_service.dart — 按类型过滤
  - lib/services/study_plan_service.dart — 科目参数 + 冲突
  - lib/services/interview_service.dart — 动态分类
  - lib/services/assistant_service.dart — 上下文注入
  - test/widget_test.dart — 适配新 Provider
  - test/baseline_service_test.dart — 适配新 Provider

## 红蓝对抗修正落实

- [x] setTarget() 使用 db.transaction() 包裹 — exam_category_service.dart:89
- [x] 事务提交后一次性更新内存字段 — exam_category_service.dart:96-104
- [x] loadTargets() 优先检测 '__explore__' — exam_category_service.dart:58
- [x] checkTargetConflict() 查询方法（分层，不弹窗） — exam_category_service.dart:181
- [x] UserExamTarget.isExploreMarker getter — user_exam_target.dart
- [x] SubjectCategory UI 扩展在 widget 层 — widgets/subject_category_ui.dart

## 结论

机械验收: 11/11 通过
手动验证: 3 项待确认
