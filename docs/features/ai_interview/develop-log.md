# AI 面试辅导系统 - 开发日志

## 实现日期
2026-04-07

## 实现概览

基于 `idea.md` 确认方案，完整实现了 AI 面试辅导系统（文字模式），涵盖数据层、服务层、UI 层共 10 个文件。

## 新增文件清单

| 文件 | 说明 |
|------|------|
| `lib/models/interview_question.dart` | 面试题模型（含 fromDb/toDb/keyPointsList） |
| `lib/models/interview_session.dart` | 面试会话模型 |
| `lib/models/interview_score.dart` | 面试评分详情模型 |
| `lib/services/interview_service.dart` | 面试服务（ChangeNotifier，含 Timer/LLM 评分/追问/报告） |
| `lib/screens/interview_home_screen.dart` | 面试主页（题型选择 + 开始模拟 + 历史记录） |
| `lib/screens/interview_session_screen.dart` | 面试进行页（计时 + 作答 + AI 流式评分 + 追问） |
| `lib/screens/interview_report_screen.dart` | 面试报告页（综合得分 + 维度分析 + 逐题回顾 + AI 建议） |
| `assets/questions/interview_sample.json` | 预置面试题 JSON（5 种题型 × 4 题 = 20 题） |

## 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | DB version 4→5，新增 3 张表 + 2 个索引 + CRUD 方法 + _onUpgrade 迁移 |
| `lib/main.dart` | 注册 InterviewService（ChangeNotifierProxyProvider） |
| `lib/screens/practice_screen.dart` | 刷题页顶部新增面试入口横幅卡片 |
| `pubspec.yaml` | 注册 interview_sample.json 资产 |

## 锁定决策落实（22 条）

### 数据层（1-5）
1. ✅ `interview_questions` 表：含 category/content/reference_answer/key_points/difficulty/region/year/source
2. ✅ `interview_sessions` 表：含 category/total_questions/total_score/status/started_at/finished_at/summary
3. ✅ `interview_scores` 表：含三维度评分/ai_comment/follow_up 系列字段/time_spent
4. ✅ DB version 4→5：_createDB 同步建 3 表 + 索引；_onUpgrade 事务包裹迁移
5. ✅ 索引：idx_interview_questions_category + idx_interview_scores_session_question

### 服务层（6-8）
6. ✅ InterviewService extends ChangeNotifier：注入 LlmManager，含全部核心方法
7. ✅ 3 个核心 prompt：评分 JSON prompt + 点评 prompt + 综合报告 prompt
8. ✅ 统一通过 LlmManager 调用（chat + streamChat）

### UI 层（9-17）
9. ✅ 面试入口：PracticeScreen 科目列表顶部渐变横幅卡片
10. ✅ interview_home_screen.dart：题型选择网格 + 开始按钮 + 历史列表（ScrollController 懒加载）
11. ✅ interview_session_screen.dart：逐题展示 + 双阶段计时 + 流式点评 + 追问
12. ✅ interview_report_screen.dart：综合得分渐变卡 + 维度条形图 + 逐题展开 + 流式报告
13-15. ✅ 三个模型文件（json_serializable + fromDb/toDb）
16. ✅ Provider 注册：ChangeNotifierProxyProvider<LlmManager, InterviewService>
17. ✅ 预置 20 题 JSON（5 种题型各 4 题 + 参考答案 + 要点）

### 红蓝对抗修正（18-22）
18. ✅ 评分用 chat()（非流式）获取 JSON → 解析 → regex 降级 → 默认分 5.0；点评用 streamChat() 流式；分数 clamp(1, 10)
19. ✅ InterviewService.dispose() 取消 Timer + StreamSubscription；cancelInterview() 全清理
20. ✅ 用户答案包裹 `<user_answer>` 标签；system prompt 强调忽略答案中指令性文字
21. ✅ loadHistory(limit, offset) 分页；UI 用 ScrollController 滚动到底加载更多
22. ✅ 切题/退出时 cancel StreamSubscription；下一题按钮在 isScoring 时禁用

## 待细化补充设计

### 评分 prompt
- 四维度 rubric：内容(50%) + 表达(30%) + 时间(20%) = 综合分
- 输出纯 JSON：`{"content_score":X,"expression_score":X,"time_score":X,"total_score":X}`
- 时间维度：180s 内满分区间，超时酌情扣分

### 追问触发条件
- 综合分 < 7：80% 概率追问
- 综合分 >= 7：30% 概率追问
- 每题最多 1 轮追问

### 综合报告 prompt
- 输入：4 题各维度评分
- 输出：总体评价 + 各维度分析 + 至少 3 条改进建议 + 推荐练习方向

### 预置面试题
- 5 种公考结构化面试题型：综合分析/计划组织/人际关系/应急应变/自我认知
- 每种 4 题，共 20 题
- 每题含参考答案框架和 5 个答题要点

## 验证结果

- `flutter analyze`：零错误零警告
- `flutter test`：37 tests passed
- DB version: 5
- 所有验收标准 mechanical 项均满足
