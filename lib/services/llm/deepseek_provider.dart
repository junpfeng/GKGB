import 'openai_compatible_provider.dart';

/// DeepSeek 大模型 Provider（OpenAI 兼容格式）
class DeepSeekProvider extends OpenAiCompatibleProvider {
  @override
  final String name = 'deepseek';

  @override
  final String displayName = 'DeepSeek';

  @override
  final String baseUrl = 'https://api.deepseek.com/v1';

  @override
  final String defaultModel = 'deepseek-chat';
}
