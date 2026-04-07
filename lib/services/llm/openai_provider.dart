import 'openai_compatible_provider.dart';

/// OpenAI GPT Provider（OpenAI 兼容格式）
class OpenAiProvider extends OpenAiCompatibleProvider {
  @override
  final String name = 'openai';

  @override
  final String displayName = 'OpenAI';

  @override
  final String baseUrl = 'https://api.openai.com/v1';

  @override
  final String defaultModel = 'gpt-4o-mini';
}
