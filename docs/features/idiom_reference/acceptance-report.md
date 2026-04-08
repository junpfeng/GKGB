---
generated: 2026-04-08T00:00:00Z
---

# 验收报告：成语整理 (idiom_reference)

## 验收标准

[PASS] AC-01: 新表存在 — grep "idioms" database_helper.dart 命中
[PASS] AC-02: 新文件存在 — idiom.dart, idiom_example.dart, idiom_service.dart, idiom_list_screen.dart
[PASS] AC-03: Provider 已注册 — grep "IdiomService" main.dart 命中
[PASS] AC-04: QuestionCard 集成 — _IdiomDefinitionSection 已添加
[PASS] AC-05: flutter analyze 零错误
[PASS] AC-06: flutter test 全通过 (54/54)
[MANUAL] AC-07: 刷题 > 言语理解 > 成语整理入口卡片 + 一键整理流程
[MANUAL] AC-08: 选词填空真题答后显示成语释义折叠区

## 实现概要

- 新增文件: lib/models/idiom.dart, lib/models/idiom_example.dart, lib/services/idiom_service.dart, lib/screens/idiom_list_screen.dart
- 修改文件: lib/db/database_helper.dart, lib/main.dart, lib/widgets/question_card.dart, lib/screens/practice_screen.dart

## 结论

机械验收: 6/6 通过
手动验证: 2 项待确认
