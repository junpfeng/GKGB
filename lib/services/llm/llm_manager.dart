import 'dart:async';
import 'package:flutter/foundation.dart';
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';
import 'deepseek_provider.dart';
import 'openai_provider.dart';
import 'qwen_provider.dart';
import 'claude_provider.dart';
import 'ollama_provider.dart';
import 'zhipu_provider.dart';

/// LLM 管理器：模型切换、fallback、统一调用入口
/// 继承 ChangeNotifier，Provider 状态自动通知 UI
class LlmManager extends ChangeNotifier {
  final Map<String, LlmProvider> _providers = {};
  String? _defaultProviderName;
  String? _fallbackProviderName;

  /// 所有支持的 Provider 实例（预创建）
  final DeepSeekProvider deepseek = DeepSeekProvider();
  final OpenAiProvider openai = OpenAiProvider();
  final QwenProvider qwen = QwenProvider();
  final ClaudeProvider claude = ClaudeProvider();
  final OllamaProvider ollama = OllamaProvider();
  final ZhipuProvider zhipu = ZhipuProvider();

  LlmManager() {
    // 预注册所有 Provider
    _providers[deepseek.name] = deepseek;
    _providers[openai.name] = openai;
    _providers[qwen.name] = qwen;
    _providers[claude.name] = claude;
    _providers[ollama.name] = ollama;
    _providers[zhipu.name] = zhipu;
  }

  void registerProvider(LlmProvider provider) {
    _providers[provider.name] = provider;
    notifyListeners();
  }

  void setDefault(String name) {
    _defaultProviderName = name;
    notifyListeners();
  }

  void setFallback(String name) {
    _fallbackProviderName = name;
    notifyListeners();
  }

  LlmProvider? get defaultProvider =>
      _defaultProviderName != null ? _providers[_defaultProviderName] : null;

  String? get defaultProviderName => _defaultProviderName;
  String? get fallbackProviderName => _fallbackProviderName;

  List<LlmProvider> get availableProviders => _providers.values.toList();

  bool get hasProvider => defaultProvider != null;

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

  /// 流式对话入口，带 fallback 逻辑
  Stream<String> streamChat(List<ChatMessage> messages) {
    final controller = StreamController<String>();

    Future(() async {
      final primary = defaultProvider;
      if (primary == null) {
        controller.addError(Exception('未配置任何 LLM 模型，请在设置中添加'));
        controller.close();
        return;
      }

      bool primarySentData = false;
      try {
        await for (final chunk in primary.streamChat(messages)) {
          primarySentData = true;
          controller.add(chunk);
        }
      } catch (e) {
        // 主模型已发送部分数据后失败，不能混入 fallback 输出（会导致文本拼接混乱）
        if (primarySentData || _fallbackProviderName == null) {
          controller.addError(e);
        } else {
          // 主模型尚未发送任何数据，安全降级到 fallback
          final fallback = _providers[_fallbackProviderName];
          if (fallback != null) {
            try {
              await for (final chunk in fallback.streamChat(messages)) {
                controller.add(chunk);
              }
            } catch (fallbackErr) {
              controller.addError(fallbackErr);
            }
          } else {
            controller.addError(e);
          }
        }
      }

      controller.close();
    });

    return controller.stream;
  }

  /// 根据配置设置 API Key（由 LlmConfigService 调用）
  void applyApiKey(String providerName, String apiKey) {
    final provider = _providers[providerName];
    if (provider is OpenAiCompatibleProvider) {
      provider.setApiKey(apiKey);
    }
    notifyListeners();
  }

  /// 根据配置设置模型名
  void applyModelName(String providerName, String modelName) {
    final provider = _providers[providerName];
    if (provider is OpenAiCompatibleProvider) {
      provider.setModelName(modelName);
    } else if (provider is OllamaProvider) {
      provider.setModelName(modelName);
    }
    notifyListeners();
  }

  /// 设置自定义 baseUrl（支持所有 OpenAI 兼容 Provider 和 Ollama）
  void applyBaseUrl(String providerName, String baseUrl) {
    final provider = _providers[providerName];
    if (provider is OpenAiCompatibleProvider) {
      provider.setBaseUrl(baseUrl);
    } else if (provider is OllamaProvider) {
      provider.setBaseUrl(baseUrl);
    }
    notifyListeners();
  }
}
