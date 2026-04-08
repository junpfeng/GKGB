# 考公考编智能助手 — 应用架构文档

## 1. 产品概述

**产品名称**：考公考编智能助手
**目标用户**：备考公务员、事业编、选调生、人才引进的考生
**支持平台**：Windows 桌面端 + Android 手机端
**技术栈**：Flutter 3.x (Dart), SQLite, Provider, Material Design 3
**存储方案**：本地 SQLite 优先，离线可用

---

## 2. 功能模块总览

| 模块 | 说明 | 涉及 AI |
|------|------|---------|
| 题库刷题 | 行测/申论/公基分科练习，错题本，收藏，选词填空成语整理 | 追问讲解 |
| 模拟考试 | 按真实考试时间题量模拟，自动评分，成绩趋势 | — |
| 真题练习 | 国考/省考/事业编真题卷，原题序作答 | — |
| 人才引进匹配 | 公告粗筛 → 岗位精准匹配，筛选理由卡片 | 公告解析、模糊条件匹配 |
| 学习路线 | 摸底测试 → AI 生成分阶段每日计划 → 动态调整 | 计划生成与调整 |
| 面试模拟 | 分类别面试练习，AI 实时评分与追问 | 评分、追问、报告生成 |
| 申论训练 | 写作练习 + AI 批改评分 | 批改评分 |
| 错题分析 | 错因分类（知识盲区/易混淆/粗心/超时/陷阱） | 错因归类 |
| 时政热点 | 热点话题 + 申论素材库 | 话题分析 |
| 学习看板 | 今日概览、热力图、雷达图、知识掌握度 | — |
| 考试日历 | 考试时间线、报名截止提醒、准考证管理 | — |
| 自适应刷题 | 基于薄弱知识点的智能出题 | 出题策略 |
| 全局 AI 助手 | 浮动气泡，上下文感知，跨页面对话 | 核心 |
| 成语整理 | 选词填空成语释义 + 人民日报例句 | — |

---

## 3. 技术架构

### 3.1 分层架构

```
┌─────────────────────────────────────────────┐
│  UI 层 (screens/ + widgets/)                │
│  35 个页面 + 21 个通用组件                    │
├─────────────────────────────────────────────┤
│  状态管理层 (Provider)                       │
│  26 个 ChangeNotifier，依赖注入              │
├─────────────────────────────────────────────┤
│  服务层 (services/)                          │
│  37 个服务类，业务逻辑集中                    │
├─────────────────────────────────────────────┤
│  LLM 抽象层 (services/llm/)                 │
│  统一接口 + 6 个模型 Provider + fallback     │
├─────────────────────────────────────────────┤
│  数据层 (db/ + models/)                      │
│  SQLite 42 张表 + 41 个数据模型              │
└─────────────────────────────────────────────┘
```

**依赖方向**：screens → services → db/models（禁止反向）

### 3.2 导航结构

```
App
├── ExamTargetScreen（未设目标时显示）
└── HomeScreen（底部 5 Tab）
    ├── Tab 0: PracticeScreen（刷题总入口）
    │   ├── QuestionListScreen → QuestionDetailScreen
    │   ├── IdiomListScreen（言语理解入口）
    │   ├── RealExamScreen → RealExamPaperScreen / ContributeQuestionScreen
    │   ├── InterviewHomeScreen → InterviewSessionScreen → InterviewReportScreen
    │   ├── AdaptiveQuizScreen → MasteryOverviewScreen
    │   ├── SpeedTrainingScreen（首页/训练中/训练结束 3 视图）
    │   ├── WrongAnalysisScreen → KnowledgeMapScreen
    │   ├── PoliticalTheoryScreen（3 Tab: 文件解读 / 口诀记忆 / 概念对比）
    │   │   └── ExamPointListScreen → ExamPointDetailScreen（口诀生成）
    │   ├── EssayComparisonScreen（试卷选择 → 小题列表 → 答案对比）
    │   ├── VisualExplanationScreen（数量关系可视化解题播放器）
    │   └── FavoriteListScreen
    ├── Tab 1: ExamScreen（模拟考试）→ ExamReportScreen
    ├── Tab 2: PolicyMatchScreen → PositionDetailScreen
    ├── Tab 3: DashboardScreen
    │   ├── KnowledgeMapScreen
    │   ├── MasteryOverviewScreen
    │   └── WrongAnalysisScreen
    └── Tab 4: ProfileScreen
        ├── LLMSettingsScreen
        ├── StudyPlanScreen
        ├── BaselineTestScreen
        ├── ExamCalendarScreen
        ├── InterviewHomeScreen → InterviewSessionScreen → InterviewReportScreen
        ├── HotTopicsScreen
        ├── EssayMaterialScreen → EssayTrainingScreen
        ├── AdaptiveQuizScreen
        └── ContributeQuestionScreen
全局浮动: AiAssistantOverlay（所有页面上方）
```

---

## 4. 页面清单（28 个）

| 文件 | 类名 | 说明 |
|------|------|------|
| `home_screen.dart` | `HomeScreen` | 主页，底部 5 Tab 导航 |
| `practice_screen.dart` | `PracticeScreen` | 刷题：科目练习 / 错题本 / 真题 |
| `exam_screen.dart` | `ExamScreen` | 模拟考试，限时作答 + 评分 |
| `dashboard_screen.dart` | `DashboardScreen` | 学习看板：热力图、雷达图、趋势 |
| `profile_screen.dart` | `ProfileScreen` | 个人信息编辑 |
| `policy_match_screen.dart` | `PolicyMatchScreen` | 人才引进公告列表 |
| `policy_match_detail_screen.dart` | 岗位匹配详情 | 筛选理由卡片 |
| `exam_target_screen.dart` | `ExamTargetScreen` | 备考目标选择 |
| `baseline_test_screen.dart` | `BaselineTestScreen` | 摸底测试 |
| `study_plan_screen.dart` | `StudyPlanScreen` | AI 学习计划 |
| `real_exam_screen.dart` | `RealExamScreen` | 真题卷浏览 |
| `real_exam_paper_screen.dart` | `RealExamPaperScreen` | 真题卷作答 |
| `interview_home_screen.dart` | `InterviewHomeScreen` | 面试练习首页 |
| `interview_session_screen.dart` | `InterviewSessionScreen` | 面试作答 + AI 评分 |
| `interview_report_screen.dart` | `InterviewReportScreen` | 面试报告 |
| `wrong_analysis_screen.dart` | `WrongAnalysisScreen` | 错题分析 |
| `knowledge_map_screen.dart` | `KnowledgeMapScreen` | 知识点掌握度地图 |
| `mastery_overview_screen.dart` | `MasteryOverviewScreen` | 科目掌握度总览 |
| `hot_topics_screen.dart` | `HotTopicsScreen` | 时政热点 |
| `essay_material_screen.dart` | `EssayMaterialScreen` | 申论素材库 |
| `essay_training_screen.dart` | `EssayTrainingScreen` | 申论写作练习 |
| `exam_calendar_screen.dart` | `ExamCalendarScreen` | 考试日历 |
| `exam_calendar_detail_screen.dart` | `ExamCalendarDetailScreen` | 考试详情 |
| `exam_calendar_edit_screen.dart` | `ExamCalendarEditScreen` | 添加/编辑考试 |
| `idiom_list_screen.dart` | `IdiomListScreen` | 成语整理 |
| `llm_settings_screen.dart` | `LLMSettingsScreen` | LLM 模型配置 |
| `contribute_question_screen.dart` | `ContributeQuestionScreen` | 用户贡献题目 |
| `adaptive_quiz_screen.dart` | `AdaptiveQuizScreen` | 自适应刷题 |
| `exam_entry_scores_screen.dart` | `ExamEntryScoresScreen` | 进面分数线查询 |
| `spatial_viz_screen.dart` | `SpatialVizScreen` | 空间可视化全屏播放器 |
| `political_theory_screen.dart` | `PoliticalTheoryScreen` | 政治理论专项（3 Tab: 文件解读/口诀记忆/概念对比） |
| `visual_explanation_screen.dart` | `VisualExplanationScreen` | 数量关系可视化解题播放器（方程推导动画） |
| `essay_comparison_screen.dart` | `EssayComparisonScreen` | 申论小题多名师答案对比（三级导航：试卷→小题→答案对比） |
| `speed_training_screen.dart` | `SpeedTrainingScreen` | 资料分析速算训练（首页/训练中/训练结束 3 视图） |

---

## 5. 服务层清单（37 个）

### 5.1 核心业务服务

| 服务 | 关键方法 | 说明 |
|------|---------|------|
| `QuestionService` | `loadQuestions()`, `randomQuestions()`, `recordAnswer()` | 题库管理与检索 |
| `ExamService` | `startExam()`, `submitAnswer()`, `finishExam()` | 模拟考试编排与评分 |
| `ProfileService` | `loadProfile()`, `saveProfile()` | 用户画像管理 |
| `BaselineService` | `startBaseline()`, `submitBaseline()` | 摸底诊断测试 |
| `RealExamService` | `loadPapers()`, `contributeQuestion()` | 真题卷管理 |
| `MatchService` | `matchPositions()`, `addPolicy()` | 两级岗位匹配 |
| `StudyPlanService` | `generatePlan()`, `getDailyTasks()`, `adjustPlan()` | AI 学习计划 |
| `InterviewService` | `startSession()`, `scoreAnswer()`, `getReport()` | 面试模拟 |
| `ExamCategoryService` | `loadTargets()`, `setTarget()` | 备考目标管理 |

### 5.2 内容与分析服务

| 服务 | 说明 |
|------|------|
| `EssayService` | 申论写作 + AI 批改 |
| `HotTopicService` | 时政热点 + 素材库 |
| `IdiomService` | 成语预置导入 + 题目关联 |
| `WrongAnalysisService` | AI 错因分析 |
| `DashboardService` | 学习数据聚合 |
| `AdaptiveQuizService` | 薄弱点自适应出题 |
| `CalendarService` | 考试日历与提醒 |
| `ExamEntryScoreService` | 进面分数线（asset 预置导入 + 查询/排行/趋势） |
| `MasterQuestionService` | 母题类型 CRUD + 题目标签关联 + 按类型查题 |
| `SpatialVizService` | 空间可视化数据查询 + 预置 JSON 导入 |
| `PoliticalTheoryService` | 政治理论文件解读 + AI 口诀生成（流式） + 概念对比 + 预置数据导入 |
| `VisualExplanationService` | 数量关系可视化解题（AI 生成 + DB 缓存 + 预置数据导入） |
| `EssayComparisonService` | 申论小题多名师答案对比 + AI 流式分析得分要点 + 预置数据导入 |
| `SpeedTrainingService` | 速算训练（算法生成练习题 + 训练管理 + 历史统计 + 预置数据导入） |

### 5.3 基础设施服务

| 服务 | 说明 |
|------|------|
| `LlmManager` | 多模型管理 + fallback |
| `LlmConfigService` | LLM 配置加载/存储 |
| `AssistantService` | 全局 AI 助手 |
| `NotificationService` | 本地推送通知 |
| `VoiceService` | 语音识别 + 语音合成 |

### 5.4 LLM 提供者（6 个）

| Provider | 模型 | 接口 |
|----------|------|------|
| `ClaudeProvider` | Anthropic Claude | Anthropic API |
| `DeepSeekProvider` | DeepSeek | OpenAI 兼容 |
| `QwenProvider` | 阿里通义千问 | DashScope |
| `OpenAiProvider` | OpenAI GPT | OpenAI API |
| `OllamaProvider` | 本地 Ollama | REST API |
| `ZhipuProvider` | 智谱 | 专用 API |

---

## 6. 数据模型清单（39 个）

### 6.1 题目与作答

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `Question` | subject, category, type, content, options, answer, difficulty, isRealExam, region, year | 题目（支持多考试来源） |
| `UserAnswer` | questionId, userAnswer, isCorrect, timeSpent, errorType, isBaseline | 答题记录 |
| `Exam` | subject, totalQuestions, score, timeLimit, status | 模拟考试记录 |
| `RealExamPaper` | name, region, year, examType, subject, questionIds | 真题卷 |

### 6.2 用户与目标

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `UserProfile` | education, major, university, workYears, politicalStatus, certificates, targetCities | 用户画像 |
| `UserExamTarget` | examCategoryId, subTypeId, province, targetExamDate | 备考目标 |
| `ExamCategory` | id, label, scope, defaultSubjects, supportedFeatures | 考试类型定义 |

### 6.3 匹配系统

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `TalentPolicy` | title, province, policyType, publishDate, deadline | 招聘公告 |
| `Position` | positionName, department, educationReq, majorReq, ageReq | 岗位信息 |
| `MatchResult` | matchScore, matchedItems, riskItems, unmatchedItems | 匹配结果 |

### 6.4 学习系统

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `StudyPlan` | examDate, subjects, baselineScores, planData | 学习计划 |
| `DailyTask` | taskDate, subject, topic, targetCount, completedCount | 每日任务 |
| `KnowledgePoint` | name, subject, category, parentId | 知识点树 |
| `MasteryScore` | score, totalAttempts, correctAttempts, nextReviewAt | 掌握度（间隔重复） |

### 6.5 面试系统

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `InterviewQuestion` | category, content, referenceAnswer, keyPoints | 面试题 |
| `InterviewSession` | category, totalScore, status, summary | 面试会话 |
| `InterviewScore` | contentScore, expressionScore, aiComment, followUpQuestion | 面试评分 |

### 6.6 内容系统

| 模型 | 核心字段 | 说明 |
|------|---------|------|
| `HotTopic` | title, summary, examPoints, essayAngles | 时政热点 |
| `EssayMaterial` | theme, materialType, content | 申论素材 |
| `EssaySubmission` | topic, content, aiScore, aiComment | 申论提交 |
| `Idiom` | text, definition | 成语 |
| `IdiomExample` | sentence, year, sourceUrl | 成语例句 |
| `VisualExplanation` | questionId, explanationType, stepsJson, templateId | 可视化解题步骤 |

---

## 7. 通用组件（21 个）

| 组件 | 说明 |
|------|------|
| `GlassCard` | 毛玻璃卡片（轻量版，列表场景优化） |
| `GradientButton` | 渐变按钮（主色/辅色/三级） |
| `ProgressRing` | 环形进度指示器 |
| `QuestionCard` | 题目卡片（单选/多选/判断/主观 + 成语释义） |
| `MatchReasonCard` | 匹配理由卡片（符合/风险/不符） |
| `ExamTypeBadge` | 考试类型标签 |
| `HeatmapWidget` | 学习频率热力图 |
| `RadarChartWidget` | 科目得分雷达图 |
| `SubjectCategoryUI` | 科目分类选择器 |
| `VoiceInputWidget` | 语音输入组件 |
| `AiChatDialog` | 单次 AI 对话弹窗 |
| `AiAssistantOverlay` | 全局 AI 助手浮层 |
| `AssistantBubble` | 可拖动浮动气泡 |
| `AssistantDialog` | AI 对话面板 |
| `AssistantInputBar` | 文本 + 语音输入栏 |
| `AssistantMessage` | 消息气泡（支持 ACTION 按钮） |
| `AssistantTools` | 工具注册 + 消息模型 + ACTION 解析 |
| `SpatialPlayerWidget` | 空间可视化播放控制器（步骤导航+解题思路） |
| `VisualPlayerWidget` | 可视化解题播放控制器（步骤导航+速度调节） |
| `EquationPainter` | 方程推导 CustomPainter（逐步绘制+高亮+动画） |

---

## 8. 数据库设计（SQLite, 39 张表）

当前版本：**v16**

### 核心表

```
questions         — 题目库（8000+ 题，含真题标记）
user_answers      — 答题记录（含错因分类、是否摸底）
favorites         — 收藏题目
real_exam_papers  — 真题卷模板
exams             — 模拟考试记录
```

### 用户表

```
user_profile       — 用户画像
user_exam_targets  — 备考目标
user_registrations — 准考证信息
```

### 匹配表

```
talent_policies  — 招聘公告
positions        — 岗位信息
match_results    — 匹配结果
```

### 学习表

```
study_plans      — 学习计划
daily_tasks      — 每日任务
knowledge_points — 知识点树
mastery_scores   — 掌握度（间隔重复）
```

### 面试表

```
interview_questions — 面试题库
interview_sessions  — 面试会话
interview_scores    — 面试评分
```

### 内容表

```
hot_topics         — 时政热点
essay_materials    — 申论素材
essay_submissions  — 申论提交
idioms             — 成语
idiom_examples     — 成语例句
idiom_question_links — 成语-题目关联
```

### 可视化解题表

```
visual_explanations   — 可视化解题步骤（UNIQUE(question_id)，AI 生成 + 预置导入）
```

### 配置表

```
llm_config     — LLM 模型配置
exam_calendar  — 考试日历
```

---

## 9. 多模型 AI 架构

### 9.1 统一接口

```dart
abstract class LlmProvider {
  Future<String> chat(List<ChatMessage> messages);
  Stream<String> streamChat(List<ChatMessage> messages);
}
```

### 9.2 调用链路

```
业务层（任意 Service）
  ↓ 调用 LlmManager.chat() / streamChat()
LlmManager
  ↓ 选择 primary provider
  ↓ 失败 → 自动 fallback 到备选 provider
具体 Provider（Claude / DeepSeek / Qwen / ...）
  ↓ HTTP 请求
模型 API
```

### 9.3 AI 应用场景

| 场景 | 调用方式 | 服务 |
|------|---------|------|
| 题目追问讲解 | chat | QuestionCard → AiChatDialog |
| 学习计划生成 | chat | StudyPlanService |
| 面试评分 + 追问 | streamChat | InterviewService |
| 申论批改 | chat | EssayService |
| 错因分析 | chat | WrongAnalysisService |
| 公告解析 | chat | MatchService |
| 全局助手对话 | streamChat | AssistantService |
| 自适应出题 | chat | AdaptiveQuizService |
| 口诀生成 | streamChat | PoliticalTheoryService |
| 概念对比 | streamChat | PoliticalTheoryService |
| 可视化解题步骤生成 | streamChat | VisualExplanationService |
| 名师答案分析 | streamChat | EssayComparisonService |

### 9.4 API Key 安全

- 用户在设置页输入 API Key
- 通过 `flutter_secure_storage` 加密存储
- 禁止 SQLite 明文存储或日志输出

---

## 10. 资产文件

### 10.1 题库数据

```
assets/questions/
├── verbal_comprehension.json    — 言语理解
├── quantitative_reasoning.json  — 数量关系
├── logical_reasoning.json       — 判断推理
├── data_analysis.json           — 资料分析
├── common_knowledge.json        — 常识判断
├── essay_writing.json           — 申论
├── public_basics.json           — 公基
├── interview_sample.json        — 面试题
└── real_exam/                   — 真题卷
    ├── index.json
    ├── guokao/                  — 国考（2020-2025）
    ├── shengkao/                — 省考（上海/山东/江苏/浙江）
    └── shiyebian/               — 事业编
```

### 10.2 预置数据

```
assets/data/
├── exam_calendar_sample.json    — 考试日历种子数据
├── hot_topics_sample.json       — 时政热点种子数据
├── essay_materials_sample.json  — 申论素材种子数据
└── idioms_preset.json           — 成语释义 + 人民日报例句
```

---

## 11. 开发工具

### 11.1 真题采集工具链 (`tools/scraper/`)

Python 实现的完整数据管线：采集 → 标准化 → 去重 → 输出 JSON。

```bash
# 安装依赖
pip install -r tools/scraper/requirements.txt

# 运行全部爬虫
python tools/scraper/main.py

# 仅粉笔网（需 cookie）
python tools/scraper/main.py --source fenbi --fenbi-cookie "SESSION=..."

# 仅政府官网（指定省份）
python tools/scraper/main.py --source gov --province jiangsu

# 仅标准化已有数据
python tools/scraper/main.py --normalize-only --input raw.json
```

**数据流**：

```
数据源（4个） → BaseScraper（限速/robots.txt/重试）
                  ↓
              原始数据
                  ↓
          Normalizer（字段标准化）
                  ↓
          Dedup（MD5 去重）
                  ↓
          分组输出 → assets/questions/real_exam/{guokao,shengkao,shiyebian}/
```

#### 数据源爬虫（4 个）

| 爬虫 | 文件 | 数据源 | 状态 | 说明 |
|------|------|--------|------|------|
| 粉笔网 | `fenbi_scraper.py` | `tiku.fenbi.com` | **主力源** | API 接口采集，含完整题目+解析。需登录 cookie。支持国考/省考/事业编 |
| QZZN 论坛 | `qzzn_scraper.py` | `bbs.qzzn.com` | 框架完成 | 论坛帖子正则解析，社区维护的真题回忆版 |
| 政府官网 | `gov_scraper.py` | 各省人事考试网 | 框架完成 | 支持江苏/浙江/上海/山东。部分页面为 PDF/Word 需额外解析 |
| 小红书 | `xiaohongshu_scraper.py` | `xiaohongshu.com` | **默认禁用** | 图片型回忆版，需登录+签名验证+OCR 服务 |

#### 粉笔网爬虫详解（主力数据源）

**API 调用链**：
1. `GET /subLabels` → 获取省份/地区列表
2. `GET /papers/?labelId=X` → 获取试卷列表
3. `POST /exercises` → 创建练习（获取题目 ID）
4. `GET /exercises/{id}` → 获取练习详情（题目 ID 列表 + 章节映射）
5. `GET /solutions?ids=X,Y,Z` → 批量获取完整题目数据

**数据解析**：
- HTML 标签清理（题目内容/选项/解析）
- 章节 → 科目分类映射（如"数字推理"→"数量关系"）
- 试卷名 → 考试信息解析（国考/副省级/地市级等）
- 材料题/资料分析题的上下文提取
- 多选题自动检测（答案长度 > 1）

**目标范围**：国考、江苏、浙江、上海、山东，2020-2025 年

#### 基础设施组件

| 组件 | 文件 | 说明 |
|------|------|------|
| 基类 | `base_scraper.py` | 限速（≥2s + 随机抖动）、robots.txt 检查、自动重试（指数退避，3 次）、会话管理 |
| 配置 | `config.py` | 各数据源 URL、目标年份（2020-2026）、请求参数、输出目录 |
| 标准化 | `normalizer.py` | 字段映射（科目/分类/题型/难度/地区/年份）、HTML 清理、选项格式统一、校验 |
| 去重 | `dedup.py` | 基于内容 MD5 哈希去重，标点/空白归一化后比较。有解析的版本优先保留 |
| 入口 | `main.py` | 命令行参数、流程编排、按（考试类型+地区+年份+科目）分组输出 JSON |

#### 输出格式

```json
{
  "paper": {
    "name": "2024年国考行测真题（副省级）",
    "region": "全国", "year": 2024, "exam_type": "国考",
    "subject": "行测", "time_limit": 7200, "total_score": 100
  },
  "questions": [
    {
      "subject": "行测", "category": "言语理解", "type": "single",
      "content": "题目内容...", "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "answer": "C", "explanation": "解析...", "difficulty": 3,
      "region": "全国", "year": 2024, "exam_type": "国考",
      "exam_session": "", "is_real_exam": 1
    }
  ],
  "generated_at": "2024-01-01T00:00:00", "source": "scraped", "total": 135
}
```

#### 合规性

- 所有请求携带 `User-Agent: ExamPrepBot/1.0 (+educational use)`
- 每次请求前检查 robots.txt
- 请求间隔 ≥2s（含随机抖动 0-3s）
- 超时 30s，最多重试 3 次（指数退避）
- 数据仅用于本地学习分析，禁止二次分发

### 11.2 进面分数线采集工具 (`tools/exam_score_scraper/`)

Python 实现，采集国考/省考/事业编进面分数线数据。

```bash
pip install -r tools/exam_score_scraper/requirements.txt
python tools/exam_score_scraper/export_json.py
```

**数据流**：

```
数据源（华图API/上岸鸭/qihejy/官方网站）
  → ScraperBase（限速≥2s/robots.txt/UA）
  → HuatuApiScraper（双轨：fs_list真实分数 / get_distinct代理分数）
  → GuokaoScraper / ShengkaoScraper / ShiyebianScraper
  → HuatuEchartsScraper（省级汇总）
  → DataCleaner（标准化/去重/校验）
  → export_json.py → assets/data/exam_entry_scores/{file}.json + index.json
```

| 爬虫 | 文件 | 数据源 | 数据量 |
|------|------|--------|--------|
| 华图 API | `huatu_api_scraper.py` | apis.huatu.com（fs_list + get_distinct） | ~34,000（江苏）+ ~12,000（浙沪鲁） |
| 国考 | `guokao_scraper.py` | eoffcn.com + gwy.com + 内置历史 | ~57 |
| 省考 | `shengkao_scraper.py` | qihejy.com Excel（江苏） | ~2,152 |
| 华图汇总 | `huatu_echarts_scraper.py` | 华图 skfscx 静态页面 | ~4（省级汇总） |
| 事业编 | `shiyebian_scraper.py` | （暂无可用来源） | 0 |

### 11.3 成语采集脚本 (`tools/collect_idioms.dart`)

Dart 实现，开发阶段使用。

```bash
dart run tools/collect_idioms.dart
```

**流程**：
1. 扫描 `assets/questions/` 下所有题库 JSON
2. 识别选词填空题（言语理解 + 内容含 `___`）
3. 从选项中提取四字成语（正则 `[\u4e00-\u9fff]{4}`）
4. 增量更新：已有数据跳过
5. 爬取百度汉语释义 + 人民日报搜索例句（2020-2025）
6. 输出到 `assets/data/idioms_preset.json`

**限制**：百度汉语已改为 SPA 架构，人民日报搜索需国内网络。当前预置数据通过 WebSearch 补充。

---

## 12. Provider 注册顺序

```dart
// main.dart 中 MultiProvider 注册链
 0. ExamCategoryService     — 启动时加载备考目标
 1. CalendarService          — 启动时加载日历数据
 2. QuestionService          — 无依赖
 3. ProfileService           — 无依赖
 4. LlmManager              — 启动时加载配置
 5. ExamService              — 依赖 QuestionService
 6. MatchService             — 依赖 ProfileService + LlmManager
 7. StudyPlanService         — 依赖 QuestionService + LlmManager + ExamCategoryService
 8. BaselineService          — 依赖 QuestionService
 9. RealExamService          — 依赖 QuestionService + LlmManager
10. InterviewService         — 依赖 LlmManager + ExamCategoryService
11. WrongAnalysisService     — 依赖 LlmManager
12. HotTopicService          — 启动时导入预置数据
13. EssayService             — 依赖 LlmManager
14. VoiceService             — 无依赖
15. DashboardService         — 依赖 QuestionService + ExamService + LlmManager
16. AdaptiveQuizService      — 依赖 LlmManager
17. AssistantService         — 依赖全部核心 Service
18. IdiomService             — 启动时导入预置数据
```

---

## 13. 主题设计

| 渐变 | 色值 | 用途 |
|------|------|------|
| 主色 | #667eea → #764ba2 | 按钮、强调、品牌色 |
| 信息 | #0ED2F7 → #09A6C3 | 统计、信息提示 |
| 暖色 | #f093fb → #f5576c | 警告、错题标记 |
| 成功 | #11998e → #38ef7d | 正确、完成 |

组件风格：毛玻璃卡片（GlassCard）、圆角 8-20px、渐变按钮
