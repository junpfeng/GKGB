# 个性化数据看板

## 核心需求
基于 `docs/advanced-features-design.md` 第八章，提供综合仪表板（今日概览、能力雷达图、学习热力图、备考进度条）、自我对比分析、学习周报。

## 确认方案

核心思路：纯数据聚合功能，不新建 DB 表（查询现有 user_answers/exams/daily_tasks/study_plans），用 DashboardService 汇总数据，fl_chart 绑制雷达图/热力图/折线图，替换现有 StatsScreen 为增强版仪表板。

### 锁定决策

**数据层：**

1. 不新建表，DB version 保持 8。所有数据从现有表聚合：
   - `user_answers` → 答题量、正确率、各科表现、每日活跃度
   - `exams` → 模考成绩趋势
   - `daily_tasks` → 学习计划完成度
   - `study_plans` → 备考进度
   - `interview_sessions` → 面试练习数据

2. 扩展 `DatabaseHelper` 新增聚合查询方法（全部只读）：
   - `queryDailyActivityHeatmap(int days)` → 近 N 天每日答题量（热力图数据）
   - `querySubjectRadarData()` → 各科目正确率（雷达图数据）
   - `queryWeeklyComparison()` → 本周 vs 上周各维度对比
   - `queryStudyStreak()` → 连续打卡天数
   - `queryOverallProgress()` → 总体完成度

**服务层：**

3. 新增 `DashboardService extends ChangeNotifier`：
   - 注入 `QuestionService`（获取统计数据）
   - `refreshDashboard()` → 一次性加载所有仪表板数据
   - `getTodayOverview()` → {answeredToday, correctToday, studyMinutes, daysUntilExam}
   - `getRadarData()` → Map<String, double>（5 科正确率 + 申论 + 公基）
   - `getHeatmapData(int days: 90)` → Map<DateTime, int>（每日答题量）
   - `getWeekComparison()` → {thisWeek: stats, lastWeek: stats}
   - `getScoreTrend()` → 复用 ExamService.getScoreTrend()
   - `generateWeeklyReport()` → Stream<String> LLM 流式周报
   - `getStudyStreak()` → int 连续天数

4. LLM 周报通过注入 LlmManager（ChangeNotifierProxyProvider2）

**UI 层：**

5. 替换现有 StatsScreen 为增强版 `DashboardScreen`：
   - 保留原有统计功能 + 考试日历入口
   - 顶部：今日概览卡片（答题量/正确率/距考试天数）
   - 雷达图：7 维能力值（行测 5 科 + 申论 + 公基）
   - 热力图：类 GitHub 贡献图，近 90 天每日学习强度
   - 趋势折线图：近 10 次模考成绩
   - 本周 vs 上周对比条形图
   - 连续打卡天数徽章
   - 「生成 AI 周报」按钮 → 流式展示

6. 新增 `lib/widgets/radar_chart_widget.dart`：基于 fl_chart RadarChart 封装
7. 新增 `lib/widgets/heatmap_widget.dart`：自定义 Widget（GridView + 颜色渐变格子）

8. 入口：直接替换 HomeScreen 的 StatsScreen 引用为 DashboardScreen（Tab 名称改为「看板」）

9. DashboardService Provider 在 main.dart 注册

**预防性修正：**

10. 聚合查询加缓存：refreshDashboard 结果缓存 5 分钟，避免频繁 DB 查询
11. 热力图数据量可控：限制 90 天，GridView 用 builder
12. 雷达图空数据处理：无答题数据的科目显示 0，不崩溃
13. 周报 LLM 调用用 streamChat 流式展示

**范围边界：**
- 做：今日概览、雷达图、热力图、模考趋势、周对比、连续打卡、AI 周报
- 不做：月报、PDF 导出、预测分析、目标差距分析

### 验收标准
- [mechanical] DashboardService：`ls lib/services/dashboard_service.dart`
- [mechanical] DashboardScreen：`ls lib/screens/dashboard_screen.dart`
- [mechanical] 雷达图组件：`ls lib/widgets/radar_chart_widget.dart`
- [mechanical] 热力图组件：`ls lib/widgets/heatmap_widget.dart`
- [mechanical] Provider 注册：`grep "DashboardService" lib/main.dart`
- [mechanical] HomeScreen 引用替换：`grep "DashboardScreen\|dashboard" lib/screens/home_screen.dart`
- [test] `flutter test`
- [mechanical] `flutter analyze` 零错误
- [manual] 运行 `flutter run -d windows` 验证看板可见
