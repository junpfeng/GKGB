# 错题深度分析与知识图谱

## 核心需求
基于 `docs/advanced-features-design.md` 第六章，为现有错题本增加深度分析能力：AI 错因标注（5 种类型）、错因分布统计、高频错误知识点 TOP 10、知识图谱可视化、AI 诊断报告。

## 调研上下文

### 现有错题系统
- `user_answers` 表有 is_correct 字段，缺少 error_type
- QuestionService.loadWrongQuestions() 查询错题
- PracticeScreen Tab 2 是错题本（_WrongQuestionList）
- questions 表有 subject/category 分类

### 现有图表能力
- fl_chart 已安装（条形图、折线图已在使用）
- 无图谱可视化包

### 现有 LLM
- LlmManager.chat() / streamChat() 可用于错因分析

## 范围边界
- 做：user_answers 扩展 error_type、AI 错因分析、错因分布饼图、高频错误知识点 TOP 10、简化知识图谱（树状，非网状）、AI 诊断报告
- 不做：知识点关联图谱网状可视化（graphview 复杂度高）、每周自动生成报告（需后台定时，后续迭代）、知识点掌握度评分系统（P2 自适应出题功能）

## 确认方案

核心思路：扩展 user_answers 增加 error_type 字段，答错后 AI 异步分析错因，新增错题分析主页（错因饼图 + TOP 10 + 简化知识图谱 + AI 诊断报告），入口在错题本 Tab 顶部。

### 锁定决策

**数据层：**

1. `user_answers` 表 ALTER 新增 `error_type TEXT DEFAULT ''`
   - 5 种类型：blind_spot / confusion / careless / timeout / trap
   - 正确答案和未分析的记录留空

2. DB version 6 → 7：
   - `_createDB` 同步包含 error_type 字段
   - `_onUpgrade` 中 `if (oldVersion < 7)` 事务包裹 ALTER

3. 新增索引：`idx_user_answers_error_type ON user_answers(error_type)` 加速错因统计

**服务层：**

4. 新增 `WrongAnalysisService extends ChangeNotifier`：
   - 构造函数注入 `QuestionService` + `LlmManager`
   - `analyzeError(Question question, String userAnswer, String correctAnswer)` → 调用 `LlmManager.chat()` 分析错因，返回 error_type 字符串，失败返回空
   - `getErrorTypeDistribution({String? subject})` → `Map<String, int>` 各错因数量
   - `getTopWrongCategories({int limit: 10})` → 高频错误分类 TOP N
   - `getCategoryAccuracy()` → `Map<String, double>` 各分类正确率（知识图谱用）
   - `generateDiagnosisReport()` → `Stream<String>` LLM 流式诊断报告（基于近 7 天错题）
   - `getRecentWrongStats({int days: 7})` → 近 N 天错题统计摘要

5. 扩展 `DatabaseHelper`：
   - `updateAnswerErrorType(int answerId, String errorType)`
   - `queryErrorTypeDistribution({String? subject})` → GROUP BY error_type 统计
   - `queryTopWrongCategories({int limit})` → JOIN questions 表 GROUP BY category ORDER BY count DESC
   - `queryCategoryAccuracy()` → 各 category 的 correct/total

6. 扩展 `QuestionService.submitAnswer()`：答案错误时异步调用 `WrongAnalysisService.analyzeError()`，不阻塞 UI

7. LLM 错因分析 prompt：输入题目+用户答案+正确答案 → 输出 JSON `{"error_type": "blind_spot", "analysis": "..."}` + regex 降级

**UI 层：**

8. 入口：PracticeScreen 错题本 Tab 顶部增加「错题深度分析」入口卡片

9. 新增 `lib/screens/wrong_analysis_screen.dart`：
   - 顶部：错因分布饼图（fl_chart PieChart，5 种颜色）
   - 中部：高频错误知识点 TOP 10 列表（分类名 + 错题数 + 正确率进度条）
   - 底部：「生成 AI 诊断报告」按钮 → 流式展示报告

10. 新增 `lib/screens/knowledge_map_screen.dart`：
    - 简化知识图谱：按科目分组，每科下展示各 category 卡片
    - 卡片颜色渐变：正确率 >= 80% 绿色、60-80% 黄色、< 60% 红色
    - 点击卡片进入该分类的专项练习（复用 QuestionListScreen）
    - 入口在 wrong_analysis_screen 中

11. 新增模型（非 DB 表，纯数据类）：
    - `lib/models/error_analysis.dart` — ErrorAnalysis（error_type + analysis 文本）

12. `WrongAnalysisService` Provider 在 `main.dart` 注册（ChangeNotifierProxyProvider2 注入 QuestionService + LlmManager）

**红蓝对抗修正：**

13. **消除循环依赖**：WrongAnalysisService 只注入 LlmManager（不注入 QuestionService），直接用 DatabaseHelper.instance。错因分析由 Screen 层编排（submitAnswer 后判断 isCorrect=false 再调用 analyzeError），不在 QuestionService 内部调用
14. LLM 分析改用 `streamChat()` + join + `timeout(15s)`，避免 chat() 无超时控制
15. 用户答案用 `<user_answer>` 标签包裹防 prompt 注入
16. 饼图数据为空时（无错题）显示友好提示而非空图
17. getCategoryAccuracy 需 LEFT JOIN 确保无答题记录的分类也显示
18. UserAnswer 模型同步增加 `errorType` 字段 + fromDb/toDb 更新
19. 补复合索引 `idx_user_answers_correct_question ON user_answers(is_correct, question_id)`
20. Provider 注册改为 `ChangeNotifierProxyProvider<LlmManager, WrongAnalysisService>`（单依赖）

**范围边界：**
- 做：error_type 字段、AI 错因分析（异步）、错因饼图、TOP 10、简化知识图谱（树状）、AI 诊断报告（手动触发流式）
- 不做：graphview 网状图谱、自动周报、知识点掌握度评分、知识点前置依赖关系

### 待细化
- 错因分析 LLM prompt 具体内容
- 诊断报告 prompt 具体内容
- 知识图谱卡片的 UI 布局细节

### 验收标准
- [mechanical] error_type 字段存在：判定 `grep -c "error_type" lib/db/database_helper.dart` >= 1
- [mechanical] WrongAnalysisService 存在：判定 `ls lib/services/wrong_analysis_service.dart`
- [mechanical] 错题分析页面存在：判定 `ls lib/screens/wrong_analysis_screen.dart`
- [mechanical] 知识图谱页面存在：判定 `ls lib/screens/knowledge_map_screen.dart`
- [mechanical] Provider 注册：判定 `grep "WrongAnalysisService" lib/main.dart`
- [mechanical] DB version 7：判定 `grep "version: 7" lib/db/database_helper.dart`
- [mechanical] 入口在错题本：判定 `grep -c "analysis\|分析" lib/screens/practice_screen.dart` >= 1
- [test] 全量测试通过：`flutter test`
- [mechanical] 零分析错误：`flutter analyze`
- [manual] 运行 `flutter run -d windows` 验证：错题本顶部出现分析入口，饼图/TOP10/知识图谱/AI 报告可用
