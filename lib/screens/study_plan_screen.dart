import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exam_category_service.dart';
import '../services/study_plan_service.dart';
import '../models/study_plan.dart';
import '../models/daily_task.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

/// 学习计划总览页
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyPlanService>().loadActivePlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: '调整计划',
            onPressed: () => _showAdjustPlan(context),
          ),
        ],
      ),
      body: Consumer<StudyPlanService>(
        builder: (context, service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!service.hasPlan) {
            if (service.hasPausedPlan) {
              return _PausedPlanView(
                plan: service.pausedPlan!,
                onResume: () async {
                  await service.resumePlan(service.pausedPlan!.id!);
                },
                onGenerate: () => _showGeneratePlanDialog(context),
              );
            }
            return _NoPlanView(
                onGenerate: () => _showGeneratePlanDialog(context));
          }

          return _PlanView(plan: service.activePlan!, service: service);
        },
      ),
    );
  }

  Future<void> _showGeneratePlanDialog(BuildContext context) async {
    final examDateController = TextEditingController();
    final contextController = TextEditingController();
    final allSubjects = context.read<ExamCategoryService>().getSubjectsForPlan();
    final selectedSubjects = allSubjects.toSet();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('生成学习计划'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择科目：', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: allSubjects.map((subject) {
                    final selected = selectedSubjects.contains(subject);
                    return FilterChip(
                      label: Text(subject),
                      selected: selected,
                      onSelected: (v) => setDialogState(() {
                        if (v) {
                          selectedSubjects.add(subject);
                        } else {
                          selectedSubjects.remove(subject);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: examDateController,
                  decoration: const InputDecoration(
                    labelText: '考试日期（可选）',
                    hintText: '如：2025-12-31',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contextController,
                  decoration: const InputDecoration(
                    labelText: '补充信息（可选）',
                    hintText: '如：每天能学习 2 小时',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generatePlan(
                  context,
                  subjects: selectedSubjects.toList(),
                  examDate: examDateController.text.trim().isEmpty
                      ? null
                      : examDateController.text.trim(),
                  userContext: contextController.text.trim().isEmpty
                      ? null
                      : contextController.text.trim(),
                );
              },
              child: const Text('AI 生成'),
            ),
          ],
        ),
      ),
    );

    examDateController.dispose();
    contextController.dispose();
  }

  Future<void> _generatePlan(
    BuildContext context, {
    required List<String> subjects,
    String? examDate,
    String? userContext,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<StudyPlanService>();
    try {
      await service.generatePlan(
        subjects: subjects,
        examDate: examDate,
        userContext: userContext,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('学习计划生成成功')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  Future<void> _showAdjustPlan(BuildContext context) async {
    final service = context.read<StudyPlanService>();
    if (!service.hasPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先生成学习计划')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI 正在分析...'),
          ],
        ),
      ),
    );

    try {
      final advice = await service.adjustPlan();
      if (context.mounted) {
        Navigator.pop(context);
        AiChatDialog.show(
          context,
          initialPrompt: advice,
          title: '计划调整建议',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取建议失败：$e')),
        );
      }
    }
  }
}

class _NoPlanView extends StatelessWidget {
  final VoidCallback onGenerate;
  const _NoPlanView({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 渐变图标
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.route, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有学习计划',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              '让 AI 根据你的情况生成个性化学习路线',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: onGenerate,
              label: 'AI 生成学习计划',
              icon: Icons.smart_toy,
            ),
          ],
        ),
      ),
    );
  }
}

/// 暂停计划视图（计划因切换备考目标被暂停时展示）
class _PausedPlanView extends StatelessWidget {
  final StudyPlan plan;
  final VoidCallback onResume;
  final VoidCallback onGenerate;
  const _PausedPlanView({
    required this.plan,
    required this.onResume,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppTheme.warningGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pause_circle_outline,
                  size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              '学习计划已暂停',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '备考目标切换后，原计划（${plan.subjects.join('、')}）已暂停',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: onResume,
              label: '恢复学习计划',
              icon: Icons.play_arrow,
              gradient: AppTheme.warningGradient,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.smart_toy),
              label: const Text('重新生成计划'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  final StudyPlan plan;
  final StudyPlanService service;

  const _PlanView({required this.plan, required this.service});

  @override
  Widget build(BuildContext context) {
    final milestones = plan.id != null
        ? service.checkMilestones(plan.id!)
        : <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 里程碑提醒横幅（渐变背景）
        if (milestones.isNotEmpty) ...[
          _MilestoneBanner(milestones: milestones, plan: plan),
          const SizedBox(height: 14),
        ],
        // 计划概览卡片
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.route, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '当前学习计划',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DailyTaskScreen(plan: plan)),
                    ),
                    child: const Text('今日任务'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (plan.examDate != null)
                _InfoRow('考试日期', plan.examDate!),
              _InfoRow('备考科目', plan.subjects.join('、')),
              _InfoRow('创建日期', plan.createdAt?.substring(0, 10) ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 操作按钮行
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _autoAdjust(context),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('自动调整'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goToRelatedPractice(context),
                icon: const Icon(Icons.error_outline, size: 16),
                label: const Text('错题推荐'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // AI 生成的计划内容
        if (plan.planData != null && plan.planData!.isNotEmpty) ...[
          Text(
            '计划详情',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              plan.planData!,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // 今日任务预览
        Text(
          '今日任务',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (service.todayTasks.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: const Text('今日无任务', style: TextStyle(color: Colors.grey)),
          )
        else
          ...service.todayTasks
              .take(3)
              .map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskCard(task: task, service: service),
                  )),
        if (service.todayTasks.length > 3)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DailyTaskScreen(plan: plan)),
            ),
            child: Text('查看全部 ${service.todayTasks.length} 个任务'),
          ),
        const SizedBox(height: 16),
        // 重新生成按钮
        OutlinedButton.icon(
          onPressed: () => _showRegeneratePlan(context),
          icon: const Icon(Icons.refresh),
          label: const Text('重新生成计划'),
        ),
      ],
    );
  }

  Future<void> _autoAdjust(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (plan.id == null) {
      messenger.showSnackBar(const SnackBar(content: Text('计划尚未保存')));
      return;
    }
    try {
      final result = await service.autoAdjust(plan.id!);
      messenger.showSnackBar(
        SnackBar(content: Text(result), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('自动调整失败：$e')));
    }
  }

  void _goToRelatedPractice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请切换到"刷题"页面查看错题本')),
    );
  }

  Future<void> _showRegeneratePlan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重新生成'),
        content: const Text('将废弃当前计划，重新生成。确认吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<StudyPlanService>().generatePlan(
          subjects: plan.subjects,
          examDate: plan.examDate,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('计划已更新')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('生成失败：$e')));
        }
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DailyTask task;
  final StudyPlanService service;

  const _TaskCard({required this.task, required this.service});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'completed';

    return AccentCard(
      accentGradient: isCompleted
          ? AppTheme.successGradient
          : AppTheme.primaryGradient,
      accentWidth: 4,
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: (v) => service.updateTaskStatus(
              task.id!,
              v! ? 'completed' : 'pending',
            ),
            activeColor: const Color(0xFF667eea),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.subject} · ${task.topic ?? task.taskType ?? "练习"}',
                  style: TextStyle(
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (task.targetCount > 0)
                  Text(
                    '目标：${task.targetCount} 题',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          _StatusBadge(status: task.status),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, gradient) = switch (status) {
      'completed' => ('完成', AppTheme.successGradient),
      'ongoing' => ('进行中', AppTheme.infoGradient),
      'skipped' => ('跳过', const LinearGradient(colors: [Colors.grey, Colors.grey])),
      _ => ('待完成', AppTheme.warningGradient),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }
}

/// 里程碑提醒横幅（渐变背景）
class _MilestoneBanner extends StatelessWidget {
  final List<String> milestones;
  final StudyPlan plan;

  const _MilestoneBanner({required this.milestones, required this.plan});

  @override
  Widget build(BuildContext context) {
    // 根据距考试天数判断紧急度渐变
    LinearGradient bannerGradient = const LinearGradient(
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    );
    IconData icon = Icons.event_note;

    if (plan.examDate != null) {
      final examDate = DateTime.tryParse(plan.examDate!);
      if (examDate != null) {
        final daysLeft = examDate.difference(DateTime.now()).inDays;
        if (daysLeft <= 7) {
          bannerGradient = AppTheme.warmGradient;
          icon = Icons.alarm;
        } else if (daysLeft <= 30) {
          bannerGradient = AppTheme.warningGradient;
          icon = Icons.schedule;
        }
      }
    }

    return GradientCard(
      gradient: bannerGradient,
      borderRadius: AppTheme.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              milestones.join(' '),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// 每日任务详情页
class DailyTaskScreen extends StatelessWidget {
  final StudyPlan plan;
  const DailyTaskScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      appBar: AppBar(title: Text('今日任务 · $today')),
      body: Consumer<StudyPlanService>(
        builder: (context, service, _) {
          if (service.todayTasks.isEmpty) {
            return const Center(child: Text('今日无任务'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: service.todayTasks.length,
            itemBuilder: (context, index) {
              final task = service.todayTasks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TaskCard(task: task, service: service),
              );
            },
          );
        },
      ),
    );
  }
}
