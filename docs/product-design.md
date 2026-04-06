# 考公考编智能助手 — 产品设计文档

## 1. 产品概述

**产品名称**：考公考编智能助手（暂定）
**目标用户**：备考公务员、事业编、选调生、人才引进的考生
**支持平台**：Windows 桌面端 + Android 手机端
**技术框架**：Flutter（Dart），单代码库跨平台
**存储方案**：混合模式（本地 SQLite + 云端同步），离线可用，联网刷新

---

## 2. 核心功能模块

### 2.1 题库刷题系统
- 按科目分类：行测（言语/数量/判断/资料/常识）、申论、公基、专业课
- 按题型分类：单选、多选、判断、主观题
- 刷题模式：顺序练习、随机练习、专项练习、错题重做
- 错题本：自动收录错题，支持标注笔记和收藏
- 题目解析：每题附详细解析，支持 AI 追问讲解

### 2.2 模拟考试
- 按真实考试时间和题量模拟（如行测 120 分钟 130 题）
- 自动评分 + 各模块得分分析
- 历史成绩趋势图
- 支持自定义组卷（指定科目/题型/数量）

### 2.3 人才引进智能匹配

#### 2.3.1 用户画像
用户填写个人信息，作为匹配基础：
- 学历/学位（本科/硕士/博士）
- 专业（教育部专业目录编码，精确到二级学科）
- 毕业院校（是否 985/211/双一流）
- 工作年限、基层工作经历
- 政治面貌（群众/团员/党员）
- 资格证书（法律职业资格、CPA、教师资格等）
- 年龄、性别、户籍所在地
- 目标城市偏好（可多选）

#### 2.3.2 公告抓取
数据源（初期）：
- 各省市人社局官网
- 高校人才招聘网（硕博引进）
- 事业单位招聘公告网
- 选调生公告

定时更新机制：
- Android：WorkManager 后台定时任务（每日 8:00）
- Windows：系统托盘常驻 + 定时轮询
- 有新匹配时本地通知推送

#### 2.3.3 两级匹配机制

**第一级：公告粗筛**
- 学历/学位门槛过滤
- 专业大类初筛
- 年龄/工作年限筛选
- 城市偏好排序
- 过滤明显不相关的公告

**第二级：岗位精准匹配**
- 解析公告中的岗位表（Excel/PDF 附件中的职位表）
- 逐岗位匹配条件：
  - 专业目录编码（精确到二级学科）
  - 学历/学位要求
  - 政治面貌要求
  - 基层工作经历要求
  - 资格证书要求
  - 性别限制
  - 户籍限制
  - 年龄限制
  - 应届生要求

#### 2.3.4 筛选理由卡片
每个匹配岗位生成详细筛选理由：
- **符合项**：逐条列出（学历达标、专业对口、年龄符合…）
- **风险项**：如竞争比预估较高、刚好满足最低年限要求等
- **不符项**：如有，说明为何仍推荐（如"限应届生，毕业未满2年可能按政策视同应届"）
- **综合匹配度评分**：0-100 分，附评分依据
- **报考建议**：竞争激烈程度预估、建议作为保底/冲刺岗位

#### 2.3.5 AI 辅助判断
- 公告中"相关专业"等模糊表述 → LLM 结合上下文判断是否符合
- 政策性条件（如"视同应届"规则）→ AI 解读并标注置信度

### 2.4 岗位定制学习路线

#### 2.4.1 核心流程
1. 用户从匹配岗位中选定目标岗位（"我要报这个"）
2. 系统提取考试信息：笔试科目、面试形式、考试日期
3. 用户完成摸底测试 → 得出各科目基线分数
4. 系统根据"可用天数 + 薄弱点"生成分阶段学习计划

#### 2.4.2 学习计划结构
- **阶段划分**：基础夯实期 → 专项突破期 → 刷题强化期 → 冲刺模考期
- **每日任务**：具体到"今天学什么科目、哪个知识点、做哪套题、预计用时"
- **动态调整**：每周根据刷题正确率自动调整后续计划（薄弱项加量，强项减量）
- **里程碑提醒**：距考试 30/15/7/3 天关键节点提醒 + 阶段测评

#### 2.4.3 AI 增强
- 根据错题分布生成针对性复习建议
- 薄弱知识点自动关联题库中的相关练习题
- 面试岗可生成面试题库 + 答题框架建议

### 2.5 多大模型接入

#### 2.5.1 支持的模型
| 模型 | API 格式 | 说明 |
|------|---------|------|
| Claude | Anthropic API | Anthropic 官方 |
| DeepSeek | OpenAI 兼容 | 国产大模型，性价比高 |
| 通义千问 | DashScope API | 阿里云，国内访问稳定 |
| OpenAI GPT | OpenAI API | 可选 |
| Ollama 本地模型 | REST API | 离线场景备用 |

#### 2.5.2 架构设计
- 统一抽象接口 `LlmProvider`：`chat()` + `streamChat()`
- DeepSeek/OpenAI 共用 OpenAI 兼容格式，只换 baseUrl 和 key
- 用户在设置页选择默认模型、填入自己的 API Key（加密存储）
- 支持 fallback：主模型调用失败自动降级到备选模型
- 所有 AI 场景统一通过 `LlmManager.chat()` 调用，不耦合具体模型

#### 2.5.3 AI 应用场景
| 场景 | 说明 |
|------|------|
| 公告智能解析 | 非结构化公告文本 → 结构化岗位条件 |
| 模糊条件判断 | "相关专业"等模糊表述的匹配判断 |
| 题目讲解答疑 | 对不理解的题目进行深入讲解 |
| 学习建议生成 | 根据错题分布生成复习建议 |
| 面试模拟 | 生成面试题 + 答题框架 |
| 申论批改 | 对主观题作答进行点评 |

---

## 3. 技术架构

### 3.1 技术栈
- **框架**：Flutter 3.x（Dart）
- **本地数据库**：SQLite（sqflite）
- **网络请求**：Dio
- **状态管理**：Provider
- **序列化**：json_serializable
- **网络检测**：connectivity_plus
- **后台任务**：WorkManager（Android）

### 3.2 项目目录结构
```
independent_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   ├── question.dart           # 题目
│   │   ├── exam.dart               # 试卷
│   │   ├── user_progress.dart      # 用户进度
│   │   ├── user_profile.dart       # 用户画像
│   │   ├── talent_policy.dart      # 人才引进政策
│   │   ├── position.dart           # 岗位
│   │   ├── match_result.dart       # 匹配结果
│   │   ├── study_plan.dart         # 学习计划
│   │   ├── daily_task.dart         # 每日任务
│   │   └── target_position.dart    # 目标岗位
│   ├── db/
│   │   ├── database_helper.dart    # SQLite 管理
│   │   └── sync_service.dart       # 云端同步
│   ├── services/
│   │   ├── api_service.dart        # 云端 API
│   │   ├── question_service.dart   # 题目服务
│   │   ├── crawler_service.dart    # 公告抓取
│   │   ├── match_service.dart      # 公告匹配
│   │   ├── match_engine.dart       # 岗位匹配引擎
│   │   ├── position_parser.dart    # 岗位表解析
│   │   ├── plan_generator.dart     # 学习计划生成
│   │   └── llm/
│   │       ├── llm_provider.dart       # LLM 抽象接口
│   │       ├── claude_provider.dart
│   │       ├── deepseek_provider.dart
│   │       ├── qwen_provider.dart
│   │       ├── openai_provider.dart
│   │       ├── ollama_provider.dart
│   │       └── llm_manager.dart        # 模型管理
│   ├── screens/
│   │   ├── home_screen.dart            # 首页
│   │   ├── practice_screen.dart        # 刷题
│   │   ├── exam_screen.dart            # 模拟考试
│   │   ├── stats_screen.dart           # 统计
│   │   ├── profile_screen.dart         # 个人信息
│   │   ├── policy_match_screen.dart    # 公告匹配列表
│   │   ├── position_detail_screen.dart # 岗位匹配详情
│   │   ├── target_select_screen.dart   # 目标岗位确认
│   │   ├── baseline_test_screen.dart   # 摸底测试
│   │   ├── study_plan_screen.dart      # 学习计划总览
│   │   ├── daily_task_screen.dart      # 今日任务
│   │   └── llm_settings_screen.dart    # 模型设置
│   └── widgets/
│       ├── question_card.dart          # 题目卡片
│       ├── match_reason_card.dart      # 筛选理由卡片
│       ├── plan_calendar.dart          # 日历组件
│       └── progress_ring.dart          # 进度环
├── assets/
├── android/
├── windows/
└── pubspec.yaml
```

### 3.3 数据库表设计（SQLite）
- `questions` — 题库
- `user_answers` — 答题记录
- `favorites` — 收藏
- `user_profile` — 用户画像
- `talent_policies` — 人才引进公告
- `positions` — 岗位
- `match_results` — 匹配结果
- `study_plans` — 学习计划
- `daily_tasks` — 每日任务
- `llm_config` — 模型配置

---

## 4. 云端可选扩展
- 后端定时爬虫集中抓取公告，客户端拉取结果（减少客户端抓取压力）
- 后端代理 LLM 调用（用户无需自备 Key，走订阅制）
- 多设备数据同步
- 题库在线更新

---

## 5. 环境搭建清单

### 当前状态
- ✅ Windows 10 Pro, Git 2.43, VS Community 2026, winget
- ❌ Flutter SDK、Dart SDK、Java JDK、Android SDK

### 安装步骤
1. `winget install Google.Flutter`
2. `winget install Microsoft.OpenJDK.17`
3. `winget install Google.AndroidStudio`（Android SDK）
4. 配置环境变量
5. `flutter doctor` 确认就绪
6. `flutter config --enable-windows-desktop`
7. `flutter create --org com.examprep --project-name exam_prep_app .`

### 验证标准
1. `flutter doctor` 全部通过
2. `flutter run -d windows` 能启动桌面窗口
3. `flutter build apk` 能生成 APK
4. 首页底部导航可切换
5. 个人信息可保存到 SQLite
6. 选定目标岗位后能生成学习计划
