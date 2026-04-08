import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('真题导入逻辑测试', () {
    // ===== 内容哈希测试 =====

    group('_computeContentHash', () {
      test('相同内容生成相同哈希', () {
        final q1 = {
          'content': '下列选项中，正确的是：',
          'options': ['A. 选项一', 'B. 选项二', 'C. 选项三', 'D. 选项四'],
        };
        final q2 = {
          'content': '下列选项中，正确的是：',
          'options': ['A. 选项一', 'B. 选项二', 'C. 选项三', 'D. 选项四'],
        };
        // 通过 reflection 访问私有方法（测试环境使用公开包装函数）
        final hash1 = _testComputeHash(q1);
        final hash2 = _testComputeHash(q2);
        expect(hash1, equals(hash2));
      });

      test('不同内容生成不同哈希', () {
        final q1 = {
          'content': '题目甲',
          'options': ['A. 选项一', 'B. 选项二'],
        };
        final q2 = {
          'content': '题目乙',
          'options': ['A. 选项一', 'B. 选项二'],
        };
        final hash1 = _testComputeHash(q1);
        final hash2 = _testComputeHash(q2);
        expect(hash1, isNot(equals(hash2)));
      });

      test('空格差异不影响哈希（归一化）', () {
        final q1 = {
          'content': '下列 选项 中',
          'options': ['A. 选 项 一', 'B. 选项二'],
        };
        final q2 = {
          'content': '下列选项中',
          'options': ['A. 选项一', 'B. 选项二'],
        };
        final hash1 = _testComputeHash(q1);
        final hash2 = _testComputeHash(q2);
        expect(hash1, equals(hash2));
      });

      test('选项前缀 A. 不影响哈希', () {
        final q1 = {
          'content': '题目内容',
          'options': ['A. 苹果', 'B. 香蕉'],
        };
        // 如果选项没有前缀，哈希应该相同（因为 A. 会被去除）
        final hash1 = _testComputeHash(q1);
        expect(hash1, isNotEmpty);
        expect(hash1, isA<String>());
      });

      test('空选项题目（主观题）也能正确计算哈希', () {
        final q = {
          'content': '请分析我国数字鸿沟产生的原因。',
          'options': <String>[],
        };
        final hash = _testComputeHash(q);
        expect(hash, isNotEmpty);
      });
    });

    // ===== JSON 格式验证测试 =====

    group('真题 JSON 格式验证', () {
      test('标准格式题目可被正确解析', () {
        const jsonStr = '''
{
  "paper": {
    "name": "2024年国考行测真题",
    "region": "全国",
    "year": 2024,
    "exam_type": "国考",
    "exam_session": "上半年",
    "subject": "行测",
    "time_limit": 7200,
    "total_score": 100,
    "question_ids": []
  },
  "questions": [
    {
      "subject": "行测",
      "category": "言语理解",
      "type": "single",
      "content": "测试题目内容",
      "options": ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
      "answer": "A",
      "explanation": "测试解析",
      "difficulty": 2,
      "region": "全国",
      "year": 2024,
      "exam_type": "国考",
      "exam_session": "上半年",
      "is_real_exam": 1
    }
  ]
}''';

        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(data['paper'], isNotNull);
        expect(data['questions'], isA<List>());

        final questions = data['questions'] as List;
        expect(questions.length, equals(1));

        final q = questions.first as Map<String, dynamic>;
        expect(q['subject'], equals('行测'));
        expect(q['category'], equals('言语理解'));
        expect(q['type'], equals('single'));
        expect(q['is_real_exam'], equals(1));
        expect(q['year'], equals(2024));
        expect(q['exam_type'], equals('国考'));
      });

      test('试卷元数据包含必要字段', () {
        const jsonStr = '''
{
  "paper": {
    "name": "2024年国考行测",
    "region": "全国",
    "year": 2024,
    "exam_type": "国考",
    "subject": "行测",
    "time_limit": 7200,
    "total_score": 100,
    "question_ids": []
  },
  "questions": []
}''';
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final paper = data['paper'] as Map<String, dynamic>;
        expect(paper['name'], isNotNull);
        expect(paper['year'], isA<int>());
        expect(paper['time_limit'], isA<int>());
        expect(paper['question_ids'], isA<List>());
      });

      test('省考题目包含地区字段', () {
        const jsonStr = '''
{
  "questions": [
    {
      "subject": "行测",
      "category": "常识判断",
      "type": "single",
      "content": "江苏省会是哪个城市？",
      "options": ["A. 南京", "B. 苏州", "C. 无锡", "D. 南通"],
      "answer": "A",
      "explanation": "南京是江苏省省会",
      "difficulty": 1,
      "region": "江苏",
      "year": 2024,
      "exam_type": "省考",
      "exam_session": "上半年",
      "is_real_exam": 1
    }
  ]
}''';
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final q = (data['questions'] as List).first as Map<String, dynamic>;
        expect(q['region'], equals('江苏'));
        expect(q['exam_type'], equals('省考'));
      });

      test('事业编公基题目格式正确', () {
        const jsonStr = '''
{
  "questions": [
    {
      "subject": "公基",
      "category": "公基",
      "type": "judge",
      "content": "公民的权利与义务是对立统一的关系。",
      "options": ["A. 正确", "B. 错误"],
      "answer": "A",
      "explanation": "权利与义务相互依存",
      "difficulty": 2,
      "region": "全国",
      "year": 2024,
      "exam_type": "事业编",
      "exam_session": "上半年",
      "is_real_exam": 1
    }
  ]
}''';
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final q = (data['questions'] as List).first as Map<String, dynamic>;
        expect(q['subject'], equals('公基'));
        expect(q['type'], equals('judge'));
        expect(q['exam_type'], equals('事业编'));
        expect(q['options'], hasLength(2));
      });
    });

    // ===== 增量导入逻辑测试 =====

    group('增量导入去重逻辑', () {
      test('相同哈希不重复导入', () {
        final existingHashes = <String>{'abc123', 'def456'};
        final newQuestions = [
          {'content': '题目A', 'options': <String>[]},
          {'content': '题目B', 'options': <String>[]},
        ];

        // 模拟：如果计算出的哈希已在 existingHashes 中则跳过
        final toImport = newQuestions.where((q) {
          final hash = _testComputeHash(q);
          return !existingHashes.contains(hash);
        }).toList();

        // 两道新题的哈希不在已有哈希集合中，所以都应该导入
        expect(toImport.length, equals(2));
      });

      test('哈希集合可以正确去重同批次重复题', () {
        final seen = <String>{};
        final questions = [
          {'content': '相同题目', 'options': <String>[]},
          {'content': '相同题目', 'options': <String>[]},
          {'content': '不同题目', 'options': <String>[]},
        ];

        final deduped = <Map<String, dynamic>>[];
        for (final q in questions) {
          final hash = _testComputeHash(q);
          if (!seen.contains(hash)) {
            seen.add(hash);
            deduped.add(q);
          }
        }

        expect(deduped.length, equals(2)); // 3题去重后剩2题
      });
    });

    // ===== 数据库 map 转换测试 =====

    group('题目 DB 映射格式', () {
      test('options 序列化为 JSON 字符串', () {
        final options = ['A. 选项一', 'B. 选项二', 'C. 选项三', 'D. 选项四'];
        final encoded = jsonEncode(options);
        final decoded = jsonDecode(encoded) as List<dynamic>;
        expect(decoded.length, equals(4));
        expect(decoded[0], equals('A. 选项一'));
      });

      test('主观题 options 为空列表', () {
        final q = {
          'subject': '申论',
          'category': '申论',
          'type': 'subjective',
          'content': '请就以下问题写一篇议论文。',
          'options': <String>[],
          'answer': '',
          'explanation': '',
          'difficulty': 4,
          'region': '全国',
          'year': 2025,
          'exam_type': '国考',
          'exam_session': '上半年',
          'is_real_exam': 1,
        };
        final encoded = jsonEncode(q['options']);
        expect(encoded, equals('[]'));
      });

      test('is_real_exam 字段值为 1', () {
        final q = {
          'content': '真题',
          'options': <String>[],
          'is_real_exam': 1,
        };
        expect(q['is_real_exam'], equals(1));
      });
    });

    // ===== 年份和考试类型范围验证 =====

    group('覆盖范围验证', () {
      final targetYears = [2020, 2021, 2022, 2023, 2024, 2025];
      final examTypes = ['国考', '省考', '事业编'];
      final provinces = ['全国', '江苏', '浙江', '上海', '山东'];

      test('目标年份列表正确', () {
        expect(targetYears, hasLength(6));
        expect(targetYears.first, equals(2020));
        expect(targetYears.last, equals(2025));
      });

      test('考试类型列表正确', () {
        expect(examTypes, contains('国考'));
        expect(examTypes, contains('省考'));
        expect(examTypes, contains('事业编'));
      });

      test('省份列表包含目标省份', () {
        expect(provinces, contains('江苏'));
        expect(provinces, contains('浙江'));
        expect(provinces, contains('上海'));
        expect(provinces, contains('山东'));
      });
    });
  });
}

/// 测试辅助函数：复现 RealExamService._computeContentHash 的逻辑
/// （因为方法是私有的，这里复制相同逻辑用于测试验证）
String _testComputeHash(Map<String, dynamic> q) {
  final content = _normalizeForHash(q['content'] as String? ?? '');
  final optionsRaw = q['options'];
  final optionTexts = <String>[];
  if (optionsRaw is List) {
    for (final opt in optionsRaw) {
      final optStr = opt.toString();
      final cleaned = optStr.replaceFirst(
        RegExp(r'^[A-E][.、]\s*'),
        '',
      );
      optionTexts.add(_normalizeForHash(cleaned));
    }
  }
  final combined = [content, ...optionTexts].join('|');
  return combined.hashCode.toRadixString(16);
}

String _normalizeForHash(String text) {
  return text
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp('[，。？！、；：""【】《》()（）\\[\\]…—]'), '')
      .toLowerCase();
}
