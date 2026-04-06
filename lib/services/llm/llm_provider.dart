/// LLM 统一抽象接口
/// 所有大模型实现此接口，通过 LlmManager 统一调用
abstract class LlmProvider {
  String get name;
  String get displayName;

  /// 单次对话
  Future<String> chat(List<ChatMessage> messages);

  /// 流式对话
  Stream<String> streamChat(List<ChatMessage> messages);

  /// 测试连接
  Future<bool> testConnection();
}

class ChatMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}
