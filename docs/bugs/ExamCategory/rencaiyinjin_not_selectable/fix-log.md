# 修复日志: 人才引进无法选择 + 功能链路缺失

## 根因

`ExamCategoryRegistry.rencaiyinjin` 的 `contentStatus` 为 `ContentStatus.comingSoon`，导致 `ExamTargetScreen` 阻止选择（显示"题库建设中"SnackBar）。同时缺少完整的岗位驱动功能链路。

## 修复内容

### Part 1: 解除选择限制 + 自动跳转岗位匹配

**修改文件：**
- `lib/models/exam_category_registry.dart` — `contentStatus: comingSoon → partial`，添加默认科目（行测120+申论）和面试分类，扩展 supportedFeatures
- `lib/services/exam_category_service.dart` — 新增 `pendingTabIndex` 机制和 `consumePendingTabIndex()` 方法，选择人才引进时自动设置待跳转到岗位匹配 Tab
- `lib/screens/home_screen.dart` — initState 中消费 pendingTabIndex，实现跨页面自动切 Tab

### Part 2: 预置全国人才引进公告 + 增量合并

**新增文件：**
- `assets/data/rencaiyinjin_policies_preset.json` — 25 条全国各省人才引进公告预置数据

**修改文件：**
- `lib/services/match_service.dart` — 新增 `loadPresetPolicies()` 方法（增量合并，title+province+city 去重），新增 `addPolicyIfNotExists()` 方法
- `lib/screens/policy_match_screen.dart` — 人才引进目标时自动加载预置公告
- `pubspec.yaml` — 注册新 asset

### Part 3: 目标岗位驱动的动态功能开放

**修改文件：**
- `lib/services/exam_category_service.dart` — 新增 `_overrideSubjects` 字段和 `updateSubjectsFromExamText()` 方法，根据岗位 examSubjects 关键词（行测/申论/公基/职测）动态映射科目配置
- `lib/services/match_service.dart` — `toggleTarget()` 增加通知 ExamCategoryService 逻辑；新增 `setExamCategoryService()` 延迟注入方法
- `lib/main.dart` — MatchService 创建时注入 ExamCategoryService

## 验证

- `flutter analyze` 零新增错误（8 个预存错误均为 speed_training 模块未提交导致）
