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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows / Linux 平台初始化 sqflite FFI
  if (Platform.isWindows || Platform.isLinux) {
    initSqfliteForWindows();
  }

  await DatabaseHelper.instance.database;

  // 启动时加载 LLM 配置并注入到 LlmManager
  final llmManager = LlmManager();
  final configService = LlmConfigService();
  await configService.loadAndApply(llmManager);

  runApp(
    MultiProvider(
      providers: [
        // 1. QuestionService（无依赖）
        ChangeNotifierProvider(create: (_) => QuestionService()),
        // 2. ProfileService（无依赖）
        ChangeNotifierProvider(create: (_) => ProfileService()),
        // 3. LlmManager（启动时已加载配置）
        ChangeNotifierProvider.value(value: llmManager),
        // 4. ExamService（依赖 QuestionService）
        ChangeNotifierProxyProvider<QuestionService, ExamService>(
          create: (ctx) => ExamService(ctx.read<QuestionService>()),
          update: (ctx, qs, prev) => prev ?? ExamService(qs),
        ),
        // 5. MatchService（依赖 ProfileService, LlmManager）
        ChangeNotifierProxyProvider2<ProfileService, LlmManager, MatchService>(
          create: (ctx) => MatchService(ctx.read<ProfileService>(), ctx.read<LlmManager>()),
          update: (ctx, ps, lm, prev) => prev ?? MatchService(ps, lm),
        ),
        // 6. StudyPlanService（依赖 QuestionService, LlmManager）
        ChangeNotifierProxyProvider2<QuestionService, LlmManager, StudyPlanService>(
          create: (ctx) => StudyPlanService(ctx.read<QuestionService>(), ctx.read<LlmManager>()),
          update: (ctx, qs, lm, prev) => prev ?? StudyPlanService(qs, lm),
        ),
        // 7. BaselineService（依赖 QuestionService）
        ChangeNotifierProxyProvider<QuestionService, BaselineService>(
          create: (ctx) => BaselineService(ctx.read<QuestionService>()),
          update: (ctx, qs, prev) => prev ?? BaselineService(qs),
        ),
        // 8. RealExamService（依赖 QuestionService, LlmManager）
        ChangeNotifierProxyProvider2<QuestionService, LlmManager, RealExamService>(
          create: (ctx) => RealExamService(ctx.read<QuestionService>(), ctx.read<LlmManager>()),
          update: (ctx, qs, lm, prev) => prev ?? RealExamService(qs, lm),
        ),
        // 9. VoiceService（无依赖）
        ChangeNotifierProvider(create: (_) => VoiceService()),
        // 10. AssistantService（依赖全部 service，ctx.read 一次性注入）
        ChangeNotifierProvider(
          create: (ctx) => AssistantService(
            llm: ctx.read<LlmManager>(),
            questionService: ctx.read<QuestionService>(),
            examService: ctx.read<ExamService>(),
            matchService: ctx.read<MatchService>(),
            studyPlanService: ctx.read<StudyPlanService>(),
            profileService: ctx.read<ProfileService>(),
            baselineService: ctx.read<BaselineService>(),
          ),
        ),
      ],
      child: const ExamPrepApp(),
    ),
  );
}
