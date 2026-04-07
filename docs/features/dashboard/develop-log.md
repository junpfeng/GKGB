# 个性化数据看板 - 开发日志

## 实现概要

基于 `docs/features/dashboard/idea.md` 锁定的 13 条决策，完整实现个性化数据看板功能。

## 变更文件清单

### 新增文件
| 文件 | 说明 |
|------|------|
| `lib/services/dashboard_service.dart` | 看板服务（数据聚合 + 5 分钟缓存 + AI 周报流式生成） |
| `lib/widgets/radar_chart_widget.dart` | 能力雷达图组件（fl_chart RadarChart，7 维默认科目） |
| `lib/widgets/heatmap_widget.dart` | 学习热力图组件（GridView + 绿色系渐变，类 GitHub） |
| `lib/screens/dashboard_screen.dart` | 数据看板页面（替换原 StatsScreen） |

### 修改文件
| 文件 | 变更内容 |
|------|----------|
| `lib/db/database_helper.dart` | 新增 5 个聚合查询方法（只读），DB version 保持 8 |
| `lib/screens/home_screen.dart` | Tab 引用从 StatsScreen → DashboardScreen，标签「统计」→「看板」 |
| `lib/main.dart` | 注册 DashboardService Provider（ChangeNotifierProxyProvider3） |
| `test/widget_test.dart` | 添加 DashboardService/CalendarService Provider，标签断言更新 |

## 锁定决策执行情况

| # | 决策 | 状态 |
|---|------|------|
| 1 | 不新建表，DB version 保持 8 | ✅ 仅新增聚合查询方法 |
| 2 | DatabaseHelper 新增聚合查询 | ✅ queryDailyActivityHeatmap / querySubjectRadarData / queryWeeklyComparison / queryStudyStreak / queryOverallProgress |
| 3 | DashboardService extends ChangeNotifier | ✅ 含 refreshDashboard / generateWeeklyReport 等 |
| 4 | LLM 周报通过 LlmManager 注入 | ✅ ChangeNotifierProxyProvider3 |
| 5 | 替换 StatsScreen 为 DashboardScreen | ✅ 保留考试日历入口 |
| 6 | RadarChartWidget 基于 fl_chart | ✅ RadarChart 封装，7 维默认科目 |
| 7 | HeatmapWidget 自定义 GridView | ✅ 绿色系 4 级渐变 + Tooltip |
| 8 | HomeScreen Tab 引用替换 | ✅ 标签改为「看板」 |
| 9 | Provider 在 main.dart 注册 | ✅ |
| 10 | 聚合查询缓存 5 分钟 | ✅ _cacheDuration = Duration(minutes: 5) |
| 11 | 热力图限制 90 天 + builder | ✅ ListView.builder 横向滚动 |
| 12 | 雷达图空数据处理 | ✅ 无数据科目显示 0，不足 3 维显示提示 |
| 13 | 周报 streamChat 流式 | ✅ Stream.listen 逐字展示 |

## 看板模块组成

1. **考试日历入口** — 渐变卡片，保留原有功能
2. **今日概览** — 三栏渐变卡片（做题量/正确数/正确率）
3. **连续打卡 + 备考进度** — 火焰徽章 + ProgressRing
4. **能力雷达图** — 7 维多边形（行测 5 科 + 申论 + 公基）
5. **学习热力图** — 近 90 天 GitHub 风格贡献图
6. **模考成绩趋势** — fl_chart 折线图（近 10 次）
7. **本周 vs 上周** — 双条对比（做题量 + 正确率）
8. **AI 学习周报** — 流式生成，LLM 分析学习数据

## 验证结果

- `flutter analyze` — ✅ No issues found
- `flutter test` — ✅ All 37 tests passed
