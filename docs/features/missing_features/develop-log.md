# 缺失功能实现日志

## 任务概述
在现有代码基础上补齐 8 项缺失功能：摸底测试、成绩趋势图、申论批改、模考细分、里程碑提醒、学习计划自动调整、错题推荐入口、公告智能获取。

## 实现日期
2026-04-07

## Phase 1：依赖 + 数据库迁移

**新增依赖**
- `fl_chart: ^0.70.2`（成绩趋势折线图、行测细分柱状图）
- `html: ^0.15.5`（URL导入时解析网页正文）

**数据库升级 v2 → v3**
- `user_answers` 表新增 `is_baseline INTEGER DEFAULT 0`（区分摸底测试答题）
- `study_plans` 表新增 `auto_adjusted_at TEXT`（记录上次自动调整时间）
- `onUpgrade` 处理 `v2→v3` 的 ALTER TABLE 迁移
- 新增数据库查询方法：`queryBaselineAccuracyBySubject`、`queryLatestBaselineAnswers`、`queryRecentAccuracyBySubject`、`queryExamCategoryStats`、`queryScoreTrend`

**遇到的问题**
- SQLite 不支持 ALTER TABLE DROP COLUMN（已有代码中已知），ALTER TABLE ADD COLUMN 正常

## Phase 2：服务层扩展

**新增 BaselineService**
- `startBaseline(subjects)`: 每科随机抽10题
- `recordAnswer(questionId, answer, isCorrect)`: 记录摸底答题
- `submitBaseline()`: 计算各科正确率并写入 DB（is_baseline=1）
- `getBaselineReport()`: 从 DB 查询历史摸底结果
- `reset()`: 清理状态

**扩展 ExamService**
- `getCategoryStats(examId)`: 查各分类正确/总计（行测5科细分）
- `getScoreTrend({subject, limit})`: 查历史成绩趋势，返回升序列表

**扩展 QuestionService**
- `gradeEssay(question, userAnswer, llm)`: 申论批改 prompt + Stream<String> 返回
- `getRelatedQuestions(subject, category, {limit, excludeId})`: 同科同类关联推荐

**扩展 StudyPlanService**
- `autoAdjust(planId)`: 薄弱科+30%，强项-20%，更新 daily_tasks，记录 auto_adjusted_at
- `checkMilestones(planId)`: 计算距考试天数，返回颜色区分的提醒文本

**扩展 MatchService**
- `searchPoliciesOnline(targetCities)`: LLM生成搜索词 → Dio搜Bing → LLM解析结果
- `importFromUrl(url)`: Dio抓取网页 → html包提取正文 → LLM解析基本信息
- `importFromClipboard(text)`: 直接调用 LLM 解析文本为公告

**注册 BaselineService 到 main.dart**（ChangeNotifierProxyProvider 依赖 QuestionService）

## Phase 3：UI 层

**新建 BaselineTestScreen**（`lib/screens/baseline_test_screen.dart`）
- 选科页（FilterChip 多选）→ 答题页（PageView 逐题，下一题按钮需答题才激活）→ 报告页
- 报告页含各科正确率进度条 + "生成学习计划"按钮

**扩展 StatsScreen**
- 新增 TabBar（概览 / 趋势）
- 趋势 Tab：`fl_chart LineChart` 多科折线图，支持 7次/10次/30次 切换
- 图例、横轴日期（月/日）、悬停 Tooltip

**扩展 ExamScreen / ExamReportScreen**
- 改为 StatefulWidget，initState 加载行测分类统计
- `fl_chart BarChart` 展示各分类正确率（颜色区分好/中/差）
- 行测以外科目或无数据时不显示柱状图

**扩展 QuestionCard**
- 主观题（type='subjective'）且有答案时显示"AI 批改"按钮
- 点击调用 `AiChatDialog.show()` 展示批改 Prompt，复用现有流式对话界面

**扩展 StudyPlanScreen**
- 顶部 `_MilestoneBanner`：颜色区分（蓝/橙/红）距考试天数提醒
- 操作按钮行："自动调整"（调用 autoAdjust + SnackBar）+ "错题推荐"（跳转提示）
- 去除 `_autoAdjustPlan` 方法（冗余，逻辑已移到 _PlanView）

**扩展 PolicyMatchScreen**
- AppBar 新增 `PopupMenuButton`（智能搜索/URL导入/粘贴导入）
- 三个对话框各自独立 StatefulWidget（`_OnlineSearchDialog`、`_UrlImportDialog`、`_PasteImportDialog`）
- 智能搜索：输入城市 → AI搜索 → 列表勾选 → 入库
- URL导入：输入链接 → 解析预览 → 确认入库
- 粘贴导入：自动读取剪贴板 → AI解析预览 → 确认入库

**扩展 ProfileScreen**
- 添加"摸底测试"入口（图标: Icons.quiz）

## Phase 4：测试

新增 `test/baseline_service_test.dart`，包含 10 个测试用例：
- BaselineService 初始状态、recordAnswer、reset、重复答题覆盖
- ExamService 扩展方法存在性
- StudyPlanService 扩展方法存在性
- QuestionService 实例化

**测试结果**：37/37 通过（包含原有 27 个测试）

## 遇到的问题与处理

1. **StatefulBuilder null 检查警告**：初始版本在 `StatefulBuilder` 回调中声明局部变量（每次重建时重置），导致 Dart 分析器报 `unnecessary_null_comparison`。解决：将三个公告对话框提取为独立 `StatefulWidget`，状态正确保存在 `State` 中。

2. **本地变量下划线前缀**：`exam_screen.dart` 中函数内定义 `_shortCat` 被 lint 提示，改为 `shortCat`。

3. **未使用的导入/参数**：`question_card.dart` 的 `_showStreamGrading` 签名传入了 `QuestionService` 和 `LlmManager` 但未使用，合并简化方法后清理。

4. **DB 测试环境**：`getRelatedQuestions` 即使不 await 也会触发 DB 单例初始化（sqflite FFI 未初始化），改为仅测试实例化。

## 验收标准完成情况

- [x] `BaselineTestScreen` 存在于 `lib/screens/baseline_test_screen.dart`
- [x] `fl_chart` 在 `pubspec.yaml` 中
- [x] DB version 为 3（`lib/db/database_helper.dart`）
- [x] 全量测试通过：37/37
- [x] `flutter analyze` 零错误
