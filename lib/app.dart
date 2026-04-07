import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/ai_assistant/ai_assistant_overlay.dart';

/// 应用入口 Widget，配置全局主题
class ExamPrepApp extends StatelessWidget {
  const ExamPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '考公考编智能助手',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
      // 注入全局 AI 助手 Overlay [H-5]
      builder: (context, child) => Stack(
        children: [
          child!,
          const AiAssistantOverlay(),
        ],
      ),
    );
  }
}
