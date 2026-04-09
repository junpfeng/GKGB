# 考试类型差异化服务系统 - 实现日志

## 实现概览

按照设计文档 Phase 1-4 完整实现，一次性完成全部功能。

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/exam_category.dart` | ExamCategory/ExamSubType/ExamSubject/SubjectCategory 纯数据模型 |
| `lib/models/exam_category_registry.dart` | 静态注册表：国考/省考/事业编(A/B/C)/选调生/三支一扶/人才引进 完整定义 |
| `lib/models/user_exam_target.dart` | 用户备考目标模型（json_serializable + DB 存储） |
| `lib/models/user_exam_target.g.dart` | build_runner 生成的序列化代码 |
| `lib/services/exam_category_service.dart` | 中心服务：目标管理、活跃配置、科目查询、冲突检测 |
| `lib/screens/exam_target_screen.dart` | 引导页：7 张卡片（6 类型 + 探索模式），comingSoon 禁用 |
| `lib/widgets/exam_type_badge.dart` | 全局考试类型指示器（32px 彩色条） |
| `lib/widgets/subject_category_ui.dart` | SubjectCategory → IconData/Color 的 UI 扩展 |

## 修改文件

| 文件 | 变更内容 |
|------|----------|
| `lib/db/database_helper.dart` | version 10→11；新增 user_exam_targets 表（_createDB + _onUpgrade）；queryQuestions/countQuestions/randomQuestions 增加 examTypes 参数；querySubjectRadarData/queryWeeklyComparison 增加 examTypes 过滤；新增 _buildExamTypeFilter 辅助方法和 user_exam_targets CRUD |
| `lib/main.dart` | 注册 ExamCategoryService（最前面）；启动时 loadTargets()；更新 StudyPlanService/InterviewService/DashboardService/AssistantService 构造参数 |
| `lib/app.dart` | Consumer<ExamCategoryService> 条件路由：无目标→引导页，有目标→主页 |
| `lib/screens/practice_screen.dart` | 删除硬编码 _subjects 列表，从 activeSubjects 动态构建；面试入口按 Feature.interview 条件显示 |
| `lib/screens/exam_screen.dart` | 删除硬编码 '130题·120分钟'，从 getExamConfig() 动态获取；Wrap 布局支持多科目 |
| `lib/screens/home_screen.dart` | 顶部增加 ExamTypeBadge 指示器 |
| `lib/screens/profile_screen.dart` | 新增备考目标管理卡片；申论训练按 hasEssay 条件显隐 |
| `lib/screens/baseline_test_screen.dart` | 删除硬编码科目列表，从 activeSubjects 动态获取 |
| `lib/screens/study_plan_screen.dart` | 删除硬编码 {'行测','申论'} 和 ['行测','申论','公基']，动态获取；新增 paused 计划显示 |
| `lib/screens/exam_calendar_screen.dart` | 删除硬编码 _examTypes，从 ExamCategoryRegistry 动态生成 |
| `lib/screens/dashboard_screen.dart` | 新增考试倒计时组件；ExamCategoryService 注入 |
| `lib/services/study_plan_service.dart` | 新增 ExamCategoryService 依赖；默认 subjects 改为动态获取；AI prompt 注入备考目标；新增 paused 计划管理 |
| `lib/services/interview_service.dart` | 新增 ExamCategoryService 依赖；新增 activeCategories getter 动态获取面试分类 |
| `lib/services/assistant_service.dart` | 新增 ExamCategoryService 依赖；system prompt 注入备考目标上下文 |
| `lib/services/dashboard_service.dart` | 新增 ExamCategoryService 依赖；雷达图/周对比按 examTypes 过滤；雷达图改用 category 键 |
| `test/widget_test.dart` | 更新构造参数；使用 setExploreModeSync() 避免 DB 依赖 |
| `test/baseline_service_test.dart` | 更新 StudyPlanService 构造参数 |

## 关键决策说明

1. **setTarget() 事务包裹**：按锁定决策，所有 DB 写入用 db.transaction() 包裹，事务提交后再一次性更新内存字段 + 单次 notifyListeners()

2. **探索模式检测顺序**：loadTargets() 优先检测 `__explore__` 标记，在 Registry 匹配之前处理，避免被错误恢复逻辑清除

3. **SubjectCategory UI 扩展**：放在 `widgets/subject_category_ui.dart`（不在 model 中），通过 extension 提供 IconData/Color

4. **学习计划冲突**：Service 层仅提供 checkTargetConflict() 查询方法 + pauseActivePlans()，弹窗逻辑留给 Screen 层

5. **DB 查询兼容**：`OR exam_type = ''` 确保未标记类型的历史题目始终可见

6. **测试兼容**：新增 setExploreModeSync() 方法供测试环境使用，避免异步 DB 调用导致超时

## 遇到的问题及解决方式

1. **querySubjectRadarData 重复定义**：database_helper.dart 已有同名方法，改为在原方法上增加可选 examTypes 参数，而非新增方法

2. **Widget 测试超时**：enterExploreMode() 在测试环境触发 DB 写入导致 10 分钟超时。解决：增加 setExploreModeSync() 同步方法，测试中直接设置内存状态

3. **sqlite3.dll 文件锁**：并发 flutter test 导致 native_assets 目录锁定。解决：kill dart 进程 + 清理 build/native_assets 目录

4. **profile_screen.dart linter 回退**：文件被 linter 回退后重新应用变更（ExamCategoryService import + 备考目标卡片 + 申论条件显隐）

## 验证结果

- `flutter analyze`: No issues found
- `flutter test`: 37/37 All tests passed
- DB version: 11
