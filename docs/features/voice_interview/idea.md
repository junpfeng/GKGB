# AI 面试辅导（语音模式）

## 核心需求
基于文字面试模式（已实现），扩展语音交互：用户口述回答（STT）→ AI 评分 → AI 朗读点评（TTS）。speech_to_text 和 flutter_tts 已在 pubspec 中。

## 确认方案

核心思路：扩展现有 InterviewService 和 interview_session_screen，增加语音输入（STT）和语音输出（TTS）能力，复用已有评分逻辑。不新建 DB 表。

### 锁定决策

**数据层：**

1. `interview_sessions` 表 ALTER 新增 `mode TEXT DEFAULT 'text'`（text/voice）
2. DB version 9 → 10（与 adaptive_quiz 的 v9 衔接），_createDB 和 _onUpgrade 同步

**服务层：**

3. 扩展现有 `VoiceService`（已存在 lib/services/voice_service.dart）：
   - 确保 `startListening()` / `stopListening()` / `speak()` 方法完备
   - 添加 `isListening` / `isSpeaking` 状态
   - Windows 端 STT 可能不可用，做 Platform 判断 + 降级提示

4. 扩展 `InterviewService`：
   - `startInterview` 新增 `mode` 参数（'text' / 'voice'）
   - 语音模式下：题目自动 TTS 朗读 → 用户按钮触发 STT → 识别结果填入答案 → 复用已有评分逻辑
   - 评分完成后 TTS 朗读点评摘要

**UI 层：**

5. 修改 `interview_home_screen.dart`：增加模式选择（文字/语音切换开关）

6. 修改 `interview_session_screen.dart`：
   - 语音模式 UI：大号麦克风按钮（按住说话/点击开始）+ 实时波形/状态指示
   - STT 识别结果实时显示在文本框（可手动修改后提交）
   - TTS 播放状态指示
   - 文字模式保持不变

7. 新增 `lib/widgets/voice_input_widget.dart`：
   - 封装 STT 交互（麦克风按钮 + 状态动画 + 识别文本回调）
   - Platform 判断：不支持时显示"当前平台不支持语音输入"

**预防性修正：**

8. STT/TTS 权限处理：麦克风权限请求（Android）
9. Windows 端降级：STT 不可用时自动回退文字模式，TTS 尝试系统引擎
10. 语音识别超时：30s 无输入自动停止
11. TTS 朗读可中断：用户点击跳过

**范围边界：**
- 做：语音输入（STT）、语音输出（TTS）、模式切换、波形动画、平台降级
- 不做：口头禅检测、语速分析、音频录制存储

### 验收标准
- [mechanical] mode 字段：`grep -c "mode.*text.*voice\|interview_mode" lib/db/database_helper.dart` >= 1
- [mechanical] voice_input_widget：`ls lib/widgets/voice_input_widget.dart`
- [mechanical] DB version 10：`grep "version: 10" lib/db/database_helper.dart`
- [mechanical] 模式选择 UI：`grep -c "voice\|语音" lib/screens/interview_home_screen.dart` >= 1
- [test] `flutter test`
- [mechanical] `flutter analyze` 零错误
- [manual] 运行 `flutter run -d windows` 验证语音模式切换可见
