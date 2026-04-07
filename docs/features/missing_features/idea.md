# 补齐所有缺失功能

## 核心需求
补齐产品设计文档中所有未实现的功能，包括摸底测试、成绩趋势图、申论批改、模考细分、里程碑提醒、学习计划自动调整、错题推荐、公告智能获取。

## 调研上下文
基于 full_app 实现后的差距分析，当前完成度约 82%，缺失 8 项功能。现有代码架构完整（models/services/screens/widgets 四层），可在现有基础上扩展。

## 范围边界
- 做：8项缺失功能（摸底测试、趋势图、申论批改、模考细分、里程碑提醒、自动调整、错题推荐、公告智能获取）
- 不做：公告定时爬虫、云端同步、WorkManager后台任务、PDF/Excel解析、系统推送通知

## 初步理解
在现有代码上扩展，不新建数据库表，DB version 升到 3 增加字段。新增 1 个 Service + 1 个 Screen，其余为扩展现有文件。

## 待确认事项
无（已全部确认）

## 确认方案

核心思路：在现有代码基础上扩展 8 项功能，不新建表，DB version 升到 3

### 锁定决策

数据层：
  - user_answers 表增加 is_baseline INTEGER DEFAULT 0（区分摸底测试答题）
  - study_plans 表增加 auto_adjusted_at TEXT（记录上次自动调整时间）
  - DB version 3，onUpgrade 处理 v2→v3 迁移
  - 新增依赖：fl_chart（趋势图）、html（URL导入时解析网页）

服务层：
  - 新增 BaselineService（ChangeNotifier）：每科抽题、评估基线、生成基线报告
  - 扩展 ExamService：按行测5科细分统计、历史成绩趋势数据
  - 扩展 QuestionService：申论批改 prompt + AI 流式返回、错题关联推荐
  - 扩展 StudyPlanService：自动调整（直接修改 daily_tasks）、里程碑检测
  - 扩展 MatchService：AI联网搜索公告、URL导入解析、剪贴板文本导入
  - 公告搜索：LlmManager.chat() 生成搜索关键词 → Dio 调用搜索 → AI 解析结果

UI 层：
  - 新增 BaselineTestScreen：选科→快速10题测试→基线报告→自动生成学习计划
  - 扩展 StatsScreen：新增"趋势"Tab，用 fl_chart LineChart 展示各科成绩曲线
  - 扩展 ExamReportScreen：增加行测5科柱状图细分
  - 扩展 QuestionCard：主观题输入框 + "AI批改"按钮 → AiChatDialog 流式批改
  - 扩展 StudyPlanScreen：里程碑提醒横幅 + "自动调整"按钮
  - 扩展 PolicyMatchScreen：
    - "智能搜索"按钮 → AI联网搜索公告 → 结果预览 → 一键入库
    - "URL导入"按钮 → 粘贴链接 → 抓取解析
    - "粘贴导入"按钮 → 剪贴板文本 → AI解析

状态管理：
  - 新增 BaselineService 注册到 main.dart（依赖 QuestionService）
  - 其余复用现有 Provider

主要技术决策：
  - 摸底测试：每科随机抽10题，独立于模考。原因：轻量快速，不影响模考历史
  - 趋势图：fl_chart LineChart，放在 StatsScreen 新 Tab。原因：统计页是数据可视化的自然位置
  - 申论批改：复用 QuestionCard + AiChatDialog，streamChat()。原因：不新建页面，交互一致
  - 里程碑提醒：应用内横幅，不做系统通知。原因：避免引入通知权限复杂度
  - 公告搜索：LLM 生成搜索词 + WebSearch/Dio 搜索 + LLM 解析。原因：比固定爬虫更灵活
  - URL导入：Dio GET 网页 → html 包提取正文 → LLM 解析为岗位。原因：轻量，无需 headless browser
  - 自动调整：直接修改 daily_tasks 的 target_count，薄弱科 +30%，强项 -20%。原因：可感知的变化

技术细节：
  - BaselineService：
    - startBaseline(List<String> subjects) → 每科抽10题
    - submitBaseline() → 计算各科正确率 → 写入 study_plans.baseline_scores
    - getBaselineReport() → Map<String, double> 各科基线分
  - ExamService 扩展：
    - getCategoryStats(int examId) → Map<String, {correct, total}> 行测5科细分
    - getScoreTrend(String subject, int limit) → List<{date, score}> 趋势数据
  - QuestionService 扩展：
    - gradeEssay(Question q, String answer) → Stream<String> AI批改流
    - getRelatedQuestions(String subject, String category, int limit) → 关联推荐
  - StudyPlanService 扩展：
    - autoAdjust(int planId) → 直接修改 daily_tasks + 记录调整日志
    - checkMilestones(int planId) → List<Milestone> 距考试天数提醒
  - MatchService 扩展：
    - searchPoliciesOnline(String targetCities) → AI搜索+解析公告列表
    - importFromUrl(String url) → Dio抓取+AI解析
    - importFromClipboard(String text) → AI解析（复用已有 aiParsePolicy）

范围边界：
  - 做：8项缺失功能全部实现
  - 不做：公告定时爬虫、云端同步、WorkManager后台任务、PDF/Excel解析、系统推送通知

### 待细化
  - AI联网搜索的具体搜索引擎选择：引擎实现时根据可用API决定
  - 趋势图的时间范围选择（7天/30天/全部）：引擎实现时补充UI

### 验收标准
  - [mechanical] BaselineTestScreen 存在：判定 `grep -r "BaselineTestScreen" lib/screens/`
  - [mechanical] fl_chart 在 pubspec.yaml 中：判定 `grep fl_chart pubspec.yaml`
  - [mechanical] DB version 为 3：判定 `grep "version: 3" lib/db/database_helper.dart`
  - [test] 全量测试通过：`flutter test`
  - [mechanical] flutter analyze 零错误：`flutter analyze`
  - [manual] 摸底测试：运行 `flutter run -d windows` 验证 `我的→摸底测试→选科→答题→查看基线报告`
  - [manual] 趋势图：验证 `统计Tab→趋势→各科成绩折线图展示`
  - [manual] 申论批改：验证 `刷题→申论题→输入答案→AI批改→流式返回批改结果`
  - [manual] 公告搜索：验证 `岗位Tab→智能搜索→输入城市→AI搜索→结果预览→入库`
  - [manual] 自动调整：验证 `学习计划→自动调整→每日任务数量变化`
