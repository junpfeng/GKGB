# Bug: 人才引进无法选择 + 功能链路缺失

## 现象
备考目标页"人才引进"显示为"即将上线"（半透明+标签），点击只弹 SnackBar，无法设为备考目标。

## 根因
`ExamCategoryRegistry.rencaiyinjin` 的 `contentStatus` 为 `ContentStatus.comingSoon`，`ExamTargetScreen` 对 comingSoon 类型阻止选择。

## 修复方案

### Part 1: 解除选择限制 + 自动跳转
1. `exam_category_registry.dart`: contentStatus → partial, 添加默认科目（行测+申论+面试）, 扩展 supportedFeatures
2. `exam_target_screen.dart`: 选择人才引进后自动跳转到岗位匹配 Tab
3. `exam_category_service.dart`: 添加 pendingTabIndex 机制支持跨页面导航
4. `home_screen.dart`: 读取 pendingTabIndex 实现自动切 Tab

### Part 2: 预置全国公告数据 + 增量合并
1. 创建 `assets/data/rencaiyinjin_policies_preset.json`（25+ 条全国各省公告）
2. `match_service.dart`: 添加 loadPresetPolicies() 加载预置数据，标题去重
3. 选择人才引进进入岗位匹配时自动加载预置数据

### Part 3: 岗位驱动的动态功能开放
1. `exam_category_service.dart`: 添加 _overrideSubjects 字段，支持从目标岗位动态覆盖科目
2. `match_service.dart`: toggleTarget 时解析 examSubjects，通知 ExamCategoryService
3. 关键词映射：行测/申论/公基/面试 → 对应科目配置
