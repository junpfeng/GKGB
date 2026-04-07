import 'openai_compatible_provider.dart';

/// 通义千问 Provider（DashScope OpenAI 兼容模式）
class QwenProvider extends OpenAiCompatibleProvider {
  @override
  final String name = 'qwen';

  @override
  final String displayName = '通义千问';

  @override
  final String baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';

  @override
  final String defaultModel = 'qwen-plus';
}
