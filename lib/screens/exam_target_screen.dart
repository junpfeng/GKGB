import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_category.dart';
import '../models/exam_category_registry.dart';
import '../models/user_exam_target.dart';
import '../services/exam_category_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';

/// 考试目标选择引导页（首次启动或未设置目标时显示）
class ExamTargetScreen extends StatefulWidget {
  const ExamTargetScreen({super.key});

  @override
  State<ExamTargetScreen> createState() => _ExamTargetScreenState();
}

class _ExamTargetScreenState extends State<ExamTargetScreen> {
  String? _selectedId; // 当前选中的类型 ID（null=未选择, '__explore__'=探索模式）

  // 考试类型图标映射
  static const _categoryIcons = {
    'guokao': Icons.account_balance,
    'shengkao': Icons.location_city,
    'shiyebian': Icons.business,
    'xuandiao': Icons.school,
    'sanzhiyifu': Icons.volunteer_activism,
    'rencaiyinjin': Icons.stars,
  };

  // 考试类型渐变色映射
  static const _categoryGradients = {
    'guokao': [Color(0xFF667eea), Color(0xFF764ba2)],
    'shengkao': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    'shiyebian': [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    'xuandiao': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    'sanzhiyifu': [Color(0xFFF7971E), Color(0xFFFFD200)],
    'rencaiyinjin': [Color(0xFFf093fb), Color(0xFFf5576c)],
  };

  @override
  Widget build(BuildContext context) {
    final categories = ExamCategoryRegistry.allCategories;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: canPop
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('更改备考目标'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, canPop ? 16 : 40, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                canPop ? '选择新的备考目标' : '选择你的备考目标',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '我们将为你定制专属学习方案',
                style: TextStyle(fontSize: 15, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              // 卡片网格
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: categories.length + 1, // +1 探索模式
                  itemBuilder: (context, index) {
                    if (index < categories.length) {
                      return _buildCategoryCard(context, categories[index]);
                    }
                    return _buildExploreCard(context);
                  },
                ),
              ),
              // 底部提示
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '随时可在「我的」中更改备考目标',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
              ),
              // 老用户升级提示
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    '选择备考目标后，你的历史学习记录将全部保留',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, ExamCategory category) {
    final isComingSoon = category.contentStatus == ContentStatus.comingSoon;
    final icon = _categoryIcons[category.id] ?? Icons.quiz;
    final colors = _categoryGradients[category.id] ??
        [const Color(0xFF667eea), const Color(0xFF764ba2)];
    final isSelected = _selectedId == category.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.first,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Opacity(
        opacity: isComingSoon ? 0.5 : 1.0,
        child: GlassCard(
          onTap: isComingSoon
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('题库建设中，敬请期待')),
                  )
              : () => _selectCategory(context, category),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      category.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (category.contentStatus == ContentStatus.partial)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '部分题库',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  if (isComingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '即将上线',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
              // 选中勾选标记
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreCard(BuildContext context) {
    final isSelected = _selectedId == '__explore__';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF6B6B),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: GlassCard(
        onTap: () => _enterExploreMode(context),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.warmGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.explore, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  '先看看再说',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    '浏览全部功能，稍后再设置目标',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.warmGradient,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategory(
      BuildContext context, ExamCategory category) async {
    setState(() => _selectedId = category.id);

    final service = context.read<ExamCategoryService>();
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    final target = UserExamTarget(
      examCategoryId: category.id,
      isPrimary: 1,
    );
    await service.setTarget(target);

    // 从「我的」页面进入时，选中后自动返回
    if (mounted && canPop) {
      navigator.pop();
    }
  }

  Future<void> _enterExploreMode(BuildContext context) async {
    setState(() => _selectedId = '__explore__');

    final service = context.read<ExamCategoryService>();
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    await service.enterExploreMode();

    if (mounted && canPop) {
      navigator.pop();
    }
  }
}
