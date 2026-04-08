import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exam_category_service.dart';
import '../screens/profile_screen.dart';

/// 全局考试类型指示器（24-32px 高彩色条，显示在 HomeScreen 顶部）
class ExamTypeBadge extends StatelessWidget {
  const ExamTypeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExamCategoryService>(
      builder: (context, service, _) {
        if (!service.hasTarget && !service.isExploreMode) {
          return const SizedBox.shrink();
        }

        final isExplore = service.isExploreMode;
        final displayText = service.targetDisplayText;

        return Container(
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isExplore
                  ? [const Color(0xFFF7971E), const Color(0xFFFFD200)]
                  : [const Color(0xFF667eea), const Color(0xFF764ba2)],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      isExplore ? Icons.explore : Icons.flag,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExplore ? '设置备考目标 →' : displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '更改',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
