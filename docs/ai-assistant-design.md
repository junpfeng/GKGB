# AI 智能助手浮窗 — 设计方案

> 创建日期：2026-04-07

## Context

用户需要在 app 内集成一个全局 AI 助手对话弹窗，可最小化为悬浮球、放大为完整对话面板，支持文字和语音交互，能统筹调度 app 内所有功能（刷题、模考、岗位匹配、学习计划、统计等）为用户服务。

当前 app 已有 `AiChatDialog`（底部弹窗），但仅用于单次上下文 Q&A（如题目讲解），无法跨页面持久化、无法调度功能、无语音能力。需要一个全新的全局助手系统。

---

## 架构设计

### 三态 Overlay 模型

```
hidden（隐藏）→ minimized（悬浮球）→ expanded（完整对话面板）
```

- 使用 `MaterialApp.builder` 注入全局 `Stack`，助手浮层始终位于所有页面之上
- 悬浮球可拖拽定位，对话面板覆盖屏幕 85% 高度
- 最小化/放大之间有平滑动画过渡

### 功能编排（Tool Orchestration）

AI 通过文本标记 `[ACTION:tool_name(param=value)]` 触发 app 操作：
- 兼容所有 LLM provider（不依赖 function calling）
- `AssistantService` 解析标记并分发到对应 service 执行
- 动态 system prompt 包含当前页面上下文和用户画像

### 语音交互

- STT（语音转文字）：`speech_to_text` — Windows 10+ 和 Android 均支持
- TTS（文字转语音）：`flutter_tts` — Windows SAPI5 和 Android 原生支持

**权限处理：**
- Android 需要 `RECORD_AUDIO` 权限，在 `AndroidManifest.xml` 中声明
- 首次使用麦克风时通过 `speech_to_text` 的 `initialize()` 触发系统权限弹窗
- 权限被拒绝时：隐藏麦克风按钮，仅保留文字输入（`VoiceService.isAvailable = false`）
- Windows 无需额外权限申请

---

## 新增文件

| 文件路径 | 职责 |
|---------|------|
| `lib/services/assistant_service.dart` | 助手核心服务：状态管理、消息历史、system prompt 构建、工具分发 |
| `lib/services/voice_service.dart` | 语音服务：STT/TTS 封装，平台兼容 |
| `lib/widgets/ai_assistant/ai_assistant_overlay.dart` | 顶层 Overlay：动画控制器，渲染悬浮球或对话面板 |
| `lib/widgets/ai_assistant/assistant_bubble.dart` | 悬浮球：可拖拽、点击展开、长按菜单 |
| `lib/widgets/ai_assistant/assistant_dialog.dart` | 对话面板：毛玻璃风格，消息列表，标题栏 |
| `lib/widgets/ai_assistant/assistant_input_bar.dart` | 输入栏：文字输入 + 语音按钮 + 发送按钮 |
| `lib/widgets/ai_assistant/assistant_message.dart` | 消息气泡：支持 ACTION 操作按钮、TTS 播放 |
| `lib/widgets/ai_assistant/assistant_tools.dart` | 数据模型与工具定义：AssistantMessage、ToolCommand、解析器、工具注册表 |

## 修改文件

| 文件路径 | 改动 |
|---------|------|
| `lib/app.dart` | `MaterialApp.builder` 注入 `AiAssistantOverlay` |
| `lib/main.dart` | MultiProvider 中注册 `AssistantService` 和 `VoiceService` |
| `lib/screens/home_screen.dart` | Tab 切换时调用 `assistantService.updateContext()` |
| `pubspec.yaml` | 添加 `speech_to_text: ^7.0.0` 和 `flutter_tts: ^4.2.0` |

**不修改** `lib/widgets/ai_chat_dialog.dart`（保留现有用途）。

---

## 核心类设计

### AssistantService（ChangeNotifier）

```dart
class AssistantService extends ChangeNotifier {
  // 依赖注入（7 个 service）
  final LlmManager _llm;
  final QuestionService _questionService;
  final ExamService _examService;
  final MatchService _matchService;
  final StudyPlanService _studyPlanService;
  final ProfileService _profileService;
  final BaselineService _baselineService;

  // 状态
  AssistantState state;          // hidden / minimized / expanded
  List<AssistantMessage> messages;
  String streamingResponse;
  bool isLoading;
  String currentScreen;          // 当前页面标识
  Map<String, dynamic> screenData; // 当前页面上下文数据
  Offset bubblePosition;         // 悬浮球位置
  NavigationCallback? onNavigate; // 由 HomeScreen 注册的导航回调

  // 状态控制
  void show();     // hidden → minimized
  void expand();   // minimized → expanded
  void minimize(); // expanded → minimized
  void hide();     // any → hidden

  // 消息发送
  Future<void> sendMessage(String text);
  
  // 清空对话（新对话）
  void clearMessages();
  
  // 上下文更新（各 screen 调用）
  void updateContext(String screenName, {Map<String, dynamic>? data});
  
  // 工具执行（按顺序依次执行，如先导航再开始练习）
  Future<void> _executeActions(List<ToolCommand> commands);
  
  // system prompt 构建
  String _buildSystemPrompt();
}
```

Provider 注册方式（在所有现有 provider 之后，使用 `ctx.read` 一次性读取依赖，无需 ProxyProvider——AssistantService 不需要在依赖变化时重建）：
```dart
ChangeNotifierProvider(
  create: (ctx) => AssistantService(
    llm: ctx.read<LlmManager>(),
    questionService: ctx.read<QuestionService>(),
    examService: ctx.read<ExamService>(),
    matchService: ctx.read<MatchService>(),
    studyPlanService: ctx.read<StudyPlanService>(),
    profileService: ctx.read<ProfileService>(),
    baselineService: ctx.read<BaselineService>(),
  ),
),
```

### VoiceService（ChangeNotifier）

```dart
class VoiceService extends ChangeNotifier {
  bool isListening;
  bool isSpeaking;
  bool isAvailable;      // 平台是否支持
  String recognizedText; // 实时识别文本

  Future<void> initialize();
  Future<void> startListening({Function(String)? onResult});
  Future<void> stopListening();
  Future<void> speak(String text);
  Future<void> stopSpeaking();
}
```

### AssistantMessage（消息模型）

```dart
class AssistantMessage {
  final String id;          // UUID
  final String role;        // 'user' / 'assistant' / 'system'
  final String content;     // 原始文本（含 ACTION 标记）
  final String displayText; // 纯文本（已移除 ACTION 标记）
  final List<ToolCommand> actions; // 解析出的工具命令列表（可为空列表）
  final DateTime timestamp;

  // 转换为 LLM ChatMessage（仅 role + content）
  ChatMessage toChatMessage();
}
```

### 消息持久化策略

消息**仅保存在内存中**，app 重启后对话丢失。原因：
- 助手对话强依赖上下文时效性（当前页面、当前进度），历史对话复用价值低
- 避免数据库膨胀和隐私合规风险
- 后续如需持久化，可在 `database_helper.dart` 增加 `assistant_messages` 表

### 导航实现

`navigate` 工具通过回调修改 `HomeScreen._currentIndex` 实现页面切换。`AssistantService` 持有一个 `NavigationCallback`：
```dart
typedef NavigationCallback = void Function(int tabIndex);
```
由 `HomeScreen` 在 `initState` 中注册，screen 名称到 index 的映射在 `assistant_tools.dart` 中维护。

### ToolCommand 和工具解析

```dart
class ToolCommand {
  final String name;
  final Map<String, String> params;
}

// 从 AI 回复中提取所有 [ACTION:name(k=v,k2=v2)]（一条回复可能包含多个 ACTION）
List<ToolCommand> parseToolCommands(String response);

// 从 AI 回复中移除 ACTION 标记，返回纯文本
String stripActionTags(String response);
```

---

## AI System Prompt 策略

动态构建，分三段：

**1. 身份定义（固定）**
```
你是"考公智能助手"，专业的公务员考试备考助手。你可以帮助用户：
刷题练习、模拟考试、岗位匹配分析、学习计划制定、统计分析。请用简洁友好的中文回答。
```

**2. 可用工具列表（固定）**
```
当用户需要执行操作时，在回复末尾用 [ACTION:tool(param=value)] 标注：

**导航类：**
- [ACTION:navigate(screen=practice)] — 切换到刷题页（index=0）
- [ACTION:navigate(screen=exam)] — 切换到模考页（index=1）
- [ACTION:navigate(screen=match)] — 切换到岗位匹配页（index=2）
- [ACTION:navigate(screen=stats)] — 切换到统计页（index=3）
- [ACTION:navigate(screen=profile)] — 切换到个人信息页（index=4）

**刷题类：**
- [ACTION:start_practice(subject=言语理解)] — 开始练习（可选参数：category, type）
- [ACTION:load_wrong_questions(subject=数量关系)] — 查看错题
- [ACTION:toggle_favorite(questionId=123)] — 收藏/取消收藏题目

**考试类：**
- [ACTION:start_exam(subject=行测,count=20,timeSeconds=3600)] — 开始模考（time 单位：秒）
- [ACTION:show_exam_history()] — 查看考试历史

**学习规划类：**
- [ACTION:generate_plan(examDate=2026-05-01)] — 生成学习计划
- [ACTION:adjust_plan()] — 调整学习计划
- [ACTION:start_baseline(subjects=言语理解|数量关系)] — 摸底测试

**其他：**
- [ACTION:run_match()] — 执行岗位匹配
- [ACTION:show_stats()] — 查看统计
```

**3. 当前上下文（动态，由 `_buildSystemPrompt()` 从各 service 实时获取）**
```
当前页面：刷题（言语理解，第3题/共20题）  ← screenName + screenData
用户画像：本科，计算机专业，2年工作经验    ← ProfileService.profile
今日学习：已做15题，正确率73%              ← QuestionService.answeredCount / correctCount
学习计划：距考试45天，今日任务完成50%       ← StudyPlanService.currentPlan
```

---

## UI 设计

### 悬浮球（AssistantBubble）
- 56x56 渐变圆形（`AppTheme.primaryGradient`）
- 图标：`Icons.smart_toy`
- 可拖拽（`GestureDetector.onPanUpdate`）
- 点击 → expand，长按 → 快捷菜单（新对话/隐藏）
- 默认位置：右下角（`right: 16, bottom: kBottomNavigationBarHeight + 16`），基于 `MediaQuery` 动态计算

### 对话面板（AssistantDialog）
- 毛玻璃背景（复用 `AiChatDialog` 视觉风格）
- 高度 85% 屏幕，圆角顶部
- 标题栏：AI 图标 + "智能助手" + 最小化按钮 + 关闭按钮
- 消息列表：用户气泡（渐变）/ AI 气泡（浅色）
- AI 消息附带操作按钮（当 AI 建议 ACTION 时显示为可点击 Chip）
- AI 消息附带 TTS 播放按钮
- 输入栏：文字框 + 麦克风按钮 + 发送按钮

### 动画过渡
- `AnimationController` 0.0→1.0，300ms，`Curves.easeOutCubic`
- 尺寸：56x56 → 全宽x85%高
- 圆角：28 → 24（仅顶部）
- 位置：悬浮球坐标 → 底部对齐
- 内容（消息列表/输入栏）在动画 70%-100% 区间淡入

---

## 实现分阶段

### Phase 1：基础框架
1. 创建 `assistant_tools.dart`（ToolCommand、AssistantMessage 模型、解析器、工具注册）
2. 创建 `AssistantService`（状态管理、消息历史、system prompt）
3. 注册到 `main.dart` 的 MultiProvider

### Phase 2：Overlay UI
1. 创建 `AiAssistantOverlay`（动画控制器、状态切换）
2. 创建 `AssistantBubble`（可拖拽悬浮球）
3. 创建 `AssistantDialog`（对话面板、消息列表）
4. 创建 `AssistantInputBar`（文字输入 + 发送）
5. 创建 `AssistantMessage`（消息气泡 + ACTION 按钮）
6. 修改 `app.dart` 注入 Overlay

### Phase 3：功能编排
1. 实现所有工具执行器（导航、开始练习、模考、匹配等）
2. 在 `home_screen.dart` 添加 tab 切换时的上下文更新
3. 端到端测试：用户提问 → AI 回复带 ACTION → app 执行

### Phase 4：语音集成
1. `pubspec.yaml` 添加 `speech_to_text`、`flutter_tts`
2. 创建 `VoiceService`
3. `AssistantInputBar` 集成麦克风按钮
4. `AssistantMessage` 集成 TTS 播放按钮
5. 注册 `VoiceService` 到 `main.dart`

---

## 验证方式

1. `flutter analyze` — 零错误
2. `flutter test` — 全通过
3. 手动验证（`flutter run -d windows`）：
   - 启动 app → 悬浮球出现在右下角
   - 点击悬浮球 → 动画展开为对话面板
   - 输入"帮我开始言语理解练习" → AI 回复 + 跳转到练习页
   - 点击最小化 → 动画收缩为悬浮球
   - 拖拽悬浮球 → 位置跟随手指
   - 点击麦克风 → 语音输入 → 文字出现在输入框
   - AI 回复旁 TTS 按钮 → 语音播报
