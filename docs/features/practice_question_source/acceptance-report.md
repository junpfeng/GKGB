---
generated: 2026-04-08T12:00:00+08:00
git_branch: feature/practice_question_source
---

# 验收报告：科目练习题目来源分类

## 验收标准

[PASS] AC-01: QuestionService 新增筛选参数 — `grep isRealExam lib/services/question_service.dart` 命中
[PASS] AC-02: QuestionListScreen 包含 SegmentedButton — `grep SegmentedButton lib/screens/practice_screen.dart` 命中
[PASS] AC-03: 全量测试通过 — `flutter test` 54/54 passed
[PASS] AC-04: 静态分析通过 — `flutter analyze` No issues found
[MANUAL] AC-05: 运行 flutter run -d windows，验证科目练习→题型→来源切换和真题筛选

## 实现概要

- 修改文件:
  - lib/db/database_helper.dart — queryQuestions() 增加 isRealExam/examType/region/year 参数
  - lib/services/question_service.dart — loadQuestions() 增加筛选参数，新增 getAvailableRegions/Years/ExamTypes
  - lib/screens/practice_screen.dart — QuestionListScreen 增加 SegmentedButton + 真题筛选器 UI
- 新增文件:
  - docs/features/practice_question_source/ 系列文档

## 结论

机械验收: 4/4 通过
手动验证: 1 项待确认
