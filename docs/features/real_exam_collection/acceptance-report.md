---
generated: 2026-04-07T00:00:00+08:00
git_branch: feature/real_exam_collection
---

# 验收报告：真题库收集与整理系统

## 验收标准

[PASS] AC-01: questions 表新增 is_real_exam 等 5 字段 — grep 匹配 8 处
[PASS] AC-02: real_exam_papers 表存在 — grep 匹配 11 处
[PASS] AC-03: 事务迁移 — grep transaction/txn 匹配 11 处
[PASS] AC-04: RealExamService 文件存在 — `lib/services/real_exam_service.dart`
[PASS] AC-05: 真题筛选页面存在 — `lib/screens/real_exam_screen.dart`
[PASS] AC-06: 贡献真题页面存在 — `lib/screens/contribute_question_screen.dart`
[PASS] AC-07: RealExamPaper 模型存在 — `lib/models/real_exam_paper.dart`
[PASS] AC-08: Question 模型含真题字段 — grep 匹配 5 处
[PASS] AC-09: Provider 注册 — grep RealExamService in main.dart 匹配 4 处
[PASS] AC-10: 复合索引存在 — grep idx_questions_real_exam 匹配 2 处
[PASS] AC-11: flutter test — 37/37 tests passed
[PASS] AC-12: flutter analyze — No issues found
[MANUAL] AC-13: PracticeScreen 第 3 个 Tab「真题」可见，三级筛选可用，可模考

## 实现概要

- 新增文件:
  - lib/models/real_exam_paper.dart
  - lib/services/real_exam_service.dart
  - lib/screens/real_exam_screen.dart
  - lib/screens/real_exam_paper_screen.dart
  - lib/screens/contribute_question_screen.dart
  - assets/questions/real_exam_sample.json
  - docs/features/real_exam_collection/develop-log.md

- 修改文件:
  - lib/models/question.dart
  - lib/db/database_helper.dart
  - lib/services/question_service.dart
  - lib/services/exam_service.dart
  - lib/screens/practice_screen.dart
  - lib/main.dart
  - pubspec.yaml

## 结论

机械验收: 12/12 通过
手动验证: 1 项待确认
