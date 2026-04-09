# 考试类型差异化服务系统

## 核心需求
当前 app 硬编码了"行测/申论/公基"三科和"130题120分钟"等参数，只适用于国考/省考。需要一套「考试类型配置 + 用户目标选择」机制，让 app 根据用户备考目标（国考/省考/事业编/选调生/三支一扶/人才引进）自动适配科目、题量、时间、功能入口。

## 调研上下文

### 数据库现状
- 当前 DB version = 10，需升级到 11
- `questions` 表已有 `exam_type` 字段（TEXT DEFAULT ''），值为 '国考'/'省考'/'事业编'/'选调'
- `queryQuestions()`、`countQuestions()`、`randomQuestions()` 均未按 exam_type 过滤
- `queryRealExamQuestions()` 已支持 exam_type 过滤
- `real_exam_papers` 和 `exam_calendar` 表已有 exam_type 字段和索引

### Provider 注册模式
- main.dart 注册 17 个 Provider，使用 ChangeNotifierProvider / ChangeNotifierProxyProvider
- AssistantService 使用 ctx.read() 注入 7 个依赖（特殊模式）
- 异步初始化模式：main() 中 await 完成后构建 widget 树

### 硬编码位置
- `practice_screen.dart:21-71` — 7 个科目的完整硬编码（行测5类+申论+公基）
- `exam_screen.dart:79-83` — '130题·120分钟' 硬编码
- `baseline_test_screen.dart:51-67` — 硬编码 3 科目
- `study_plan_screen.dart:61,77` — 硬编码 {'行测','申论'} 和 ['行测','申论','公基']
- `exam_calendar_screen.dart:29` — 硬编码 ['国考','省考','事业编','选调']
- `study_plan_service.dart:71` — 硬编码 ['行测','申论'] 默认科目
- `interview_service.dart:54-60` — 静态 5 个面试分类

### 最相似实现参考
- 现有服务层注入模式：构造函数参数注入（如 `StudyPlanService(questionService, llmManager)`）
- ExamCategory 模型族为全新模块，无直接对标

### 关键文件清单（设计文档已列出 30+ 文件的新建/修改计划）

## 范围边界
- 做：单目标选择（含探索模式）、6 类考试基础配置、8 省省考覆盖、所有现有功能动态适配、空状态处理、全局目标指示器
- 不做：多目标管理、完整 34 省覆盖、人才引进完整支持、事业编 D/E 类、注册表远程更新、底部导航动态调整

## 初步理解
这是一个大规模重构功能，核心是建立 ExamCategoryRegistry（静态注册表）+ UserExamTarget（DB 用户目标）+ ExamCategoryService（中心服务）三层架构，然后将所有硬编码的科目、题量、时间参数替换为动态查询。设计文档已给出完整的 4 Phase 实现计划和详细的数据模型定义。

## 待确认事项
设计文档已非常详尽，关键技术决策均已明确。需确认方案摘要后进入实现。

## 确认方案

方案摘要：考试类型差异化服务系统

核心思路：建立静态注册表 + 用户目标表 + 中心服务三层架构，替换全部硬编码的科目/题量/时间参数，一次性完成 Phase 1-4 全部实现。

### 锁定决策

数据层：
  - 数据模型：新建 ExamCategory/ExamSubType/ExamSubject/SubjectCategory（纯 Dart，非 DB 存储）、UserExamTarget（json_serializable + DB 存储）
  - 数据库变更：v10→v11，新增 user_exam_targets 表，不修改现有表
  - 序列化：UserExamTarget 使用 json_serializable；ExamCategory 族为纯 Dart 静态定义，无需序列化
  - DB 查询增强：queryQuestions/countQuestions/randomQuestions 增加可选 examTypes 参数
  - 省考省份覆盖：v1 用通用默认值 + 仅标记 8 省省份名，不做题量/时间差异

服务层：
  - 新增服务：ExamCategoryService extends ChangeNotifier（中心服务，管理用户目标和活跃配置）
  - ExamCategoryRegistry：纯静态类，定义 6 类考试配置（国考/省考/事业编完整定义，选调生/三支一扶简化，人才引进 comingSoon）
  - LLM 调用：不直接涉及，但 StudyPlanService/AssistantService 的 AI prompt 注入考试类型上下文
  - 外部依赖：无新增 package
  - 学习计划冲突处理：v1 实现完整方案（暂停/恢复）。Service 层仅提供 checkTargetConflict() 查询方法，弹窗逻辑在 Screen 层处理（遵循分层约束）

UI 层：
  - 新增页面：ExamTargetScreen（引导页，7 张卡片选择）
  - 新增组件：ExamTypeBadge（全局考试类型指示器，24-32px 高彩色条）
  - 状态管理：ExamCategoryService 作为 ChangeNotifierProvider 注册在 main.dart 最前面
  - 条件路由：app.dart 中 Consumer<ExamCategoryService> 判断是否显示引导页
  - ProfileScreen：新增备考目标管理卡片

主要技术决策：
  - 一次性实现 Phase 1-4：因各 Phase 紧密耦合，分拆会导致体验割裂
  - 省考数据用通用默认：后续版本补充省份差异数据
  - SubjectCategory 图标/渐变色：参考现有行测科目风格自行配色
  - 下游服务不改 ProxyProvider：构造函数注入 ExamCategoryService 实例
  - 探索模式持久化：写入特殊 UserExamTarget 记录（examCategoryId='__explore__'）。loadTargets() 中优先检测 '__explore__' 标记，在 Registry 匹配之前处理，避免被错误恢复逻辑清除

技术细节：
  - ExamCategory 字段：id, label, description, scope, requiresProvince, contentStatus, subTypes, defaultSubjects, interviewCategories, dbExamTypeValues, supportedFeatures
  - ExamSubject 字段：subject, label, defaultQuestionCount, defaultTimeLimitSeconds, totalScore, categories
  - SubjectCategory 字段：category, label, iconCodePoint, iconFontFamily, gradientColors
  - UserExamTarget 字段：id, examCategoryId, subTypeId, province, isPrimary, targetExamDate, createdAt, updatedAt
  - ExamCategoryService 关键接口：loadTargets(), setTarget(), enterExploreMode(), removeTarget(), getExamConfig(), getSubjectsForPlan(), isFeatureSupported()
  - DB 查询 WHERE 子句：exam_type IN (?) OR exam_type = ''（兼容历史数据）
  - 切换目标时 UI 刷新：setTarget() 用 db.transaction() 包裹全部 DB 写入，事务提交后一次性更新所有内存字段（_activeCategory/_activeSubType/_primaryTarget），最后单次 notifyListeners() → HomeScreen 重置索引 → DashboardService 强制刷新
  - 学习计划冲突：Service 提供 checkTargetConflict() 返回冲突信息 → Screen 层弹确认对话框 → 确认后调用 setTarget() 暂停旧计划(status='paused') → StudyPlanScreen 显示恢复按钮
  - UserExamTarget.isPrimary：model 增加 bool get isPrimaryTarget => isPrimary == 1，写入时固定 0/1
  - study_plans.status 新增 'paused' 值：实现引擎需审查所有 status 相关查询确保不误处理 paused 状态

范围边界：
  - 做：单目标选择（含探索模式）、6 类考试基础配置、8 省省考标记、所有现有功能动态适配、空状态处理、全局目标指示器、学习计划冲突处理
  - 不做：多目标管理、完整 34 省差异数据、人才引进完整支持、事业编 D/E 类、注册表远程更新、底部导航动态调整

### 待细化
  - 事业编 B/C 类的具体科目配置（方向已定，细节由实现引擎补充）
  - 选调生/三支一扶的简化科目配置细节
  - 各科目 SubjectCategory 的具体 iconCodePoint 和 gradientColors 值
  - DB 查询 OR exam_type='' 条件在大数据量下的性能：评估是否需要 UNION ALL 替代
  - 引导页→主页切换过渡动画（LOW，不阻塞）

### 验收标准
  - [mechanical] 新文件存在：判定 `grep -r "ExamCategory" lib/models/exam_category.dart`
  - [mechanical] 新文件存在：判定 `grep -r "ExamCategoryRegistry" lib/models/exam_category_registry.dart`
  - [mechanical] 新文件存在：判定 `grep -r "UserExamTarget" lib/models/user_exam_target.dart`
  - [mechanical] 新文件存在：判定 `grep -r "ExamCategoryService" lib/services/exam_category_service.dart`
  - [mechanical] 新文件存在：判定 `grep -r "ExamTargetScreen" lib/screens/exam_target_screen.dart`
  - [mechanical] 新文件存在：判定 `grep -r "ExamTypeBadge" lib/widgets/exam_type_badge.dart`
  - [mechanical] DB version 升级：判定 `grep "version: 11" lib/db/database_helper.dart`
  - [mechanical] Provider 注册：判定 `grep "ExamCategoryService" lib/main.dart`
  - [mechanical] 硬编码移除：判定 `grep -c "130题" lib/screens/exam_screen.dart` 返回 0
  - [test] 全部测试通过：`flutter test`
  - [mechanical] 零 analyze 错误：`flutter analyze`
  - [manual] 首次启动显示引导页 → 选择国考 → 刷题页显示行测5类+申论
  - [manual] 切换到事业编A类 → 刷题页显示"职测"/"综合"，申论训练入口隐藏
  - [manual] 选择"先看看" → 探索模式 → 顶部显示引导 Banner
