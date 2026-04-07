# AI 面试辅导系统（文字模式）

## 核心需求
基于 `docs/advanced-features-design.md` 第二章，实现公考结构化面试文字模拟训练：面试题库、AI 模拟面试（文字模式）、多维度评分反馈、历史面试记录。本期不做语音模式。

## 调研上下文

### LLM 集成架构
- `LlmManager` 提供 `chat()` / `streamChat()` 方法，支持 fallback
- `ChatMessage(role, content)` 数据结构
- `AiChatDialog` 提供流式对话 UI（frosted glass bottom sheet + markdown 渲染）
- `AssistantService` 有工具执行模式（[ACTION:...] 标签解析）

### 现有考试流程
- `ExamService` 管理考试生命周期：startExam → recordAnswer → submitExam
- 有计时器（Timer + remainingSeconds）、评分、历史记录
- `ExamReportScreen` 展示考后分析（分数卡片 + 分类统计 + AI 分析入口）

### 现有 UI 组件可复用
- `AiChatDialog` 流式对话框（streaming + markdown + auto-scroll）
- `QuestionCard` 题目展示（支持主观题 textarea）
- `GradientButton`、`GlassCard` 样式组件
- `flutter_markdown` 富文本渲染

### 现有首页导航
- 5 个 Tab（刷题、模考、匹配、统计、个人），已满
- 面试入口需要放在已有 Tab 内或替换某个 Tab

## 范围边界
- 做：面试题库（结构化面试 5 种题型）、文字模拟面试（计时 + AI 出题 + 文字作答 + 即时点评）、多维度评分、历史记录、AI 考官追问
- 不做：语音模式（STT/TTS）、无领导小组讨论、面试技巧知识库（后续迭代）、面试能力雷达图（后续迭代）、按岗位分类题库

## 初步理解
1. **数据层**：3 张新表（interview_questions、interview_sessions、interview_scores）
2. **服务层**：新增 InterviewService，通过 LlmManager 做 AI 出题/评分/追问
3. **UI 层**：面试主页（题库浏览 + 开始模拟）、模拟面试进行页（计时 + 逐题作答）、评分报告页

## 待确认事项
1. 面试入口放在哪里？
2. 面试题库是否需要预置数据？
3. AI 考官追问的实现方式？
4. 评分维度和存储方式？

## 确认方案

核心思路：新建面试题库独立表 + 模拟面试会话表 + 评分表，通过 InterviewService 管理面试流程（AI 出题 → 计时作答 → LLM 评分点评 → 追问），在刷题 Tab 首页增加面试练习入口。

### 锁定决策

**数据层：**

1. 新增 `interview_questions` 表（面试题库，独立于 questions 表）：
   ```sql
   CREATE TABLE interview_questions (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     category TEXT NOT NULL,         -- 综合分析/计划组织/人际关系/应急应变/自我认知
     content TEXT NOT NULL,          -- 题目正文
     reference_answer TEXT,          -- 参考答案框架
     key_points TEXT,                -- JSON 数组，答题要点
     difficulty INTEGER DEFAULT 3,   -- 1-5
     region TEXT DEFAULT '',         -- 地区（空表示通用）
     year INTEGER DEFAULT 0,        -- 年份（0 表示模拟题）
     source TEXT DEFAULT '',        -- 来源说明
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

2. 新增 `interview_sessions` 表（模拟面试记录）：
   ```sql
   CREATE TABLE interview_sessions (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     category TEXT NOT NULL,          -- 题型或"综合随机"
     total_questions INTEGER NOT NULL,
     total_score REAL DEFAULT 0,      -- 综合得分（各题平均）
     status TEXT DEFAULT 'ongoing',   -- ongoing/finished/cancelled
     started_at TEXT,
     finished_at TEXT,
     summary TEXT                     -- AI 生成的综合评价
   )
   ```

3. 新增 `interview_scores` 表（每题评分详情）：
   ```sql
   CREATE TABLE interview_scores (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     session_id INTEGER NOT NULL,
     question_id INTEGER NOT NULL,
     user_answer TEXT NOT NULL,        -- 用户作答内容
     content_score REAL DEFAULT 0,     -- 内容维度 1-10
     expression_score REAL DEFAULT 0,  -- 表达维度 1-10
     time_score REAL DEFAULT 0,        -- 时间维度 1-10
     total_score REAL DEFAULT 0,       -- 综合分
     ai_comment TEXT,                  -- AI 逐题点评
     follow_up_question TEXT,          -- AI 追问（可为空）
     follow_up_answer TEXT,            -- 用户追问回答（可为空）
     follow_up_comment TEXT,           -- 追问点评（可为空）
     time_spent INTEGER DEFAULT 0,     -- 实际作答秒数
     answered_at TEXT DEFAULT CURRENT_TIMESTAMP,
     FOREIGN KEY (session_id) REFERENCES interview_sessions (id),
     FOREIGN KEY (question_id) REFERENCES interview_questions (id)
   )
   ```

4. DB version 4 → 5：
   - `_createDB` 同步添加 3 张新表 + 索引（全新安装路径）
   - `_onUpgrade` 中 `if (oldVersion < 5)` 事务包裹建表迁移
   - `interview_questions` 添加 `UNIQUE(category, content)` 约束防重复导入

5. 新增索引：
   - `idx_interview_questions_category ON interview_questions(category)`
   - `idx_interview_scores_session_question ON interview_scores(session_id, question_id)`

**红蓝对抗修正（R-02/R-03/R-06/R-08/R-09）：**

18. LLM 调用拆分策略：
    - 评分用 `LlmManager.chat()`（非流式）获取完整 JSON，解析失败时 regex 提取分数或给默认分并提示
    - 点评文本用 `LlmManager.streamChat()` 流式展示
    - JSON 分数范围校验：1-10，超范围截断

19. Timer 安全：InterviewService 必须 `dispose()` 取消 Timer，面试页退出时调用 `cancelInterview()` 清理

20. Prompt 注入防护：用户答案用 `<user_answer>...</user_answer>` 标记包裹，system prompt 强调忽略答案中的指令性文字

21. 历史记录分页：`loadHistory({limit: 20, offset: 0})`，UI 用 ListView.builder + ScrollController 懒加载

22. 流式竞争防护：切题时 cancel StreamSubscription，"下一题"按钮在评分完成前禁用

**服务层：**

6. 新增 `InterviewService extends ChangeNotifier`：
   - 构造函数注入 `LlmManager`
   - 核心状态：`currentSession`、`sessionQuestions`、`currentQuestionIndex`、`remainingSeconds`、`scores`
   - `loadQuestions({category, limit, offset})` → 题库浏览
   - `startInterview({category, questionCount: 4})` → 从题库随机抽题，创建 session
   - `submitAnswer(String answer, int timeSpent)` → 调用 LLM 评分，返回 Stream<String> 实时点评
   - `submitFollowUp(String answer)` → 追问回答评分
   - `finishInterview()` → 生成综合报告，更新 session 状态
   - `loadHistory({limit})` → 历史记录列表
   - `getSessionDetail(sessionId)` → 单次面试详情（含每题评分）
   - 计时器逻辑：每题 thinking 60s + answering 180s，倒计时可见但不强制截断

7. LLM prompt 设计（3 个核心 prompt）：
   - **评分 prompt**：输入题目+用户答案+参考要点 → 输出 JSON 格式评分（content_score/expression_score/time_score/total_score/comment），之后判断是否追问
   - **追问 prompt**：基于用户回答薄弱点生成 1 个追问
   - **综合报告 prompt**：输入全部 4 题评分 → 输出整体分析 + 改进建议

8. LLM 调用统一通过构造函数注入的 `LlmManager.streamChat()`

**UI 层：**

9. 面试入口：在 PracticeScreen 的科目列表 Tab 顶部增加「面试练习」横幅卡片，点击进入面试主页

10. 新增 `lib/screens/interview_home_screen.dart`：
    - 顶部：题型选择卡片（5 种 + 综合随机）
    - 中部：「开始模拟面试」按钮（选择题型后可点击）
    - 底部：历史面试记录列表（最近 10 次，含总分和日期）
    - 题库浏览入口（按题型查看所有面试题）

11. 新增 `lib/screens/interview_session_screen.dart`：
    - 面试进行页，逐题展示
    - 顶部：题号进度（1/4）+ 计时器（思考/作答双阶段）
    - 中部：题目卡片 + 文字作答区（多行 TextField）
    - 提交后：AI 流式点评展示（复用 markdown 渲染）
    - 如有追问：展示追问 + 追问作答区
    - 底部：「下一题」/ 「查看报告」按钮

12. 新增 `lib/screens/interview_report_screen.dart`：
    - 综合得分卡片（渐变背景 + 大号分数）
    - 各维度得分条形图（内容/表达/时间）
    - 逐题回顾列表（展开可看用户答案 + AI 点评 + 追问详情）
    - AI 综合建议（流式展示）

13. 新增 `lib/models/interview_question.dart`：InterviewQuestion 模型
14. 新增 `lib/models/interview_session.dart`：InterviewSession 模型
15. 新增 `lib/models/interview_score.dart`：InterviewScore 模型

16. `InterviewService` Provider 在 `main.dart` 注册（ChangeNotifierProxyProvider 注入 LlmManager）

17. 预置示例面试题 JSON：`assets/questions/interview_sample.json`（5 种题型各 4 题，共 20 题 + 参考答案框架 + 要点）

**范围边界：**
- 做：面试题库（5 种结构化题型）、文字模拟面试（4 题一组 + 计时）、AI 评分点评（3 维度）、AI 追问（最多 1 轮）、综合报告、历史记录、示例数据
- 不做：语音模式、无领导小组讨论、面试技巧知识库、能力雷达图、按岗位分类题库

### 待细化
- 评分 prompt 的具体内容和 JSON 输出格式（方向：多维度评分 rubric + 结构化 JSON）
- 追问生成的触发条件（方向：综合分 < 7 分时追问概率 80%，>= 7 分时 30%）
- 综合报告 prompt 内容（方向：4 题汇总 + 能力短板 + 改进建议）
- 示例面试题的具体内容（方向：经典公考结构化面试真题）

### 验收标准
- [mechanical] interview_questions 表存在：判定 `grep -c "interview_questions" lib/db/database_helper.dart` >= 1
- [mechanical] interview_sessions 表存在：判定 `grep -c "interview_sessions" lib/db/database_helper.dart` >= 1
- [mechanical] interview_scores 表存在：判定 `grep -c "interview_scores" lib/db/database_helper.dart` >= 1
- [mechanical] InterviewService 存在：判定 `ls lib/services/interview_service.dart`
- [mechanical] 面试主页存在：判定 `ls lib/screens/interview_home_screen.dart`
- [mechanical] 面试进行页存在：判定 `ls lib/screens/interview_session_screen.dart`
- [mechanical] 面试报告页存在：判定 `ls lib/screens/interview_report_screen.dart`
- [mechanical] 面试模型存在：判定 `ls lib/models/interview_question.dart lib/models/interview_session.dart lib/models/interview_score.dart`
- [mechanical] Provider 注册：判定 `grep "InterviewService" lib/main.dart`
- [mechanical] DB version 5：判定 `grep "version: 5" lib/db/database_helper.dart`
- [mechanical] 面试入口在 PracticeScreen：判定 `grep -c "interview\|面试" lib/screens/practice_screen.dart` >= 1
- [test] 全量测试通过：`flutter test`
- [mechanical] 零分析错误：`flutter analyze`
- [manual] 运行 `flutter run -d windows` 验证：刷题页顶部出现面试入口，点击进入面试主页，可选题型开始模拟面试，AI 流式评分
