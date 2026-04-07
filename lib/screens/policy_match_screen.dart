import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/match_service.dart';
import '../services/profile_service.dart';
import '../models/talent_policy.dart';
import '../models/match_result.dart';
import '../widgets/match_reason_card.dart';
import '../widgets/ai_chat_dialog.dart';

/// 岗位匹配页：公告管理、匹配结果
class PolicyMatchScreen extends StatefulWidget {
  const PolicyMatchScreen({super.key});

  @override
  State<PolicyMatchScreen> createState() => _PolicyMatchScreenState();
}

class _PolicyMatchScreenState extends State<PolicyMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchService>().loadPolicies();
      context.read<MatchService>().loadMatchResults();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('岗位匹配'),
        actions: [
          Consumer<MatchService>(
            builder: (ctx, service, _) => IconButton(
              icon: service.isMatching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              tooltip: '开始匹配',
              onPressed: service.isMatching ? null : () => _runMatching(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '公告管理'),
            Tab(text: '匹配结果'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PolicyListTab(),
          _MatchResultTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPolicyDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加公告'),
      ),
    );
  }

  Future<void> _runMatching(BuildContext context) async {
    final profile = context.read<ProfileService>().profile;
    if (profile == null || profile.education == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完善个人信息')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final matchService = context.read<MatchService>();
    try {
      await matchService.runMatching();
      if (mounted) {
        _tabController.animateTo(1);
        messenger.showSnackBar(
          const SnackBar(content: Text('匹配完成')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('匹配失败：$e')),
      );
    }
  }

  Future<void> _showAddPolicyDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final provinceController = TextEditingController();
    final cityController = TextEditingController();
    final contentController = TextEditingController();
    final deadlineController = TextEditingController();
    String? policyType;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加公告'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '公告标题 *'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: provinceController,
                        decoration: const InputDecoration(labelText: '省份'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: '城市'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: policyType,
                  decoration: const InputDecoration(labelText: '公告类型'),
                  items: const [
                    DropdownMenuItem(value: '人才引进', child: Text('人才引进')),
                    DropdownMenuItem(value: '事业编招聘', child: Text('事业编招聘')),
                    DropdownMenuItem(value: '高校招聘', child: Text('高校招聘')),
                    DropdownMenuItem(value: '国企招聘', child: Text('国企招聘')),
                    DropdownMenuItem(value: '选调生', child: Text('选调生')),
                  ],
                  onChanged: (v) => setDialogState(() => policyType = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: deadlineController,
                  decoration: const InputDecoration(
                    labelText: '报名截止日期',
                    hintText: '如：2025-06-30',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: '公告内容（粘贴原文，AI 可解析）'),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await context.read<MatchService>().addPolicy(
                    title: titleController.text.trim(),
                    province: provinceController.text.trim().isEmpty
                        ? null
                        : provinceController.text.trim(),
                    city: cityController.text.trim().isEmpty
                        ? null
                        : cityController.text.trim(),
                    policyType: policyType,
                    content: contentController.text.trim().isEmpty
                        ? null
                        : contentController.text.trim(),
                    deadline: deadlineController.text.trim().isEmpty
                        ? null
                        : deadlineController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('添加成功')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('添加失败：$e')),
                    );
                  }
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    provinceController.dispose();
    cityController.dispose();
    contentController.dispose();
    deadlineController.dispose();
  }
}

/// 公告列表 Tab
class _PolicyListTab extends StatelessWidget {
  const _PolicyListTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (service.policies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无公告，点击右下角添加', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: service.policies.length,
          itemBuilder: (context, index) {
            final policy = service.policies[index];
            return _PolicyCard(policy: policy);
          },
        );
      },
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final TalentPolicy policy;
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(policy.title, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              [
                if (policy.city != null) policy.city,
                if (policy.policyType != null) policy.policyType,
                if (policy.deadline != null) '截止：${policy.deadline}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('删除')),
                if (policy.content != null && policy.content!.isNotEmpty)
                  const PopupMenuItem(value: 'ai_parse', child: Text('AI 解析岗位')),
              ],
              onSelected: (value) async {
                if (value == 'delete') {
                  await context.read<MatchService>().deletePolicy(policy.id!);
                } else if (value == 'ai_parse') {
                  await _aiParsePolicy(context, policy);
                }
              },
            ),
          ),
          if (policy.content != null && policy.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _aiParsePolicy(context, policy),
                    icon: const Icon(Icons.smart_toy, size: 14),
                    label: const Text('AI 解析岗位', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _aiParsePolicy(BuildContext context, TalentPolicy policy) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI 正在解析公告...'),
          ],
        ),
      ),
    );

    try {
      final positions = await context.read<MatchService>().aiParsePolicy(policy);
      if (context.mounted) {
        Navigator.pop(context); // 关闭 loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功解析 ${positions.length} 个岗位')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭 loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 解析失败：$e')),
        );
      }
    }
  }
}

/// 匹配结果 Tab
class _MatchResultTab extends StatelessWidget {
  const _MatchResultTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchService>(
      builder: (context, service, _) {
        if (service.isMatching) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在匹配中，请稍候...'),
              ],
            ),
          );
        }
        if (service.matchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.work_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无匹配结果', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('请先添加公告，然后点击右上角搜索开始匹配',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    // 跳转到个人信息页
                  },
                  child: const Text('完善个人信息'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: service.matchResults.length,
          itemBuilder: (context, index) {
            final result = service.matchResults[index];
            return MatchReasonCard(
              result: result,
              onSetTarget: () => service.toggleTarget(result.id!),
              onViewDetail: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PositionDetailScreen(result: result),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 岗位详情页
class PositionDetailScreen extends StatelessWidget {
  final MatchResult result;
  const PositionDetailScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(result.positionName ?? '岗位详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiChatDialog.show(
              context,
              initialPrompt: '请详细分析我报考"${result.positionName}"岗位的可能性，'
                  '匹配分数为${result.matchScore}分，'
                  '符合项：${result.matchedItems.join("、")}，'
                  '风险项：${result.riskItems.join("、")}，'
                  '不符项：${result.unmatchedItems.join("、")}。'
                  '请给出专业建议。',
              title: 'AI 岗位分析',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MatchReasonCard(
              result: result,
              onSetTarget: () => context.read<MatchService>().toggleTarget(result.id!),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => AiChatDialog.show(
                context,
                initialPrompt: '请分析"${result.positionName}"岗位的报考建议',
                title: 'AI 报考分析',
              ),
              icon: const Icon(Icons.smart_toy),
              label: const Text('AI 深度分析'),
            ),
          ],
        ),
      ),
    );
  }
}
