import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../db/database_helper.dart';
import '../models/llm_config.dart';
import 'llm/llm_manager.dart';

/// LLM 配置服务
/// API Key 存储于 flutter_secure_storage，其余配置存 SQLite
class LlmConfigService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  // Windows 使用 DPAPI，Android 使用 Keystore
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  List<LlmConfig> _configs = [];
  List<LlmConfig> get configs => List.unmodifiable(_configs);

  LlmConfig? get defaultConfig => _configs.where((c) => c.isDefault).firstOrNull;
  LlmConfig? get fallbackConfig => _configs.where((c) => c.isFallback).firstOrNull;

  /// 加载配置并注入到 LlmManager
  Future<void> loadAndApply(LlmManager manager) async {
    final rows = await _db.queryLlmConfigs();
    _configs = rows.map((r) => LlmConfig.fromDb(r)).toList();

    for (final config in _configs) {
      // 从安全存储读取 API Key
      final apiKey = await _storage.read(key: config.secureStorageKey);
      if (apiKey != null && apiKey.isNotEmpty) {
        manager.applyApiKey(config.providerName, apiKey);
      }

      // 应用模型名
      if (config.modelName != null && config.modelName!.isNotEmpty) {
        manager.applyModelName(config.providerName, config.modelName!);
      }

      // 应用 Ollama baseUrl
      if (config.providerName == 'ollama' && config.baseUrl != null && config.baseUrl!.isNotEmpty) {
        manager.applyOllamaBaseUrl(config.baseUrl!);
      }

      if (config.isDefault) {
        manager.setDefault(config.providerName);
      }
      if (config.isFallback) {
        manager.setFallback(config.providerName);
      }
    }

    notifyListeners();
  }

  /// 保存或更新配置
  Future<void> saveConfig({
    required String providerName,
    String? apiKey,
    String? baseUrl,
    String? modelName,
    bool isDefault = false,
    bool isFallback = false,
  }) async {
    // 写入 API Key 到安全存储
    if (apiKey != null && apiKey.isNotEmpty) {
      final storageKey = 'llm_key_$providerName';
      await _storage.write(key: storageKey, value: apiKey);
    }

    // 清除旧的默认/备选标记
    if (isDefault) await _db.clearDefaultLlmConfig();
    if (isFallback) await _db.clearFallbackLlmConfig();

    // 查找已有配置
    final existing = _configs.where((c) => c.providerName == providerName).firstOrNull;
    final config = LlmConfig(
      id: existing?.id,
      providerName: providerName,
      baseUrl: baseUrl,
      modelName: modelName,
      isDefault: isDefault,
      isFallback: isFallback,
    );

    if (existing == null) {
      await _db.insertLlmConfig(config.toDb());
    } else {
      await _db.updateLlmConfig(existing.id!, config.toDb());
    }

    // 重新加载
    final rows = await _db.queryLlmConfigs();
    _configs = rows.map((r) => LlmConfig.fromDb(r)).toList();
    notifyListeners();
  }

  /// 删除配置
  Future<void> deleteConfig(int id) async {
    final config = _configs.where((c) => c.id == id).firstOrNull;
    if (config != null) {
      await _storage.delete(key: config.secureStorageKey);
      await _db.deleteLlmConfig(id);
    }
    _configs.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// 读取指定 Provider 的 API Key
  Future<String?> getApiKey(String providerName) async {
    return await _storage.read(key: 'llm_key_$providerName');
  }
}
