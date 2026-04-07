import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音服务：STT/TTS 封装，平台兼容
/// VoiceService.initialize() 检测实际可用性 [H-4]
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isAvailable = false;    // 平台是否支持 STT
  bool _ttsAvailable = false;   // 平台是否支持 TTS
  bool _initialized = false;
  String _recognizedText = '';
  String? _errorMessage;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  /// STT 是否可用（权限+平台双重检查）[H-4]
  bool get isAvailable => _isAvailable;
  bool get ttsAvailable => _ttsAvailable;
  String get recognizedText => _recognizedText;
  String? get errorMessage => _errorMessage;

  /// 初始化语音服务，检测实际可用性 [H-4]
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 检测 STT 可用性
    try {
      _isAvailable = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: _onSttError,
      );
    } catch (e) {
      debugPrint('[VoiceService] STT 初始化失败：$e');
      _isAvailable = false;
    }

    // 检测 TTS 可用性
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[VoiceService] TTS 错误：$msg');
        notifyListeners();
      });

      _ttsAvailable = true;
    } catch (e) {
      debugPrint('[VoiceService] TTS 初始化失败：$e');
      _ttsAvailable = false;
    }

    notifyListeners();
  }

  void _onSttStatus(String status) {
    debugPrint('[VoiceService] STT 状态：$status');
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      notifyListeners();
    }
  }

  void _onSttError(dynamic error) {
    debugPrint('[VoiceService] STT 错误：$error');
    _isListening = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  /// 开始语音识别
  Future<void> startListening({Function(String)? onResult}) async {
    if (!_isAvailable || _isListening) return;

    _recognizedText = '';
    _errorMessage = null;
    _isListening = true;
    notifyListeners();

    try {
      await _stt.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
          if (result.finalResult && onResult != null) {
            onResult(_recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_CN',
      );
    } catch (e) {
      debugPrint('[VoiceService] startListening 失败：$e');
      _isListening = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
    notifyListeners();
  }

  /// TTS 播放文本
  Future<void> speak(String text) async {
    if (!_ttsAvailable || text.isEmpty) return;
    if (_isSpeaking) {
      await stopSpeaking();
    }
    await _tts.speak(text);
  }

  /// 停止 TTS 播放
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}
