import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:exam_prep_app/app.dart';
import 'package:provider/provider.dart';
import 'package:exam_prep_app/services/question_service.dart';
import 'package:exam_prep_app/services/profile_service.dart';
import 'package:exam_prep_app/services/exam_service.dart';
import 'package:exam_prep_app/services/match_service.dart';
import 'package:exam_prep_app/services/study_plan_service.dart';
import 'package:exam_prep_app/services/baseline_service.dart';
import 'package:exam_prep_app/services/llm/llm_manager.dart';
import 'package:exam_prep_app/services/assistant_service.dart';
import 'package:exam_prep_app/services/voice_service.dart';

void main() {
  setUpAll(() {
    // 测试环境使用 FFI 初始化 sqflite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App renders home screen with navigation tabs', (WidgetTester tester) async {
    final questionService = QuestionService();
    final profileService = ProfileService();
    final llmManager = LlmManager();
    final examService = ExamService(questionService);
    final matchService = MatchService(profileService, llmManager);
    final studyPlanService = StudyPlanService(questionService, llmManager);
    final baselineService = BaselineService(questionService);
    final voiceService = VoiceService();
    final assistantService = AssistantService(
      llm: llmManager,
      questionService: questionService,
      examService: examService,
      matchService: matchService,
      studyPlanService: studyPlanService,
      profileService: profileService,
      baselineService: baselineService,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: questionService),
          ChangeNotifierProvider.value(value: profileService),
          ChangeNotifierProvider.value(value: llmManager),
          ChangeNotifierProvider.value(value: examService),
          ChangeNotifierProvider.value(value: matchService),
          ChangeNotifierProvider.value(value: studyPlanService),
          ChangeNotifierProvider.value(value: baselineService),
          ChangeNotifierProvider.value(value: voiceService),
          ChangeNotifierProvider.value(value: assistantService),
        ],
        child: const ExamPrepApp(),
      ),
    );

    // 验证底部导航栏标签存在
    expect(find.text('刷题'), findsOneWidget);
    expect(find.text('模考'), findsOneWidget);
    expect(find.text('岗位'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
