import 'llm_provider.dart';

/// LLM 管理器：模型切换、fallback、统一入口
class LlmManager {
  final Map<String, LlmProvider> _providers = {};
  String? _defaultProviderName;
  String? _fallbackProviderName;

  void registerProvider(LlmProvider provider) {
    _providers[provider.name] = provider;
  }

  void setDefault(String name) {
    _defaultProviderName = name;
  }

  void setFallback(String name) {
    _fallbackProviderName = name;
  }

  LlmProvider? get defaultProvider =>
      _defaultProviderName != null ? _providers[_defaultProviderName] : null;

  List<LlmProvider> get availableProviders => _providers.values.toList();

  /// 统一对话入口，主模型失败自动降级到备选模型
  Future<String> chat(List<ChatMessage> messages) async {
    final primary = defaultProvider;
    if (primary != null) {
      try {
        return await primary.chat(messages);
      } catch (e) {
        // 主模型失败，尝试 fallback
        if (_fallbackProviderName != null) {
          final fallback = _providers[_fallbackProviderName];
          if (fallback != null) {
            return await fallback.chat(messages);
          }
        }
        rethrow;
      }
    }
    throw Exception('未配置任何 LLM 模型，请在设置中添加');
  }

  /// 流式对话入口
  Stream<String> streamChat(List<ChatMessage> messages) {
    final primary = defaultProvider;
    if (primary != null) {
      return primary.streamChat(messages);
    }
    throw Exception('未配置任何 LLM 模型，请在设置中添加');
  }
}
