# AI 智能助手浮窗 -- 对抗性架构审查

> 审查日期：2026-04-07
> 审查对象：`docs/features/ai_assistant/idea.md` 确认方案 + `docs/ai-assistant-design.md`
> 审查基线：`.claude/rules/constitution.md` 架构约束

---

## 严重问题（必须修改）

### [CRITICAL-1] NavigationCallback 构成 service 对 screen 的反向依赖

**问题**：`AssistantService` 持有 `NavigationCallback`，由 `HomeScreen.initState` 注册。这意味着：
1. `AssistantService`（service 层）的行为依赖于 `HomeScreen`（screen 层）是否注册了回调
2. `HomeScreen` 向 service 注入一个操作自身 `_currentIndex` 的闭包，形成 service -> screen 的隐式控制流

宪法明确规定：**分层依赖方向: screens -> services -> db/models，禁止反向依赖**。虽然 `AssistantService` 没有 `import` screen 文件，但通过回调闭包持有了对 screen 私有状态的引用，这是经典的控制反转绕过分层约束。

**攻击场景**：
- 如果 `HomeScreen` 被销毁重建（如热重载、路由替换），旧闭包引用的 `setState` 指向已 dispose 的 State，调用将抛异常
- 如果未来其他 screen 也需要导航控制（如从子页面触发），需要重复注册模式，扩展性差

**改进建议**：导航职责应由 UI 层响应 service 状态变化来完成，而非 service 主动调用。方案：
- `AssistantService` 仅暴露 `pendingNavigation` 字段（目标 tab index），UI 层通过 `context.watch` 监听变化后自行执行导航
- 或者使用 `NavigatorKey` / `GlobalKey<HomeScreenState>` 等 Flutter 标准机制，但仍应由 Overlay Widget 消费 service 状态后执行跳转，而非 service 直接操作

---

### [CRITICAL-2] ACTION 正则解析缺乏鲁棒性，无转义/嵌套防护

**问题**：ACTION 格式 `[ACTION:tool_name(param=value)]` 使用正则解析，但设计中未定义：
1. param value 中包含 `)`、`=`、`,`、`]` 等特殊字符时如何处理
2. 用户输入中恰好包含 `[ACTION:...]` 格式的文本时如何区分
3. AI 幻觉生成格式错误的 ACTION（如缺少闭合括号、未知 tool_name）时的降级行为
4. value 中包含中文逗号 `，` 或全角括号 `（）` 时是否误匹配

**攻击场景**：
- 用户输入："请解释一下 [ACTION:navigate(screen=exam)] 这个格式是什么意思" -- 会被误解析为导航指令
- AI 回复中 subject 参数值含括号："[ACTION:start_practice(subject=判断推理(图形))]" -- 正则 `\)` 提前终止
- AI 生成非法工具名："[ACTION:delete_all_data()]" -- 若无白名单校验，可能触发异常

**改进建议**：
1. 正则需使用非贪婪匹配 + 白名单工具名校验：`\[ACTION:(navigate|start_practice|...)\(([^)]*)\)\]`
2. 对未知工具名静默忽略，记录 warning 日志
3. param value 约定只允许 `[a-zA-Z0-9_\-\|.\u4e00-\u9fff]` 字符集，超出范围的做 URL encode
4. 仅解析 AI（assistant role）消息中的 ACTION，忽略 user 消息中的标记

---

### [CRITICAL-3] streamChat 期间 setState/notifyListeners 频率无节流

**问题**：`LlmManager.streamChat()` 每收到一个 chunk 就 emit，设计中 `AssistantService` 将 chunk 追加到 `streamingResponse` 后调用 `notifyListeners()`，UI 通过 `context.watch` 触发 rebuild。

流式响应的 chunk 粒度通常是 1-3 个 token（几个字符），对于一段 500 字的回复，可能触发 200+ 次 `notifyListeners()` -> 200+ 次 Widget rebuild。

**攻击场景**：
- 低端 Android 设备上，每次 rebuild 需要重新布局消息列表 + 滚动到底部 + 毛玻璃渲染，可能导致明显卡顿
- 如果 `AssistantDialog` 的 `context.watch<AssistantService>()` 位置过高，整个面板（标题栏+消息列表+输入栏）都会重建

**改进建议**：
1. 在 `AssistantService` 中对 `streamingResponse` 的更新做节流：收集 chunk，每 50-100ms 批量 flush 一次 `notifyListeners()`
2. 或者 `streamingResponse` 不走 `notifyListeners()`，改用 `ValueNotifier<String>` 单独暴露，UI 端用 `ValueListenableBuilder` 精准重建仅消息气泡部分
3. 消息列表使用 `Selector` 或 `Consumer` 缩小 rebuild 范围，避免整个面板重建

---

## 高风险问题（推荐修改）

### [HIGH-1] System Prompt 中嵌入用户隐私数据，发送至第三方 LLM

**问题**：`_buildSystemPrompt()` 将用户画像（学历、专业、户籍省份、工作年限、政治面貌等）拼入 system prompt 发送给第三方 LLM API（DeepSeek/通义千问/Claude 等）。

宪法规定："用户个人信息（画像数据）仅存储在本地 SQLite，上传云端前必须经过用户明确授权"。将隐私数据嵌入 LLM 请求 == 上传到第三方云端。

**严重程度说明**：标注 HIGH 而非 CRITICAL，因为 LLM 调用本身需要上下文才有价值，完全不传用户信息会大幅降低助手能力。但需要授权机制。

**改进建议**：
1. 首次使用 AI 助手时弹窗告知用户："智能助手需要将您的部分信息（学历、专业等）发送至 AI 服务以提供个性化建议"，用户确认后存储授权状态
2. 脱敏处理：仅发送必要字段（学历、专业、工作年限），不发送户籍省份、年龄、性别等与备考策略无关的字段
3. 如果用户选择 Ollama 本地模型，无需此授权（数据不出设备）

---

### [HIGH-2] 消息列表无限增长，长对话场景内存泄漏

**问题**：`List<AssistantMessage> messages` 仅在内存中，无上限约束。设计中也没有清空机制的自动触发（仅有手动 `clearMessages()`）。

**攻击场景**：
- 用户在一次会话中持续对话 100+ 轮，每轮消息含完整 system prompt 上下文
- system prompt 每次调用都从各 service 获取完整上下文，这些内容也会作为历史消息累积
- LLM 请求会带上全部历史消息（`messages.map((m) => m.toChatMessage()).toList()`），导致 token 超限、请求失败、费用暴涨

**改进建议**：
1. 设置消息历史上限（如 50 条），超出时滑动窗口丢弃最早的消息（保留第一条 system prompt）
2. 发送给 LLM 的历史做截断，只取最近 N 条 + system prompt
3. 或者在消息数达到阈值时提示用户"建议开启新对话"

---

### [HIGH-3] AssistantService 持有 7 个 service 引用的生命周期风险

**问题**：`AssistantService` 在构造函数中通过 `ctx.read` 一次性获取 7 个 service 引用。设计明确选择了 `ChangeNotifierProvider`（非 ProxyProvider），理由是"不需要随依赖变化重建"。

但这引入了隐患：
1. 如果任何一个被依赖的 service 在 Provider 树中被 dispose 并重建（虽然当前架构不会，但未来重构可能），`AssistantService` 持有的是旧实例的引用
2. `AssistantService` 不会收到被依赖 service 的状态变化通知——例如用户在统计页手动刷新了 `QuestionService` 的数据，`AssistantService` 构建的 system prompt 可能使用过时的上下文

**改进建议**：
- 当前架构下风险可控，但应在 `_buildSystemPrompt()` 中每次实时读取 service 属性（已经是这样设计的），确保不缓存中间结果
- 在代码注释中明确标注：这 7 个 service 的生命周期必须 >= `AssistantService`，Provider 注册顺序不可调换
- 考虑对关键 service（如 `LlmManager`）增加 null 检查/可用性校验

---

### [HIGH-4] VoiceService 平台兼容性设计不完整

**问题**：
1. `speech_to_text` 在 Windows 10+ 支持 SAPI，但实际上 Windows 桌面 Flutter 的 `speech_to_text` 插件支持状况参差不齐——部分版本不支持 Windows，需确认 ^7.0.0 版本的 Windows 兼容性
2. 设计中仅提到"权限被拒绝时隐藏麦克风按钮"，但未提到 Windows 上缺少麦克风硬件、或 SAPI 语音识别语言包未安装的情况
3. `flutter_tts` 在 Windows 上使用 SAPI5，默认可能只有英文语音包，中文 TTS 需要用户手动安装中文语音包——设计中未提及这种降级场景

**改进建议**：
1. `VoiceService.initialize()` 需要检测实际可用性，不能仅看平台类型
2. 初始化失败时应有明确的用户提示（如"当前设备不支持语音功能"），而非静默隐藏
3. 在设计文档中增加 Windows 环境的语音功能依赖说明

---

### [HIGH-5] app.dart 注入方式需要重构为 builder，但设计未展示具体实现

**问题**：当前 `app.dart` 使用 `home: const HomeScreen()`，没有 `builder`。设计说"在 `MaterialApp.builder` 中包裹 `AiAssistantOverlay`"，但未展示 `AiAssistantOverlay` 如何获取 `MediaQuery`、`Navigator` 等上下文。

关键细节：`MaterialApp.builder` 的 child 是 `Navigator`，如果 `AiAssistantOverlay` 包在 `builder` 中：
- 它在 `Navigator` 之上，无法使用 `Navigator.of(context)` 做页面跳转
- 需要通过回调或 GlobalKey 访问 Navigator（回到 CRITICAL-1 的问题）

**改进建议**：
- 明确 `builder` 的实现方式，例如：
  ```dart
  builder: (context, child) => Stack(
    children: [child!, AiAssistantOverlay()],
  )
  ```
- 确认 `AiAssistantOverlay` 不需要 Navigator 访问（当前设计确实不需要，导航通过回调实现，但这又回到了 CRITICAL-1 的问题）

---

### [HIGH-6] Android RECORD_AUDIO 权限未在 AndroidManifest.xml 中预声明

**问题**：当前 `android/app/src/main/AndroidManifest.xml` 中没有 `RECORD_AUDIO` 权限声明。设计文档说"在 `AndroidManifest.xml` 中声明"，但这属于实现任务而非设计决策——如果遗漏，运行时 `speech_to_text.initialize()` 会直接 crash 或返回永久不可用。

**改进建议**：在实现 checklist 中明确标注此项为 Phase 4 阻塞项，并增加验收标准：
```
[mechanical] grep "RECORD_AUDIO" android/app/src/main/AndroidManifest.xml
```

---

## 低风险问题（建议关注）

### [LOW-1] AssistantMessage 模型缺少 isError / isLoading 状态字段

**问题**：当前 `AssistantMessage` 仅有 role/content/displayText/actions/timestamp。没有字段表示：
- 消息正在加载中（streaming 未完成）
- 消息发送失败（网络错误、LLM 返回错误）
- ACTION 执行结果（成功/失败）

**改进建议**：增加 `MessageStatus` 枚举（sending/streaming/completed/error），以及可选的 `errorMessage` 字段。

---

### [LOW-2] 悬浮球拖拽边界约束未定义

**问题**：悬浮球可拖拽到屏幕任意位置，但未定义：
- 是否可以拖出屏幕边缘？
- 横竖屏切换（Android）后位置是否重新计算？
- 键盘弹出时悬浮球是否被遮挡？
- 拖拽结束后是否自动吸附到最近边缘（常见 UX 模式）？

**改进建议**：
1. 拖拽时 clamp 坐标到 `SafeArea` 范围内
2. 监听 `MediaQuery` 变化，重新校正位置
3. 考虑增加边缘吸附行为（非必须，但体验更好）

---

### [LOW-3] 动画过渡从悬浮球坐标到底部对齐的插值路径可能不自然

**问题**：悬浮球可能在屏幕左上角，展开动画要到底部对齐的全宽面板，300ms 内同时变化位置+尺寸+圆角，视觉上可能跳跃。

**改进建议**：考虑使用 Hero 动画或分步动画（先移动到底部，再展开尺寸），或者展开时直接从底部弹出（忽略悬浮球当前位置），与现有 `AiChatDialog` 的 `showModalBottomSheet` 行为一致。

---

### [LOW-4] 12 个 ACTION 工具一次实现的测试覆盖风险

**问题**：设计选择一次实现全部 12 个 ACTION，理由是"每个工具本质是 3-10 行 service 转发"。但验收标准中只有一条手动测试项覆盖 ACTION 执行，没有针对各工具的单元测试标准。

**改进建议**：
1. 增加验收标准：每个 ACTION 工具至少有 1 个单元测试（解析正确性 + 分发正确性）
2. 增加边界用例测试：无参 ACTION、缺参 ACTION、多 ACTION 同时出现、ACTION 顺序执行

---

### [LOW-5] 工具执行顺序语义不明确

**问题**：设计提到"按顺序依次执行，如先导航再开始练习"，但未定义：
- 如果前一个 ACTION 执行失败，后续 ACTION 是否继续？
- 执行结果是否反馈给 AI（作为下一轮上下文）？
- 是否有执行超时机制？

**改进建议**：定义明确的执行策略——建议"fail-fast + 错误反馈"：前一个失败则终止后续，将错误信息作为 system 消息追加到对话中。

---

## 确认无问题的部分

1. **LLM 调用路径合规**：通过 `LlmManager.streamChat()` 调用，不直接依赖具体 Provider，符合宪法约束。

2. **不修改现有 AiChatDialog**：保留现有单次 Q&A 场景，新助手系统独立，避免了引入回归风险。

3. **消息仅内存存储的决策**：考虑到对话强依赖时效性上下文和隐私合规，不持久化是合理的。

4. **Provider 注册顺序**：`AssistantService` 在所有依赖之后注册，`ctx.read` 读取时依赖已就绪。

5. **文件组织结构**：8 个新文件划分清晰，widgets 放在 `lib/widgets/ai_assistant/` 子目录，services 放在 `lib/services/`，符合项目规范。

6. **VoiceService 独立性**：与 `AssistantService` 解耦，无依赖关系，可独立初始化和降级。

7. **三态状态机设计**：hidden/minimized/expanded 三态转换覆盖了所有用户场景，状态枚举简洁明确。

---

## 总结

| 级别 | 数量 | 需处理 |
|------|------|--------|
| CRITICAL | 3 | 必须在实现前修改设计 |
| HIGH | 6 | 强烈建议修改，至少在实现时覆盖 |
| LOW | 5 | 实现时关注即可 |

**最高优先修复项**：
1. CRITICAL-1：NavigationCallback 反向依赖 -- 改为 service 暴露状态、UI 消费状态的单向流
2. CRITICAL-2：ACTION 解析鲁棒性 -- 增加白名单、特殊字符处理、user 消息免解析
3. CRITICAL-3：流式更新节流 -- 避免高频 rebuild 导致低端设备卡顿
