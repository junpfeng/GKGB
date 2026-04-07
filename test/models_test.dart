import 'package:flutter_test/flutter_test.dart';
import 'package:exam_prep_app/models/question.dart';
import 'package:exam_prep_app/models/exam.dart';
import 'package:exam_prep_app/models/user_answer.dart';
import 'package:exam_prep_app/models/user_profile.dart';
import 'package:exam_prep_app/models/match_result.dart';
import 'package:exam_prep_app/models/study_plan.dart';
import 'package:exam_prep_app/models/daily_task.dart';
import 'package:exam_prep_app/models/llm_config.dart';

void main() {
  group('Question 模型序列化测试', () {
    test('fromDb 和 toDb 互转', () {
      final map = {
        'id': 1,
        'subject': '行测',
        'category': '言语理解',
        'type': 'single',
        'content': '测试题目内容',
        'options': '["A. 选项A","B. 选项B","C. 选项C","D. 选项D"]',
        'answer': 'A',
        'explanation': '解析内容',
        'difficulty': 2,
        'created_at': '2024-01-01',
      };
      final q = Question.fromDb(map);
      expect(q.id, equals(1));
      expect(q.subject, equals('行测'));
      expect(q.options.length, equals(4));
      expect(q.options[0], equals('A. 选项A'));
      expect(q.answer, equals('A'));

      final db = q.toDb();
      expect(db['subject'], equals('行测'));
      expect(db['options'], contains('选项A'));
    });

    test('fromJson 和 toJson 互转', () {
      const q = Question(
        subject: '申论',
        category: '申论',
        type: 'subjective',
        content: '主观题内容',
        answer: '参考答案',
        difficulty: 3,
      );
      final json = q.toJson();
      final q2 = Question.fromJson(json);
      expect(q2.subject, equals(q.subject));
      expect(q2.type, equals(q.type));
      expect(q2.difficulty, equals(q.difficulty));
    });
  });

  group('Exam 模型测试', () {
    test('fromDb 和 copyWith', () {
      final map = {
        'id': 10,
        'subject': '行测',
        'total_questions': 30,
        'score': 85.5,
        'time_limit': 3600,
        'started_at': '2024-01-01T10:00:00',
        'finished_at': '2024-01-01T11:00:00',
        'status': 'finished',
      };
      final exam = Exam.fromDb(map);
      expect(exam.id, equals(10));
      expect(exam.score, equals(85.5));
      expect(exam.status, equals('finished'));

      final updated = exam.copyWith(score: 90.0);
      expect(updated.score, equals(90.0));
      expect(updated.id, equals(10));
    });
  });

  group('UserAnswer 模型测试', () {
    test('fromDb bool 转换', () {
      final map = {
        'id': 1,
        'question_id': 5,
        'exam_id': null,
        'user_answer': 'A',
        'is_correct': 1,
        'time_spent': 30,
        'answered_at': '2024-01-01',
      };
      final answer = UserAnswer.fromDb(map);
      expect(answer.isCorrect, isTrue);
      expect(answer.examId, isNull);
      expect(answer.timeSpent, equals(30));
    });

    test('toDb 转换', () {
      const answer = UserAnswer(
        questionId: 1,
        examId: 2,
        userAnswer: 'B',
        isCorrect: false,
        timeSpent: 60,
      );
      final db = answer.toDb();
      expect(db['is_correct'], equals(0));
      expect(db['exam_id'], equals(2));
    });
  });

  group('UserProfile 模型测试', () {
    test('fromDb 列表解析', () {
      final map = {
        'id': 1,
        'education': '硕士',
        'major': '计算机科学',
        'is_985': 1,
        'is_211': 0,
        'work_years': 3,
        'has_grassroots_exp': 0,
        'certificates': '["法律职业资格","CPA"]',
        'target_cities': '["北京","上海"]',
      };
      final profile = UserProfile.fromDb(map);
      expect(profile.education, equals('硕士'));
      expect(profile.is985, isTrue);
      expect(profile.is211, isFalse);
      expect(profile.certificates.length, equals(2));
      expect(profile.targetCities.contains('北京'), isTrue);
    });

    test('toDb 列表序列化', () {
      const profile = UserProfile(
        education: '本科',
        certificates: ['教师资格证'],
        targetCities: ['广州', '深圳'],
      );
      final db = profile.toDb();
      expect(db['education'], equals('本科'));
      expect(db['certificates'], contains('教师资格证'));
      expect(db['target_cities'], contains('广州'));
    });
  });

  group('MatchResult 模型测试', () {
    test('fromDb 列表解析', () {
      final map = {
        'id': 1,
        'position_id': 5,
        'match_score': 85,
        'matched_items': '["学历达标","专业对口"]',
        'risk_items': '["年龄接近上限"]',
        'unmatched_items': '[]',
        'advice': '建议报考',
        'is_target': 1,
      };
      final result = MatchResult.fromDb(map);
      expect(result.matchScore, equals(85));
      expect(result.matchedItems.length, equals(2));
      expect(result.riskItems.length, equals(1));
      expect(result.isTarget, isTrue);
    });
  });

  group('StudyPlan 模型测试', () {
    test('fromDb Map解析', () {
      final map = {
        'id': 1,
        'subjects': '["行测","申论"]',
        'baseline_scores': '{"行测":60.0,"申论":55.0}',
        'plan_data': 'AI生成的计划内容',
        'status': 'active',
      };
      final plan = StudyPlan.fromDb(map);
      expect(plan.subjects.length, equals(2));
      expect(plan.baselineScores['行测'], equals(60.0));
      expect(plan.status, equals('active'));
    });
  });

  group('DailyTask 模型测试', () {
    test('copyWith 测试', () {
      const task = DailyTask(
        taskDate: '2024-01-01',
        subject: '行测',
        targetCount: 20,
        status: 'pending',
      );
      final updated = task.copyWith(status: 'completed', completedCount: 20);
      expect(updated.status, equals('completed'));
      expect(updated.completedCount, equals(20));
      expect(updated.subject, equals('行测'));
    });
  });

  group('LlmConfig 模型测试', () {
    test('secureStorageKey 格式', () {
      const config = LlmConfig(providerName: 'deepseek');
      expect(config.secureStorageKey, equals('llm_key_deepseek'));
    });

    test('fromDb 和 toDb', () {
      final map = {
        'id': 1,
        'provider_name': 'claude',
        'base_url': null,
        'model_name': 'claude-3-5-haiku-20241022',
        'is_default': 1,
        'is_fallback': 0,
      };
      final config = LlmConfig.fromDb(map);
      expect(config.isDefault, isTrue);
      expect(config.isFallback, isFalse);
      expect(config.modelName, equals('claude-3-5-haiku-20241022'));
    });
  });
}
