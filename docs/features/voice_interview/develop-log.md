# AI 面试辅导语音模式 - 开发日志

## 功能概述
基于已有文字面试模式，扩展语音交互能力：TTS 朗读题目/点评 + STT 语音输入回答，复用已有评分逻辑。

## 实现记录（2026-04-07）

### 数据层
| 变更 | 文件 | 说明 |
|------|------|------|
| DB version 9→10 | `lib/db/database_helper.dart` | `interview_sessions` 表新增 `mode TEXT DEFAULT 'text'` |
| _createDB 同步 | 同上 | 新建库直接包含 mode 字段 |
| _onUpgrade v9→v10 | 同上 | ALTER TABLE 增加 mode 列 |
| v4→v5 迁移同步 | 同上 | 该迁移中 CREATE TABLE 也包含 mode 字段 |
| InterviewSession 模型 | `lib/models/interview_session.dart` | 新增 mode 字段（构造、fromDb、toDb、copyWith） |
| .g.dart 重新生成 | `lib/models/interview_session.g.dart` | `dart run build_runner build` |

### 服务层
| 变更 | 文件 | 说明 |
|------|------|------|
| startInterview 加 mode 参数 | `lib/services/interview_service.dart` | 默认 'text'，创建会话时写入 DB |
| interviewMode getter | 同上 | 暴露当前面试模式供 UI 使用 |
| VoiceService | `lib/services/voice_service.dart` | 已存在，无需修改。startListening/stopListening/speak 已完备 |

### UI 层
| 变更 | 文件 | 说明 |
|------|------|------|
| VoiceInputWidget（新建） | `lib/widgets/voice_input_widget.dart` | 封装 STT 交互：大号麦克风按钮 + 脉冲动画 + 波形指示 + 识别文本回调 + Platform 降级提示 |
| 模式选择 UI | `lib/screens/interview_home_screen.dart` | 文字/语音切换开关（Chip 样式），语音模式 STT 不可用时自动降级 |
| 历史记录模式标识 | 同上 | 语音模式会话显示麦克风图标 |
| 语音面试 UI | `lib/screens/interview_session_screen.dart` | 题目 TTS 朗读 + 跳过按钮、VoiceInputWidget 语音输入、识别文本可编辑、点评 TTS 朗读 + 停止、AppBar 模式标识 |

### 锁定决策对照

| # | 决策 | 状态 |
|---|------|------|
| 1 | interview_sessions ALTER 新增 mode | ✅ |
| 2 | DB version 9→10，_createDB 和 _onUpgrade 同步 | ✅ |
| 3 | 扩展 VoiceService（已完备，无需修改） | ✅ |
| 4 | InterviewService.startInterview 新增 mode 参数 | ✅ |
| 5 | interview_home_screen 模式选择 | ✅ |
| 6 | interview_session_screen 语音模式 UI | ✅ |
| 7 | VoiceInputWidget 封装 | ✅ |
| 8 | STT/TTS 权限处理（Android 麦克风权限由 speech_to_text 内部处理） | ✅ |
| 9 | Windows 端降级（STT 不可用时回退文字模式） | ✅ |
| 10 | 语音识别超时 30s（VoiceService.startListening listenFor: 30s） | ✅ |
| 11 | TTS 朗读可中断（跳过按钮） | ✅ |

### 验证结果
- `flutter analyze`: 0 issues
- `flutter test`: 37/37 passed
- 验收标准 mechanical checks: 全部通过

### 文件变更清单
- `lib/db/database_helper.dart` — DB v10, mode 字段
- `lib/models/interview_session.dart` — mode 字段
- `lib/models/interview_session.g.dart` — 自动生成
- `lib/services/interview_service.dart` — mode 参数 + interviewMode getter
- `lib/widgets/voice_input_widget.dart` — 新建，STT 封装组件
- `lib/screens/interview_home_screen.dart` — 模式切换 UI
- `lib/screens/interview_session_screen.dart` — 语音模式交互 UI
