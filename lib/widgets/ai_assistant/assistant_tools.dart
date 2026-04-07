import 'package:flutter/foundation.dart';
import '../../services/llm/llm_provider.dart';

/// 消息状态枚举 [LOW-1]
enum MessageStatus {
  sending,    // 用户消息已发出，等待 LLM 响应
  streaming,  // AI 消息正在流式输出
  completed,  // 消息已完成
  error,      // 发生错误
}

/// 工具命令（单个 ACTION 解析结果）
class ToolCommand {
  final String name;
  final Map<String, String> params;

  const ToolCommand({required this.name, required this.params});

  @override
  String toString() => 'ToolCommand(name: $name, params: $params)';
}

/// 助手消息模型（纯内存，不持久化）
class AssistantMessage {
  final String id;
  final String role;          // 'user' / 'assistant' / 'system'
  final String content;       // 原始文本（含 ACTION 标记）
  final String displayText;   // 纯文本（已移除 ACTION 标记）
  final List<ToolCommand> actions; // 解析出的工具命令列表
  final DateTime timestamp;
  final MessageStatus status;
  final String? errorMessage;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.displayText,
    required this.actions,
    required this.timestamp,
    this.status = MessageStatus.completed,
    this.errorMessage,
  });

  /// 转换为 LLM ChatMessage（仅 role + content）
  ChatMessage toChatMessage() => ChatMessage(role: role, content: content);

  /// 创建副本（用于更新状态）
  AssistantMessage copyWith({
    String? content,
    String? displayText,
    List<ToolCommand>? actions,
    MessageStatus? status,
    String? errorMessage,
  }) {
    return AssistantMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      displayText: displayText ?? this.displayText,
      actions: actions ?? this.actions,
      timestamp: timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ===== ACTION 解析器 =====

/// 白名单工具名（12 个已知工具） [C-2]
const Set<String> _allowedToolNames = {
  'navigate',
  'start_practice',
  'load_wrong_questions',
  'toggle_favorite',
  'start_exam',
  'show_exam_history',
  'generate_plan',
  'adjust_plan',
  'start_baseline',
  'run_match',
  'show_stats',
};

/// param value 允许的字符集 [C-2]
final _paramValuePattern = RegExp(r'^[a-zA-Z0-9_\-|.\u4e00-\u9fff]+$');

/// ACTION 解析正则（非贪婪）[C-2]
final _actionRegex = RegExp(
  r'\[ACTION:([a-zA-Z_]+)\(([^)]*)\)\]',
  multiLine: true,
);

/// 从 AI 回复中提取所有工具命令（仅解析 assistant role 消息）[C-2]
List<ToolCommand> parseToolCommands(String response, {String role = 'assistant'}) {
  // 仅解析 assistant role [C-2]
  if (role != 'assistant') return [];

  final commands = <ToolCommand>[];
  for (final match in _actionRegex.allMatches(response)) {
    final toolName = match.group(1)!;
    // 白名单校验，未知工具名静默忽略 [C-2]
    if (!_allowedToolNames.contains(toolName)) {
      debugPrint('[AssistantTools] 警告：未知工具名 $toolName，已忽略');
      continue;
    }

    final paramsStr = match.group(2) ?? '';
    final params = <String, String>{};
    if (paramsStr.isNotEmpty) {
      // 解析 key=value 参数
      for (final pair in paramsStr.split(',')) {
        final eqIdx = pair.indexOf('=');
        if (eqIdx > 0) {
          final key = pair.substring(0, eqIdx).trim();
          final value = pair.substring(eqIdx + 1).trim();
          // 校验 param value 字符集 [C-2]
          if (_paramValuePattern.hasMatch(value)) {
            params[key] = value;
          } else {
            debugPrint('[AssistantTools] 警告：参数值 "$value" 包含非法字符，已忽略');
          }
        }
      }
    }

    commands.add(ToolCommand(name: toolName, params: params));
  }
  return commands;
}

/// 从 AI 回复中移除 ACTION 标记，返回纯文本
String stripActionTags(String response) {
  return response.replaceAll(_actionRegex, '').trim();
}

// ===== 工具注册表（screen → tab index 映射）=====

/// 页面名称到底部导航 index 的映射
const Map<String, int> screenTabIndex = {
  'practice': 0,
  'exam': 1,
  'match': 2,
  'stats': 3,
  'profile': 4,
};
