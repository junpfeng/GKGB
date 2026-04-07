import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'llm_provider.dart';

/// Claude (Anthropic) Provider
/// 使用 Anthropic messages API（格式与 OpenAI 不同）
class ClaudeProvider implements LlmProvider {
  @override
  final String name = 'claude';

  @override
  final String displayName = 'Claude';

  static const String _baseUrl = 'https://api.anthropic.com/v1';
  static const String _defaultModel = 'claude-3-5-haiku-20241022';
  static const String _apiVersion = '2023-06-01';

  late final Dio _dio;
  String? _apiKey;
  String? _modelName;

  ClaudeProvider() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': _apiVersion,
        },
      ),
    );
  }

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  void setModelName(String modelName) {
    _modelName = modelName;
  }

  String get _effectiveModel => _modelName ?? _defaultModel;

  Map<String, String> get _authHeader {
    if (_apiKey == null || _apiKey!.isEmpty) return {};
    // Anthropic 使用 x-api-key header，而非 Bearer token
    return {'x-api-key': _apiKey!};
  }

  /// 将 ChatMessage 列表分离出 system prompt 和 messages
  Map<String, dynamic> _buildRequestBody(List<ChatMessage> messages) {
    final systemMessages = messages.where((m) => m.role == 'system').toList();
    final userMessages = messages.where((m) => m.role != 'system').toList();
    final body = <String, dynamic>{
      'model': _effectiveModel,
      'max_tokens': 4096,
      'messages': userMessages.map((m) => m.toJson()).toList(),
    };
    if (systemMessages.isNotEmpty) {
      body['system'] = systemMessages.map((m) => m.content).join('\n');
    }
    return body;
  }

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    final response = await _dio.post(
      '/messages',
      options: Options(headers: _authHeader),
      data: _buildRequestBody(messages),
    );
    final content = (response.data['content'] as List).first;
    return content['text'] as String;
  }

  @override
  Stream<String> streamChat(List<ChatMessage> messages) {
    final controller = StreamController<String>();

    Future(() async {
      try {
        final body = _buildRequestBody(messages)..['stream'] = true;
        final response = await _dio.post<ResponseBody>(
          '/messages',
          options: Options(
            headers: _authHeader,
            responseType: ResponseType.stream,
          ),
          data: body,
        );

        final stream = response.data!.stream;
        final buffer = StringBuffer();

        await for (final chunk in stream) {
          buffer.write(utf8.decode(chunk));
          final lines = buffer.toString().split('\n');
          buffer.clear();
          buffer.write(lines.last);

          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i].trim();
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              try {
                final json = jsonDecode(jsonStr);
                if (json['type'] == 'content_block_delta') {
                  final delta = json['delta']?['text'];
                  if (delta != null && delta is String && delta.isNotEmpty) {
                    controller.add(delta);
                  }
                }
              } catch (_) {
                // 忽略解析失败的 chunk
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
