import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'llm_provider.dart';

/// OpenAI 兼容格式 Provider 基类
/// DeepSeek、OpenAI、通义千问（DashScope兼容模式）均继承此类
abstract class OpenAiCompatibleProvider implements LlmProvider {
  late Dio _dio;

  String get baseUrl;
  String get defaultModel;

  String? _apiKey;
  String? _modelName;

  OpenAiCompatibleProvider() {
    _initDio(baseUrl);
  }

  void _initDio(String url) {
    _dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    // 仅添加脱敏日志拦截器，不打印 Authorization header
    _dio.interceptors.add(_SanitizedLogInterceptor());
  }

  /// 设置 API Key（由 LlmConfigService 注入）
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// 设置模型名（可覆盖 defaultModel）
  void setModelName(String modelName) {
    _modelName = modelName;
  }

  /// 设置自定义 baseUrl（用于第三方兼容平台，如硅基流动）
  void setBaseUrl(String url) {
    _initDio(url);
  }

  String get _effectiveModel => _modelName ?? defaultModel;

  /// 当前生效的 API Key（供 CrawlerCore 等需要直调 API 的场景读取）
  String? get currentApiKey => _apiKey;

  /// 当前生效的模型名
  String get currentModel => _effectiveModel;

  /// 当前生效的 baseUrl
  String get currentBaseUrl => _dio.options.baseUrl;

  Map<String, String> get _authHeader {
    if (_apiKey == null || _apiKey!.isEmpty) return {};
    return {'Authorization': 'Bearer $_apiKey'};
  }

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    final response = await _dio.post(
      '/chat/completions',
      options: Options(headers: _authHeader),
      data: {
        'model': _effectiveModel,
        'messages': messages.map((m) => m.toJson()).toList(),
      },
    );
    final data = response.data;
    return (data['choices'] as List).first['message']['content'] as String;
  }

  @override
  Stream<String> streamChat(List<ChatMessage> messages) {
    final controller = StreamController<String>();

    Future(() async {
      try {
        final response = await _dio.post<ResponseBody>(
          '/chat/completions',
          options: Options(
            headers: _authHeader,
            responseType: ResponseType.stream,
          ),
          data: {
            'model': _effectiveModel,
            'messages': messages.map((m) => m.toJson()).toList(),
            'stream': true,
          },
        );

        final stream = response.data!.stream;
        final buffer = StringBuffer();

        await for (final chunk in stream) {
          buffer.write(utf8.decode(chunk));
          final lines = buffer.toString().split('\n');
          // 保留最后一行（可能不完整）
          buffer.clear();
          buffer.write(lines.last);

          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i].trim();
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr == '[DONE]') continue;
              try {
                final json = jsonDecode(jsonStr);
                final delta = json['choices']?[0]?['delta']?['content'];
                if (delta != null && delta is String && delta.isNotEmpty) {
                  controller.add(delta);
                }
              } catch (_) {
                // 解析失败的 chunk 忽略
              }
            }
          }
        }
        controller.close();
      } catch (e) {
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  @override
  Future<bool> testConnection() async {
    try {
      await chat([const ChatMessage(role: 'user', content: 'ping')]);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 脱敏日志拦截器：不打印 Authorization header
class _SanitizedLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 不记录包含 Authorization 的请求头，避免 API Key 泄露
    handler.next(options);
  }
}
