---
generated: 2026-04-07T00:00:00+08:00
git_branch: feature/ai_assistant
---

# 验收报告：AI 智能助手浮窗

## 验收标准

[PASS] AC-01: 8 个新文件存在 — `ls` 确认全部存在
[PASS] AC-02: AssistantService 已注册 — `grep "AssistantService" lib/main.dart` 命中
[PASS] AC-03: VoiceService 已注册 — `grep "VoiceService" lib/main.dart` 命中
[PASS] AC-04: app.dart 注入 Overlay — `grep "AiAssistantOverlay" lib/app.dart` 命中
[PASS] AC-05: pubspec.yaml 含语音依赖 — speech_to_text + flutter_tts 均命中
[PASS] AC-06: RECORD_AUDIO 权限 — AndroidManifest.xml 中已声明
[PASS] AC-07: `flutter analyze` — No issues found!
[PASS] AC-08: `flutter test` — 37 tests passed
[MANUAL] AC-09: 启动 app → 悬浮球 → 展开 → 对话 → ACTION 执行 → 最小化 → 拖拽
[MANUAL] AC-10: 语音：麦克风输入 + TTS 播报

## 红蓝对抗修正项验证

[PASS] C-1: pendingNavigation 字段存在，service 不持有 UI 回调
[PASS] C-2: 白名单校验 + 仅解析 assistant role（grep 确认）
[PASS] C-3: streamingResponse 用 ValueNotifier，UI 用 ValueListenableBuilder
[PASS] H-1: 隐私授权机制（privacyConsent）
[PASS] H-2: 消息截断（最近 20 条 + system prompt）
[PASS] H-4: VoiceService.initialize() 检测实际可用性
[PASS] H-5: builder 注入方式
[PASS] LOW-1: MessageStatus 枚举
[PASS] LOW-5: fail-fast 执行策略

## 实现概要

- 新增文件:
  - lib/services/assistant_service.dart
  - lib/services/voice_service.dart
  - lib/widgets/ai_assistant/ai_assistant_overlay.dart
  - lib/widgets/ai_assistant/assistant_bubble.dart
  - lib/widgets/ai_assistant/assistant_dialog.dart
  - lib/widgets/ai_assistant/assistant_input_bar.dart
  - lib/widgets/ai_assistant/assistant_message.dart
  - lib/widgets/ai_assistant/assistant_tools.dart
- 修改文件:
  - lib/app.dart
  - lib/main.dart
  - lib/screens/home_screen.dart
  - pubspec.yaml
  - android/app/src/main/AndroidManifest.xml

## 结论

机械验收: 8/8 通过
手动验证: 2 项待确认
