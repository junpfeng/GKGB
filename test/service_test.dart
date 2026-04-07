import 'package:flutter_test/flutter_test.dart';
import 'package:exam_prep_app/services/llm/llm_manager.dart';
import 'package:exam_prep_app/services/llm/llm_provider.dart';
import 'package:exam_prep_app/services/question_service.dart';
import 'package:exam_prep_app/services/exam_service.dart';

void main() {
  group('LlmManager 测试', () {
    test('初始化时没有默认模型', () {
      final manager = LlmManager();
      expect(manager.hasProvider, isFalse);
      expect(manager.defaultProvider, isNull);
    });

    test('注册 Provider 并设为默认', () {
      final manager = LlmManager();
      expect(manager.availableProviders.length, equals(6)); // 预注册了6个

      manager.setDefault('deepseek');
      expect(manager.hasProvider, isTrue);
      expect(manager.defaultProviderName, equals('deepseek'));
    });

    test('设置 fallback', () {
      final manager = LlmManager();
      manager.setDefault('deepseek');
      manager.setFallback('qwen');
      expect(manager.fallbackProviderName, equals('qwen'));
    });

    test('没有配置模型时 chat 抛出异常', () async {
      final manager = LlmManager();
      expect(
        () async => await manager.chat([const ChatMessage(role: 'user', content: 'test')]),
        throwsA(isA<Exception>()),
      );
    });

    test('applyApiKey 不抛异常', () {
      final manager = LlmManager();
      // 测试设置 API Key 不报错
      expect(() => manager.applyApiKey('deepseek', 'test_key'), returnsNormally);
      expect(() => manager.applyApiKey('openai', 'test_key'), returnsNormally);
      expect(() => manager.applyApiKey('qwen', 'test_key'), returnsNormally);
      expect(() => manager.applyApiKey('claude', 'test_key'), returnsNormally);
    });

    test('applyModelName 不抛异常', () {
      final manager = LlmManager();
      expect(() => manager.applyModelName('deepseek', 'deepseek-chat'), returnsNormally);
      expect(() => manager.applyModelName('ollama', 'llama3'), returnsNormally);
    });
  });

  group('ExamService 基础测试', () {
    test('格式化时间 formatRemainingTime', () {
      final qs = QuestionService();
      final service = ExamService(qs);
      // 初始状态无计时
      expect(service.remainingSeconds, equals(0));
      expect(service.formatRemainingTime(), equals('00:00'));
      expect(service.isRunning, isFalse);
    });

    test('没有考试时 submitExam 抛异常', () async {
      final qs = QuestionService();
      final service = ExamService(qs);
      expect(
        () async => await service.submitExam(),
        throwsA(isA<Exception>()),
      );
    });

    test('cancelExam 清理状态', () {
      final qs = QuestionService();
      final service = ExamService(qs);
      service.cancelExam();
      expect(service.currentExam, isNull);
      expect(service.examQuestions.isEmpty, isTrue);
    });

    test('recordAnswer 更新状态', () {
      final qs = QuestionService();
      final service = ExamService(qs);
      service.recordAnswer(1, 'A');
      // 没有进行中的考试，但不应抛异常
      expect(service.userAnswers.isEmpty, isFalse);
    });
  });

  group('QuestionService 基础测试', () {
    test('初始统计为0', () {
      final service = QuestionService();
      expect(service.totalQuestions, equals(0));
      expect(service.answeredCount, equals(0));
      expect(service.correctCount, equals(0));
      expect(service.accuracy, equals(0.0));
    });

    test('updateStats 更新统计', () {
      final service = QuestionService();
      service.updateStats(total: 100, answered: 80, correct: 60);
      expect(service.totalQuestions, equals(100));
      expect(service.answeredCount, equals(80));
      expect(service.correctCount, equals(60));
      expect(service.accuracy, closeTo(0.75, 0.001));
    });
  });

  group('ChatMessage 测试', () {
    test('toJson 格式正确', () {
      const msg = ChatMessage(role: 'user', content: '你好');
      final json = msg.toJson();
      expect(json['role'], equals('user'));
      expect(json['content'], equals('你好'));
    });

    test('支持 system/user/assistant 角色', () {
      const system = ChatMessage(role: 'system', content: '你是助手');
      const user = ChatMessage(role: 'user', content: '问题');
      const assistant = ChatMessage(role: 'assistant', content: '回答');
      expect(system.role, equals('system'));
      expect(user.role, equals('user'));
      expect(assistant.role, equals('assistant'));
    });
  });
}
