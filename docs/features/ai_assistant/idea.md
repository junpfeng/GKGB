# AI 智能助手浮窗

## 核心需求
在 app 内集成全局 AI 助手对话弹窗，可最小化为悬浮球、放大为完整对话面板，支持文字和语音交互，能统筹调度 app 内所有功能（刷题、模考、岗位匹配、学习计划、统计等）为用户服务。

## 调研上下文

### 现有实现参考
- **AiChatDialog** (`lib/widgets/ai_chat_dialog.dart`)：底部弹窗，`DraggableScrollableSheet`，毛玻璃风格，已集成 `LlmManager.streamChat()` 流式调用。用于单次上下文 Q&A（题目讲解等），被 practice_screen、exam_screen、study_plan_screen、policy_match_screen 调用。
- **HomeScreen** (`lib/screens/home_screen.dart`)：5-tab 底部导航（刷题/模考/岗位/统计/我的），IndexedStack 切换。
- **Provider 注册模式** (`lib/main.dart`)：三级依赖注入，`ChangeNotifierProvider` + `ChangeNotifierProxyProvider`/`ProxyProvider2`。
- **LlmManager** (`lib/services/llm/llm_manager.dart`)：`chat()` 和 `streamChat()` 两个接口，支持 fallback。

### 已有 Services
QuestionService, ExamService, ProfileService, MatchService, StudyPlanService, BaselineService, LlmManager, LlmConfigService

### 当前依赖（pubspec.yaml）
provider, dio, sqflite, flutter_secure_storage, fl_chart, json_annotation 等。**未包含** speech_to_text、flutter_tts。

### 设计文档
详见 `docs/ai-assistant-design.md`，包含完整的架构设计、类设计、UI 设计和实现分阶段计划。

## 范围边界
- 做：三态 Overlay（hidden/minimized/expanded）、悬浮球拖拽、对话面板、功能编排（ACTION 标记）、语音交互（STT/TTS）、动态 system prompt、上下文感知
- 不做：消息持久化（仅内存）、修改现有 AiChatDialog、云端对话同步

## 初步理解
这是一个全新的全局模块，涉及三层（widgets + services + app.dart 注入）。核心挑战：
1. Overlay 系统需要在 MaterialApp.builder 中注入，始终覆盖所有页面
2. 功能编排需要 AssistantService 依赖 7 个已有 service
3. 语音交互需要新增两个第三方包和平台权限配置

## 待确认事项
见 Step 3 互动确认。

## 确认方案

方案摘要：AI 智能助手浮窗

核心思路：全局 Overlay 三态助手（hidden/minimized/expanded），通过 ACTION 文本标记编排 app 功能，集成 STT/TTS 语音交互。

### 锁定决策

数据层：
  - 数据模型：`AssistantMessage`（id, role, content, displayText, actions, timestamp）、`ToolCommand`（name, params）— 纯内存模型，不持久化
  - 数据库变更：无
  - 序列化：无需 json_serializable（不持久化）

服务层：
  - 新增服务：`AssistantService`（ChangeNotifier，状态管理+消息历史+system prompt+工具分发）、`VoiceService`（ChangeNotifier，STT/TTS 封装）
  - LLM 调用：通过 `LlmManager.streamChat()` 流式调用，不直接依赖具体 Provider
  - 外部依赖：`speech_to_text: ^7.0.0`、`flutter_tts: ^4.2.0`
  - Provider 注册：`ChangeNotifierProvider(create: (ctx) => AssistantService(ctx.read<...>()))`，在所有现有 provider 之后注册；`VoiceService` 无依赖，独立注册

UI 层：
  - 新增组件（`lib/widgets/ai_assistant/` 目录）：
    - `ai_assistant_overlay.dart` — 顶层 Overlay，动画控制器，渲染悬浮球或对话面板
    - `assistant_bubble.dart` — 可拖拽悬浮球（56x56 渐变圆形）
    - `assistant_dialog.dart` — 对话面板（毛玻璃风格，85% 屏幕高度）
    - `assistant_input_bar.dart` — 输入栏（文字+麦克风+发送）
    - `assistant_message.dart` — 消息气泡（支持 ACTION 按钮+TTS 播放）
    - `assistant_tools.dart` — 数据模型、工具定义、解析器、工具注册表
  - 状态管理：AssistantService 作为 ChangeNotifier，UI 通过 context.watch/read 访问
  - 注入方式：`MaterialApp.builder` 中包裹 `AiAssistantOverlay`

主要技术决策：
  - Provider 注册用 ctx.read 一次性注入（非 ProxyProvider），原因：AssistantService 不需要随依赖变化重建
  - Phase 1-4 一次性实现（含语音），原因：VoiceService 集成量小，拆分反而增加接口预留成本
  - 全部 12 个 ACTION 工具一次实现，原因：每个工具本质是 3-10 行 service 转发
  - app 启动即显示悬浮球（state=minimized），长按可隐藏，原因：核心功能不应藏在设置页
  - 消息仅保存在内存中，app 重启后清空，原因：对话强依赖上下文时效性

技术细节：
  - AssistantService 依赖：LlmManager, QuestionService, ExamService, MatchService, StudyPlanService, ProfileService, BaselineService（共 7 个）
  - AssistantState 枚举：hidden, minimized, expanded
  - ACTION 标记格式：`[ACTION:tool_name(param=value)]`，正则解析
  - **[C-1 修正] 导航实现**：AssistantService 暴露 `pendingNavigation`（int?）字段，AiAssistantOverlay 通过 watch 监听变化后执行导航（由 HomeScreen 在 initState 中向 Overlay 注册导航执行器）。Service 不持有任何 UI 回调，单向数据流 service→UI
  - **[C-2 修正] ACTION 解析安全性**：白名单校验工具名（12 个已知工具）；仅解析 assistant role 消息；非贪婪正则；未知工具名静默忽略并记录 warning；param value 约束为 `[a-zA-Z0-9_\-\|.\u4e00-\u9fff]` 字符集
  - **[C-3 修正] 流式更新性能**：`streamingResponse` 用独立 `ValueNotifier<String>` 暴露，UI 端用 `ValueListenableBuilder` 精准重建仅流式气泡部分，不走主 `notifyListeners()`
  - **[H-1 修正] 隐私授权**：首次使用 AI 助手时弹窗告知用户隐私发送范围，确认后存储授权状态；仅发送学历/专业/工作年限；Ollama 本地模型免授权
  - **[H-2 修正] 消息截断**：发送 LLM 时仅取 system prompt + 最近 20 条消息；内存中保留全部供 UI 展示
  - **[H-4 修正] 语音降级**：`VoiceService.initialize()` 检测实际可用性（非仅看平台类型），失败时提示用户并降级为仅文字
  - 动画：AnimationController 300ms easeOutCubic，56x56→全宽x85%高
  - System Prompt 三段式：身份定义（固定）+ 工具列表（固定）+ 当前上下文（动态从各 service 获取）
  - 语音降级：权限被拒绝时 VoiceService.isAvailable=false，隐藏麦克风按钮
  - **[H-5 修正] builder 注入**：`builder: (context, child) => Stack(children: [child!, AiAssistantOverlay()])`
  - **[LOW-1] AssistantMessage 增加 status 字段**：MessageStatus 枚举（sending/streaming/completed/error）+ 可选 errorMessage
  - **[LOW-5] ACTION 执行策略**：fail-fast，前一个失败终止后续，错误信息作为 system 消息追加到对话
  - 悬浮球拖拽边界：clamp 到 SafeArea 范围内

范围边界：
  - 做：三态 Overlay、悬浮球拖拽、对话面板、12 个 ACTION 工具、STT/TTS 语音、动态 system prompt、上下文感知
  - 不做：消息持久化、修改现有 AiChatDialog、云端对话同步
  - 保护策略：不修改 `lib/widgets/ai_chat_dialog.dart`；不新增数据库表；不在日志输出用户隐私数据

### 待细化
  - 无（设计文档已足够详细）

### 验收标准
  - [mechanical] 8 个新文件存在：判定 `ls lib/services/assistant_service.dart lib/services/voice_service.dart lib/widgets/ai_assistant/ai_assistant_overlay.dart lib/widgets/ai_assistant/assistant_bubble.dart lib/widgets/ai_assistant/assistant_dialog.dart lib/widgets/ai_assistant/assistant_input_bar.dart lib/widgets/ai_assistant/assistant_message.dart lib/widgets/ai_assistant/assistant_tools.dart`
  - [mechanical] AssistantService 已注册：判定 `grep "AssistantService" lib/main.dart`
  - [mechanical] VoiceService 已注册：判定 `grep "VoiceService" lib/main.dart`
  - [mechanical] app.dart 注入 Overlay：判定 `grep "AiAssistantOverlay" lib/app.dart`
  - [mechanical] pubspec.yaml 包含语音依赖：判定 `grep "speech_to_text" pubspec.yaml && grep "flutter_tts" pubspec.yaml`
  - [test] `flutter analyze` 零错误
  - [test] `flutter test` 全通过
  - [manual] 启动 app → 右下角悬浮球 → 点击展开 → 输入对话 → AI 流式回复 → ACTION 执行 → 最小化 → 拖拽悬浮球
  - [manual] 语音：点麦克风 → 语音输入 → 文字出现；AI 回复旁 TTS 按钮 → 语音播报
