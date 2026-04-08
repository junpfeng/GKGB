import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'db/database_helper.dart';
import 'services/question_service.dart';
import 'services/exam_service.dart';
import 'services/profile_service.dart';
import 'services/match_service.dart';
import 'services/study_plan_service.dart';
import 'services/baseline_service.dart';
import 'services/llm/llm_manager.dart';
import 'services/llm_config_service.dart';
import 'services/assistant_service.dart';
import 'services/voice_service.dart';
import 'services/real_exam_service.dart';
import 'services/interview_service.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/wrong_analysis_service.dart';
import 'services/hot_topic_service.dart';
import 'services/essay_service.dart';
import 'services/dashboard_service.dart';
import 'services/adaptive_quiz_service.dart';
import 'services/exam_category_service.dart';
import 'services/idiom_service.dart';
import 'services/exam_entry_score_service.dart';
import 'services/political_theory_service.dart';
import 'services/visual_explanation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows / Linux 平台初始化 sqflite FFI
  if (Platform.isWindows || Platform.isLinux) {
    initSqfliteForWindows();
  }

  await DatabaseHelper.instance.database;

  // 初始化通知服务
  await NotificationService.instance.init();

  // 导入预置考试数据
  final calendarService = CalendarService();
  await calendarService.importPresetData();
  await calendarService.loadAll();

  // 启动时加载 LLM 配置并注入到 LlmManager
  final llmManager = LlmManager();
  final configService = LlmConfigService();
  await configService.loadAndApply(llmManager);

  // 加载用户备考目标
  final examCategoryService = ExamCategoryService();
  await examCategoryService.loadTargets();

  // 导入预置时政热点和申论素材
  final hotTopicService = HotTopicService(llmManager);
  await hotTopicService.importPresetTopics();
  await hotTopicService.importPresetMaterials();

  // 导入预置成语数据
  final idiomService = IdiomService();
  await idiomService.importPresetIdioms();

  // 导入预置政治理论数据
  final politicalTheoryService = PoliticalTheoryService(llmManager);
  await politicalTheoryService.importPresetData();

  // 导入预置可视化解题数据
  final visualExplanationService = VisualExplanationService(llmManager);
  await visualExplanationService.importPresetData();

  runApp(
    MultiProvider(
      providers: [
        // 0. ExamCategoryService（启动时已加载目标）
        ChangeNotifierProvider.value(value: examCategoryService),
        // 1. CalendarService（启动时已加载数据）
        ChangeNotifierProvider.value(value: calendarService),
        // 2. QuestionService（无依赖）
        ChangeNotifierProvider(create: (_) => QuestionService()),
        // 3. ProfileService（无依赖）
        ChangeNotifierProvider(create: (_) => ProfileService()),
        // 4. LlmManager（启动时已加载配置）
        ChangeNotifierProvider.value(value: llmManager),
        // 5. ExamService（依赖 QuestionService）
        ChangeNotifierProxyProvider<QuestionService, ExamService>(
          create: (ctx) => ExamService(ctx.read<QuestionService>()),
          update: (ctx, qs, prev) => prev ?? ExamService(qs),
        ),
        // 6. MatchService（依赖 ProfileService, LlmManager）
        ChangeNotifierProxyProvider2<ProfileService, LlmManager, MatchService>(
          create: (ctx) => MatchService(ctx.read<ProfileService>(), ctx.read<LlmManager>()),
          update: (ctx, ps, lm, prev) => prev ?? MatchService(ps, lm),
        ),
        // 7. StudyPlanService（依赖 QuestionService, LlmManager, ExamCategoryService）
        ChangeNotifierProxyProvider3<QuestionService, LlmManager, ExamCategoryService, StudyPlanService>(
          create: (ctx) => StudyPlanService(ctx.read<QuestionService>(), ctx.read<LlmManager>(), ctx.read<ExamCategoryService>()),
          update: (ctx, qs, lm, ecs, prev) => prev ?? StudyPlanService(qs, lm, ecs),
        ),
        // 8. BaselineService（依赖 QuestionService）
        ChangeNotifierProxyProvider<QuestionService, BaselineService>(
          create: (ctx) => BaselineService(ctx.read<QuestionService>()),
          update: (ctx, qs, prev) => prev ?? BaselineService(qs),
        ),
        // 9. RealExamService（依赖 QuestionService, LlmManager）
        ChangeNotifierProxyProvider2<QuestionService, LlmManager, RealExamService>(
          create: (ctx) => RealExamService(ctx.read<QuestionService>(), ctx.read<LlmManager>()),
          update: (ctx, qs, lm, prev) => prev ?? RealExamService(qs, lm),
        ),
        // 10. InterviewService（依赖 LlmManager, ExamCategoryService）
        ChangeNotifierProxyProvider2<LlmManager, ExamCategoryService, InterviewService>(
          create: (ctx) => InterviewService(ctx.read<LlmManager>(), ctx.read<ExamCategoryService>()),
          update: (ctx, lm, ecs, prev) => prev ?? InterviewService(lm, ecs),
        ),
        // 11. WrongAnalysisService（依赖 LlmManager）
        ChangeNotifierProxyProvider<LlmManager, WrongAnalysisService>(
          create: (ctx) => WrongAnalysisService(ctx.read<LlmManager>()),
          update: (ctx, lm, prev) => prev ?? WrongAnalysisService(lm),
        ),
        // 12. HotTopicService（启动时已导入预置数据）
        ChangeNotifierProvider.value(value: hotTopicService),
        // 13. EssayService（依赖 LlmManager）
        ChangeNotifierProxyProvider<LlmManager, EssayService>(
          create: (ctx) => EssayService(ctx.read<LlmManager>()),
          update: (ctx, lm, prev) => prev ?? EssayService(lm),
        ),
        // 14. VoiceService（无依赖）
        ChangeNotifierProvider(create: (_) => VoiceService()),
        // 15. DashboardService（依赖 QuestionService, ExamService, LlmManager, ExamCategoryService）
        ChangeNotifierProxyProvider3<QuestionService, ExamService, LlmManager, DashboardService>(
          create: (ctx) => DashboardService(
            ctx.read<QuestionService>(),
            ctx.read<ExamService>(),
            ctx.read<LlmManager>(),
            ctx.read<ExamCategoryService>(),
          ),
          update: (ctx, qs, es, lm, prev) =>
              prev ?? DashboardService(qs, es, lm, ctx.read<ExamCategoryService>()),
        ),
        // 16. AdaptiveQuizService（依赖 LlmManager）
        ChangeNotifierProxyProvider<LlmManager, AdaptiveQuizService>(
          create: (ctx) => AdaptiveQuizService(ctx.read<LlmManager>()),
          update: (ctx, lm, prev) => prev ?? AdaptiveQuizService(lm),
        ),
        // 17. AssistantService（依赖全部 service，ctx.read 一次性注入）
        ChangeNotifierProvider(
          create: (ctx) => AssistantService(
            llm: ctx.read<LlmManager>(),
            questionService: ctx.read<QuestionService>(),
            examService: ctx.read<ExamService>(),
            matchService: ctx.read<MatchService>(),
            studyPlanService: ctx.read<StudyPlanService>(),
            profileService: ctx.read<ProfileService>(),
            baselineService: ctx.read<BaselineService>(),
            examCategoryService: ctx.read<ExamCategoryService>(),
          ),
        ),
        // 18. IdiomService（启动时已导入预置数据）
        ChangeNotifierProvider.value(value: idiomService),
        // 19. ExamEntryScoreService（无依赖）
        ChangeNotifierProvider(create: (_) => ExamEntryScoreService()),
        // 20. PoliticalTheoryService（启动时已导入预置数据）
        ChangeNotifierProvider.value(value: politicalTheoryService),
        // 21. VisualExplanationService（启动时已导入预置数据）
        ChangeNotifierProvider.value(value: visualExplanationService),
      ],
      child: const ExamPrepApp(),
    ),
  );
}
