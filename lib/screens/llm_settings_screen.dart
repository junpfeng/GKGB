import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/llm_config_service.dart';
import '../services/llm/llm_manager.dart';
import '../models/llm_config.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

/// LLM 模型设置页
class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  final LlmConfigService _configService = LlmConfigService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _configService.loadAndApply(context.read<LlmManager>());
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型设置')),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _configService,
              builder: (ctx, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // 使用说明卡片（信息渐变）
                    GradientCard(
                      gradient: AppTheme.infoGradient,
                      borderRadius: AppTheme.radiusMedium,
                      padding: const EdgeInsets.all(14),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '使用说明',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'API Key 加密存储于本设备，不会上传。\n'
                                  '建议至少配置一个模型，设为默认后即可使用 AI 功能。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '支持的模型',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _ProviderCard(
                      providerName: 'deepseek',
                      displayName: 'DeepSeek',
                      description: '性价比高，推荐首选',
                      icon: Icons.star,
                      brandGradient: AppTheme.infoGradient,
                      configService: _configService,
                      configs: _configService.configs,
                    ),
                    const SizedBox(height: 8),
                    _ProviderCard(
                      providerName: 'qwen',
                      displayName: '通义千问',
                      description: '阿里云，国内访问稳定',
                      icon: Icons.cloud,
                      brandGradient: AppTheme.warningGradient,
                      configService: _configService,
                      configs: _configService.configs,
                    ),
                    const SizedBox(height: 8),
                    _ProviderCard(
                      providerName: 'claude',
                      displayName: 'Claude (Anthropic)',
                      description: '理解能力强，适合复杂分析',
                      icon: Icons.psychology,
                      brandGradient: AppTheme.primaryGradient,
                      configService: _configService,
                      configs: _configService.configs,
                    ),
                    const SizedBox(height: 8),
                    _ProviderCard(
                      providerName: 'zhipu',
                      displayName: '智谱 GLM',
                      description: 'GLM-4-Flash 免费，国内访问快',
                      icon: Icons.auto_awesome,
                      brandGradient: const LinearGradient(
                        colors: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
                      ),
                      configService: _configService,
                      configs: _configService.configs,
                    ),
                    const SizedBox(height: 8),
                    _ProviderCard(
                      providerName: 'openai',
                      displayName: 'OpenAI GPT',
                      description: 'GPT 系列，需要国际网络',
                      icon: Icons.smart_toy,
                      brandGradient: AppTheme.successGradient,
                      configService: _configService,
                      configs: _configService.configs,
                    ),
                    const SizedBox(height: 8),
                    _ProviderCard(
                      providerName: 'ollama',
                      displayName: 'Ollama（本地）',
                      description: '本地模型，无需 API Key，离线可用',
                      icon: Icons.computer,
                      brandGradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
                      ),
                      configService: _configService,
                      configs: _configService.configs,
                      isLocal: true,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String providerName;
  final String displayName;
  final String description;
  final IconData icon;
  final LinearGradient brandGradient;
  final LlmConfigService configService;
  final List<LlmConfig> configs;
  final bool isLocal;

  const _ProviderCard({
    required this.providerName,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.brandGradient,
    required this.configService,
    required this.configs,
    this.isLocal = false,
  });

  LlmConfig? get _config =>
      configs.where((c) => c.providerName == providerName).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final isConfigured = config != null;
    final isDefault = config?.isDefault == true;
    final isFallback = config?.isFallback == true;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 6),
            if (isDefault)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '默认',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            if (isFallback) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppTheme.warningGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '备选',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isConfigured ? '已配置' : description,
          style: TextStyle(
            fontSize: 12,
            color: isConfigured ? const Color(0xFF43E97B) : Colors.grey[500],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConfigured)
              const Icon(Icons.check_circle,
                  color: Color(0xFF43E97B), size: 16),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          _ProviderConfigForm(
            providerName: providerName,
            displayName: displayName,
            config: config,
            configService: configService,
            isLocal: isLocal,
          ),
        ],
      ),
    );
  }
}

class _ProviderConfigForm extends StatefulWidget {
  final String providerName;
  final String displayName;
  final LlmConfig? config;
  final LlmConfigService configService;
  final bool isLocal;

  const _ProviderConfigForm({
    required this.providerName,
    required this.displayName,
    this.config,
    required this.configService,
    required this.isLocal,
  });

  @override
  State<_ProviderConfigForm> createState() => _ProviderConfigFormState();
}

class _ProviderConfigFormState extends State<_ProviderConfigForm> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  bool _isDefault = false;
  bool _isFallback = false;
  bool _testing = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = widget.config;
    if (config != null) {
      setState(() {
        _modelNameController.text = config.modelName ?? '';
        _baseUrlController.text = config.baseUrl ?? '';
        _isDefault = config.isDefault;
        _isFallback = config.isFallback;
      });
      final apiKey = await widget.configService.getApiKey(widget.providerName);
      if (mounted && apiKey != null) {
        _apiKeyController.text = apiKey;
      }
    }
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final modelName = _modelNameController.text.trim();
    final isDefault = _isDefault;
    final isFallback = _isFallback;
    final manager = context.read<LlmManager>();

    try {
      await widget.configService.saveConfig(
        providerName: widget.providerName,
        apiKey: apiKey.isEmpty ? null : apiKey,
        baseUrl: baseUrl.isEmpty ? null : baseUrl,
        modelName: modelName.isEmpty ? null : modelName,
        isDefault: isDefault,
        isFallback: isFallback,
      );

      if (apiKey.isNotEmpty) manager.applyApiKey(widget.providerName, apiKey);
      if (modelName.isNotEmpty) {
        manager.applyModelName(widget.providerName, modelName);
      }
      if (baseUrl.isNotEmpty) {
        manager.applyBaseUrl(widget.providerName, baseUrl);
      }
      if (isDefault) manager.setDefault(widget.providerName);
      if (isFallback) manager.setFallback(widget.providerName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final manager = context.read<LlmManager>();
      final apiKey = _apiKeyController.text.trim();
      final baseUrl = _baseUrlController.text.trim();
      if (apiKey.isNotEmpty) {
        manager.applyApiKey(widget.providerName, apiKey);
      }
      if (baseUrl.isNotEmpty) {
        manager.applyBaseUrl(widget.providerName, baseUrl);
      }
      final provider = manager.availableProviders
          .where((p) => p.name == widget.providerName)
          .firstOrNull;

      if (provider == null) throw Exception('Provider 未找到');
      final success = await provider.testConnection();
      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? '连接成功！' : '连接失败，请检查 API Key'),
          backgroundColor: success ? const Color(0xFF43E97B) : Colors.red,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('连接测试失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isLocal) ...[
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '输入你的 ${widget.displayName} API Key',
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 自定义 API 地址（可选，用于硅基流动等第三方平台）
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'API 地址（可选，留空使用官方）',
                hintText: _getDefaultBaseUrlHint(),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Ollama 地址',
                hintText: 'http://localhost:11434',
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _modelNameController,
            decoration: InputDecoration(
              labelText: '模型名称（可选，留空使用默认）',
              hintText: _getDefaultModelHint(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() {
                    _isDefault = v!;
                    if (v) _isFallback = false;
                  }),
                  title: const Text('设为默认', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  value: _isFallback,
                  onChanged: (v) => setState(() {
                    _isFallback = v!;
                    if (v) _isDefault = false;
                  }),
                  title: const Text('设为备选', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  onPressed: _save,
                  label: '保存配置',
                  width: double.infinity,
                  borderRadius: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDefaultModelHint() {
    return switch (widget.providerName) {
      'deepseek' => 'deepseek-chat',
      'openai' => 'gpt-4o-mini',
      'qwen' => 'qwen-plus',
      'claude' => 'claude-3-5-haiku-20241022',
      'zhipu' => 'glm-4-flash',
      'ollama' => 'llama3',
      _ => '',
    };
  }

  String _getDefaultBaseUrlHint() {
    return switch (widget.providerName) {
      'deepseek' => 'https://api.deepseek.com/v1',
      'openai' => 'https://api.openai.com/v1',
      'qwen' => 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'claude' => 'https://api.anthropic.com/v1',
      'zhipu' => 'https://open.bigmodel.cn/api/paas/v4',
      _ => '',
    };
  }
}
