import 'openai_compatible_provider.dart';

/// 智谱 GLM 大模型 Provider（OpenAI 兼容格式）
/// 免费模型：glm-4-flash
class ZhipuProvider extends OpenAiCompatibleProvider {
  @override
  final String name = 'zhipu';

  @override
  final String displayName = '智谱 GLM';

  @override
  final String baseUrl = 'https://open.bigmodel.cn/api/paas/v4';

  @override
  final String defaultModel = 'glm-4-flash';
}
