import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'llm_provider.dart';

/// Ollama 本地模型 Provider
/// 调用本地 Ollama REST API（/api/chat）
class OllamaProvider implements LlmProvider {
  @override
  final String name = 'ollama';

  @override
  final String displayName = 'Ollama（本地）';

  static const String _defaultBaseUrl = 'http://localhost:11434';
  static const String _defaultModel = 'llama3';

  late Dio _dio;
  String _baseUrl;
  String? _modelName;

  OllamaProvider({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// 更新 baseUrl（用户在设置页修改后调用）
  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _initDio();
  }

  void setModelName(String modelName) {
    _modelName = modelName;
  }

  String get _effectiveModel => _modelName ?? _defaultModel;

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    final response = await _dio.post(
      '/api/chat',
      data: {
        'model': _effectiveModel,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': false,
      },
    );
    return response.data['message']['content'] as String;
  }

  @override
  Stream<String> streamChat(List<ChatMessage> messages) {
    final controller = StreamController<String>();

    Future(() async {
      try {
        final response = await _dio.post<ResponseBody>(
          '/api/chat',
          options: Options(responseType: ResponseType.stream),
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
          buffer.clear();
          buffer.write(lines.last);

          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            try {
              final json = jsonDecode(line);
              final content = json['message']?['content'];
              if (content != null && content is String && content.isNotEmpty) {
                controller.add(content);
              }
              if (json['done'] == true) break;
            } catch (_) {
              // 忽略解析失败
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
      // 检查 Ollama 服务是否运行
      final response = await _dio.get('/api/tags');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
