# 考公考编智能助手完整实现 — 开发日志

**日期**: 2026-04-07  
**分支**: feature/full_app  
**最终状态**: flutter analyze 零错误，flutter test 27/27 通过

---

## Phase 1: 基础设施

### 新增依赖（pubspec.yaml）
- `flutter_secure_storage: ^9.2.4` — API Key 加密存储（Windows 用 DPAPI）
- `sqflite_common_ffi: ^2.3.4+4` — Windows 平台 SQLite FFI 支持
- `sqlite3_flutter_libs: ^0.5.29` — SQLite3 本地库

### database_helper.dart 重写
- **版本升级**: v1 → v2，添加完整的 `onUpgrade` 迁移逻辑
- **新增表**: `exams`（id, subject, total_questions, score, time_limit, started_at, finished_at, status）
- **表结构变更**: `user_answers` 新增 `exam_id` 字段（NULL 表示刷题模式）
- **API Key 安全**: `llm_config` 删除 `api_key_encrypted` 字段（重建表迁移）
- **UNIQUE 约束**: `favorites.question_id` 添加唯一约束（重建表迁移）
- **索引**: 7 个索引覆盖所有高频查询路径
- **CRUD 方法**: 每张表完整实现 insert/query/update/delete，共 40+ 个方法
- **批量查询**: `queryMatchResults` 使用 3-表 JOIN 避免 N+1 问题

### main.dart 重写
- 移除 `Provider<DatabaseHelper>`（Screen 层禁止直接访问 DB）
- Windows/Linux 平台自动初始化 sqflite FFI
- 按依赖图顺序注册 6 个 Provider（含 3 个 ChangeNotifierProxyProvider）

---

## Phase 2: 数据模型层

新建目录 `lib/models/`，8 个 Model 文件均使用 `json_serializable`：

| 文件 | 说明 | 特殊处理 |
|------|------|----------|
| `question.dart` | 题目 | `options: List<String>` 存 JSON |
| `exam.dart` | 模拟考试 | `copyWith` 方法，`score: double` |
| `user_answer.dart` | 答题记录 | `is_correct` int/bool 互转 |
| `user_profile.dart` | 用户画像 | `certificates/targetCities` 存 JSON |
| `talent_policy.dart` | 公告 | `attachmentUrls` 存 JSON |
| `position.dart` | 岗位 | JOIN 字段用 `includeToJson: false` |
| `match_result.dart` | 匹配结果 | 三个 List 字段存 JSON，JOIN 字段 |
| `study_plan.dart` | 学习计划 | `baselineScores: Map<String,double>` 存 JSON |
| `daily_task.dart` | 每日任务 | `copyWith` 支持状态更新 |
| `llm_config.dart` | LLM 配置 | `secureStorageKey` 计算属性 |

运行 `dart run build_runner build` 生成 10 个 `.g.dart` 文件。

---

## Phase 3: LLM Provider 层

### 架构
```
LlmProvider (interface)
├── OpenAiCompatibleProvider (abstract base)
│   ├── DeepSeekProvider  (baseUrl: api.deepseek.com/v1)
│   ├── OpenAiProvider    (baseUrl: api.openai.com/v1)
│   └── QwenProvider      (baseUrl: dashscope.aliyuncs.com/compatible-mode/v1)
├── ClaudeProvider        (Anthropic messages API, x-api-key header)
└── OllamaProvider        (localhost:11434, /api/chat, 支持自定义 baseUrl)
```

### 关键设计
- **脱敏拦截器**: `_SanitizedLogInterceptor` 不打印 Authorization header
- **SSE 解析**: 所有 Provider 均实现基于行缓冲的 SSE 流解析
- **Claude 特殊处理**: system 消息独立于 messages 数组，使用 `x-api-key` 而非 `Bearer`
- **Ollama 灵活性**: baseUrl 用户可配置，Android 端显示提示

### LlmManager 重写（ChangeNotifier）
- 预注册全部 5 个 Provider（对象常驻，避免重复创建）
- `streamChat()` 带 fallback 逻辑：主模型 Stream 失败时自动切换备选
- `applyApiKey/applyModelName/applyOllamaBaseUrl` 方法供 LlmConfigService 调用

---

## Phase 4: 服务层

### QuestionService（重写）
- 题目 CRUD：按科目/分类/题型筛选，随机抽题（组卷用）
- 错题管理：`queryWrongQuestionIds` → 加载错题列表
- 收藏管理：toggle 操作，避免重复收藏（UNIQUE 约束保障）
- 示例数据导入：使用 `compute()` isolate 异步解析 JSON，不阻塞 UI
- 统计：今日/累计/按科目正确率

### ExamService（新建，ChangeNotifier）
- 组卷：通过 `QuestionService.randomQuestions()` 随机抽题
- 计时：`Timer.periodic` 倒计时，超时自动提交
- 评分：主观题标记为不计分（需 AI 批改），其余大小写不敏感比对
- `dispose()` 中清理 Timer

### ProfileService（新建，ChangeNotifier）
- 用户画像 CRUD，使用数据库 upsert（首次 insert，后续 update）

### MatchService（新建，ChangeNotifier）
- 公告 CRUD（手动添加）
- AI 解析：将公告原文发送给 LLM 提取结构化岗位信息
- 两级匹配：第一级城市偏好粗筛，第二级逐项计算匹配分（学历25分、专业30分、年龄15分、政治面貌10分、性别10分、工作经验10分）
- 批量 JOIN 查询，避免 N+1

### StudyPlanService（新建，ChangeNotifier）
- AI 生成计划：构建包含薄弱点、可用天数的提示词
- 每日任务自动生成：薄弱科目多分配题量
- 动态调整：调用 AI 分析最近正确率给出建议
- 面试题生成（基础版）

### LlmConfigService（新建）
- `flutter_secure_storage` 存储 API Key，key 格式 `llm_key_{providerName}`
- `loadAndApply()` 启动时加载配置并注入 LlmManager
- Windows 使用 DPAPI（`WindowsOptions(useBackwardCompatibility: false)`）

---

## Phase 5: UI 层

### 通用 Widgets（3 个）
- `ProgressRing`: 自定义圆环进度（`CustomPainter`），支持动态颜色
- `QuestionCard`: 支持单选/多选/判断/主观题，包含答案解析展示
  - 单选：自定义圆形单选标记（避免 Flutter 3.32+ 废弃的 `Radio.groupValue`）
  - 多选：`CheckboxListTile`
  - 判断：`_JudgeButton` 自定义按钮
  - 主观：`StatefulWidget + TextEditingController`（避免 build 中创建 controller）
- `MatchReasonCard`: 三区域（符合/风险/不符）+ 匹配分圆形显示 + 目标标记
- `AiChatDialog`: 底部弹窗，流式响应展示，追问功能

### 屏幕层（11 个 Screen）
- `PracticeScreen`: TabBar（科目练习/错题本）
- `QuestionListScreen`: 题目列表 + 开始练习
- `PracticeSessionScreen`: PageView 顺序答题，确认后显示解析，AI 讲解入口
- `QuestionDetailScreen`: 单题详情，收藏状态管理
- `FavoriteListScreen`: 收藏题目列表
- `ExamScreen`: 三态切换（主页/答题中/报告），配置弹窗支持自定义模考
- `ExamReportScreen`: 分数展示 + AI 分析薄弱点
- `ProfileScreen`: 个人信息摘要卡片 + 功能入口
- `ProfileEditScreen`: 完整画像编辑表单（学历/工作/个人/报考偏好）
- `PolicyMatchScreen`: TabBar（公告管理/匹配结果），AI 解析公告，搜索触发匹配
- `PositionDetailScreen`: 匹配详情 + AI 深度分析入口
- `StatsScreen`: 今日/累计统计 + 各科正确率进度条
- `LlmSettingsScreen`: 5 个 Provider 折叠面板，API Key 显隐切换，连接测试
- `StudyPlanScreen`: 计划总览 + 今日任务 + AI 调整建议
- `DailyTaskScreen`: 任务清单，checkbox 更新状态

### HomeScreen 优化
- 使用 `IndexedStack` 替代数组索引，保持各 Tab 状态不销毁

---

## Phase 6: 示例题库

7 个 JSON 文件，共 65 道题，覆盖所有题型：

| 文件 | 科目 | 分类 | 题数 | 题型 |
|------|------|------|------|------|
| verbal_comprehension.json | 行测 | 言语理解 | 10 | 单选 |
| quantitative_reasoning.json | 行测 | 数量关系 | 10 | 单选 |
| logical_reasoning.json | 行测 | 判断推理 | 10 | 单选+判断 |
| data_analysis.json | 行测 | 资料分析 | 10 | 单选 |
| common_knowledge.json | 行测 | 常识判断 | 10 | 单选+判断 |
| essay_writing.json | 申论 | 申论 | 5 | 主观题 |
| public_basics.json | 公基 | 公共基础知识 | 10 | 单选+判断 |

---

## Phase 7: 测试

3 个测试文件，27 个测试用例，全部通过：

- `widget_test.dart`: App 渲染测试（含 FFI 初始化）
- `models_test.dart`: 12 个模型序列化/反序列化测试
- `service_test.dart`: 15 个服务层逻辑测试

---

## 遇到的问题和处理

### 1. sqflite FFI 测试环境
**问题**: widget_test 报 `databaseFactory not initialized`  
**解决**: 在 `setUpAll()` 中调用 `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`

### 2. Flutter 3.41.6 API 废弃
**问题**: `DropdownButtonFormField.value` 废弃（改用 `initialValue`）；`Radio.groupValue` 废弃  
**解决**: 全部替换为新 API；Radio 改为自定义圆形标记 Widget

### 3. use_build_context_synchronously
**问题**: async 函数中 await 后使用 `context.read`/`ScaffoldMessenger.of(context)` 触发警告  
**解决**: 在 await 前捕获引用（`final messenger = ScaffoldMessenger.of(context)`）

### 4. SQLite 迁移约束
**问题**: SQLite 不支持 `ALTER TABLE DROP COLUMN`，llm_config 需删除 `api_key_encrypted`  
**解决**: 重建表（create_new → copy_data → drop_old → rename_new）

### 5. Stream fallback 设计
**问题**: 主模型 Stream 中途失败时切换 fallback  
**解决**: LlmManager 内部用 StreamController 包装，`await for` 捕获异常后自动切换 fallback Provider 重试

---

## 验收检查

- [x] `ls lib/models/*.dart` — 10 个模型文件
- [x] `ls lib/services/llm/*_provider.dart` — 5 个 LLM Provider
- [x] `ls assets/questions/*.json` — 7 个示例题库文件
- [x] `grep sqflite_common_ffi pubspec.yaml` — 已添加依赖
- [x] `flutter test` — 27 个测试全部通过
- [x] `flutter analyze` — 零错误
