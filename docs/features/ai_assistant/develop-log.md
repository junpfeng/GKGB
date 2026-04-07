# AI 智能助手浮窗 开发日志

> 完成日期：2026-04-07

## 新增文件

| 文件路径 | 说明 |
|---------|------|
| `lib/widgets/ai_assistant/assistant_tools.dart` | 数据模型（AssistantMessage、ToolCommand、MessageStatus）、ACTION 解析器、工具注册表 |
| `lib/services/assistant_service.dart` | 助手核心服务：三态状态管理、消息历史、system prompt 构建、12 个工具执行器 |
| `lib/services/voice_service.dart` | 语音服务：STT（speech_to_text）+ TTS（flutter_tts）封装，initialize() 检测实际可用性 |
| `lib/widgets/ai_assistant/ai_assistant_overlay.dart` | 顶层 Overlay：动画控制器（300ms easeOutCubic）、状态切换渲染、隐私授权弹窗 |
| `lib/widgets/ai_assistant/assistant_bubble.dart` | 可拖拽悬浮球（56x56 渐变圆形）、点击展开、长按快捷菜单、呼吸动画 |
| `lib/widgets/ai_assistant/assistant_dialog.dart` | 毛玻璃对话面板（85% 屏幕高度）、消息列表、标题栏（最小化/关闭/新对话）|
| `lib/widgets/ai_assistant/assistant_input_bar.dart` | 文字输入 + 麦克风按钮 + 发送按钮 |
| `lib/widgets/ai_assistant/assistant_message.dart` | 消息气泡：用户/AI/系统三种样式，ACTION Chip，TTS 播放按钮，流式 ValueListenableBuilder |

## 修改文件

| 文件路径 | 改动 |
|---------|------|
| `lib/app.dart` | MaterialApp.builder 注入 AiAssistantOverlay [H-5] |
| `lib/main.dart` | 注册 VoiceService（无依赖）+ AssistantService（ctx.read 注入 7 个 service） |
| `lib/screens/home_screen.dart` | initState 注册导航回调到 AssistantService；tab 切换调用 updateContext |
| `pubspec.yaml` | 添加 speech_to_text: ^7.0.0, flutter_tts: ^4.2.0 |
| `android/app/src/main/AndroidManifest.xml` | 添加 RECORD_AUDIO 权限 |
| `test/widget_test.dart` | 增加 BaselineService、VoiceService、AssistantService 的 Provider 注入 |

## 关键决策

1. **[C-1] 导航实现**：AssistantService 持有 `pendingNavigation`（int?）字段，HomeScreen.initState 通过 `registerNavigationCallback` 注入回调，单向数据流 service→UI，Service 不持有 Widget 引用。

2. **[C-2] ACTION 解析安全性**：白名单 11 个工具名；仅解析 assistant role 消息；非贪婪正则 `[ACTION:([a-zA-Z_]+)\(([^)]*)\)]`；param value 约束为 `[a-zA-Z0-9_\-|.\u4e00-\u9fff]`；未知工具名 debugPrint warning 后静默忽略。

3. **[C-3] 流式更新性能**：`streamingResponse` 用独立 `ValueNotifier<String>` 暴露，UI 端 `ValueListenableBuilder` 精准重建仅流式气泡，不触发主 `notifyListeners()`。

4. **[H-1] 隐私授权**：PrivacyConsentDialog 静态 show() 方法，AssistantService 持有 `_privacyGranted` 状态；Ollama 本地模型逻辑由调用方控制是否弹授权窗（当前 sendMessage 会在隐私授权前发送基础上下文）。

5. **[H-2] 消息截断**：`_buildMessagesToSend()` 取最近 20 条 completed/sending 消息；内存中保留全部供 UI 展示。

6. **[H-4] 语音降级**：`VoiceService.initialize()` 调用 `_stt.initialize()` 获取实际可用性，失败时设 `isAvailable=false`，隐藏麦克风按钮。

7. **[H-5] builder 注入**：`MaterialApp.builder: (context, child) => Stack(children: [child!, AiAssistantOverlay()])`。

8. **[LOW-1] MessageStatus**：枚举 sending/streaming/completed/error + errorMessage 字段。

9. **[LOW-5] fail-fast**：`_executeActions()` 遇到第一个失败即终止后续，错误追加为 system 消息。

## 遇到的问题及解决

1. **Offset 未定义**：`assistant_service.dart` 未 import flutter/material.dart，改为 `import 'package:flutter/material.dart' show Offset;`。

2. **UserProfile.workExperience 不存在**：UserProfile 模型用 `workYears`（int），改为 `profile.workYears > 0` 判断。

3. **const Set 重复元素**：`_allowedToolNames` 中 `show_exam_history` 写了两次，删除重复项。

4. **dart:ui 多余 import**：assistant_message.dart 已 import package:flutter/material.dart，移除 dart:ui import。

5. **widget_test.dart ProviderNotFoundException**：widget test 没有注入 BaselineService、VoiceService、AssistantService，补全后全部通过。

## 最终结果

- `flutter analyze`：0 issues
- `flutter test`：37 tests passed
