import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          // 智能获取公告菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_link),
            tooltip: '智能获取公告',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('智能搜索')),
              PopupMenuItem(value: 'url', child: Text('URL 导入')),
              PopupMenuItem(value: 'paste', child: Text('粘贴导入')),
            ],
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _showOnlineSearchDialog(context);
                case 'url':
                  _showUrlImportDialog(context);
                case 'paste':
                  _showPasteImportDialog(context);
              }
            },
          ),
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

  /// 智能搜索对话框
  Future<void> _showOnlineSearchDialog(BuildContext context) async {
    final profile = context.read<ProfileService>().profile;
    final defaultCities = profile?.targetCities ?? [];
    await showDialog(
      context: context,
      builder: (_) => _OnlineSearchDialog(defaultCities: defaultCities),
    );
  }

  /// URL 导入对话框
  Future<void> _showUrlImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _UrlImportDialog(),
    );
  }

  /// 粘贴导入对话框
  Future<void> _showPasteImportDialog(BuildContext context) async {
    String clipText = '';
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      clipText = clipData?.text ?? '';
    } catch (_) {}

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _PasteImportDialog(initialText: clipText),
    );
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

// ===== 智能获取公告对话框（独立 StatefulWidget）=====

/// 智能搜索公告对话框
class _OnlineSearchDialog extends StatefulWidget {
  final List<String> defaultCities;
  const _OnlineSearchDialog({required this.defaultCities});

  @override
  State<_OnlineSearchDialog> createState() => _OnlineSearchDialogState();
}

class _OnlineSearchDialogState extends State<_OnlineSearchDialog> {
  late final TextEditingController _citiesController;
  bool _searching = false;
  List<TalentPolicy> _results = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _citiesController =
        TextEditingController(text: widget.defaultCities.join('，'));
  }

  @override
  void dispose() {
    _citiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('智能搜索公告'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _citiesController,
              decoration: const InputDecoration(
                labelText: '目标城市（逗号分隔）',
                hintText: '如：北京，上海，广州',
              ),
            ),
            const SizedBox(height: 12),
            if (_searching) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('AI 正在搜索...'),
                ],
              ),
            ] else if (_results.isNotEmpty) ...[
              Text('找到 ${_results.length} 条公告，勾选入库：',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return CheckboxListTile(
                      value: _selected.contains(i),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      }),
                      title: Text(p.title,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        [
                          if (p.city != null) p.city!,
                          if (p.policyType != null) p.policyType!,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        if (_results.isEmpty && !_searching)
          FilledButton(
            onPressed: _doSearch,
            child: const Text('搜索'),
          )
        else if (_results.isNotEmpty)
          FilledButton(
            onPressed: _doImport,
            child: Text('入库（${_selected.length}条）'),
          ),
      ],
    );
  }

  Future<void> _doSearch() async {
    final cities = _citiesController.text
        .split(RegExp(r'[，,]'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cities.isEmpty) return;

    setState(() => _searching = true);
    try {
      final found =
          await context.read<MatchService>().searchPoliciesOnline(cities);
      setState(() {
        _searching = false;
        _results = found;
      });
    } catch (e) {
      setState(() => _searching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败：$e')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    Navigator.pop(context);
    int count = 0;
    for (final i in _selected) {
      if (i < _results.length) {
        await context.read<MatchService>().addPolicy(
              title: _results[i].title,
              province: _results[i].province,
              city: _results[i].city,
              policyType: _results[i].policyType,
              deadline: _results[i].deadline,
            );
        count++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已入库 $count 条公告')),
      );
    }
  }
}

/// URL 导入公告对话框
class _UrlImportDialog extends StatefulWidget {
  const _UrlImportDialog();

  @override
  State<_UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<_UrlImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _loading = false;
  TalentPolicy? _preview;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('URL 导入公告'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '公告链接',
              hintText: 'https://...',
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text('正在抓取解析...'),
              ],
            ),
          ] else if (_preview != null) ...[
            const SizedBox(height: 12),
            _PreviewCard(policy: _preview!),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        if (_preview == null && !_loading)
          FilledButton(
            onPressed: _doParse,
            child: const Text('解析'),
          )
        else if (_preview != null)
          FilledButton(
            onPressed: _doImport,
            child: const Text('确认入库'),
          ),
      ],
    );
  }

  Future<void> _doParse() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) return;

    setState(() => _loading = true);
    try {
      final result =
          await context.read<MatchService>().importFromUrl(url);
      setState(() {
        _loading = false;
        _preview = result;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    final p = _preview!;
    Navigator.pop(context);
    await context.read<MatchService>().addPolicy(
          title: p.title,
          province: p.province,
          city: p.city,
          policyType: p.policyType,
          content: p.content,
          deadline: p.deadline,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告已入库')),
      );
    }
  }
}

/// 粘贴导入公告对话框
class _PasteImportDialog extends StatefulWidget {
  final String initialText;
  const _PasteImportDialog({required this.initialText});

  @override
  State<_PasteImportDialog> createState() => _PasteImportDialogState();
}

class _PasteImportDialogState extends State<_PasteImportDialog> {
  late final TextEditingController _textController;
  bool _loading = false;
  TalentPolicy? _preview;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('粘贴导入公告'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: '公告文本',
                hintText: '粘贴公告内容...',
              ),
              maxLines: 6,
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('AI 正在解析...'),
                ],
              ),
            ] else if (_preview != null) ...[
              const SizedBox(height: 12),
              _PreviewCard(policy: _preview!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        if (_preview == null && !_loading)
          FilledButton(
            onPressed: _doParse,
            child: const Text('AI 解析'),
          )
        else if (_preview != null)
          FilledButton(
            onPressed: _doImport,
            child: const Text('确认入库'),
          ),
      ],
    );
  }

  Future<void> _doParse() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final result =
          await context.read<MatchService>().importFromClipboard(text);
      setState(() {
        _loading = false;
        _preview = result;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败：$e')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    final p = _preview!;
    Navigator.pop(context);
    await context.read<MatchService>().addPolicy(
          title: p.title,
          province: p.province,
          city: p.city,
          policyType: p.policyType,
          content: p.content,
          deadline: p.deadline,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告已入库')),
      );
    }
  }
}

/// 公告预览卡片（复用）
class _PreviewCard extends StatelessWidget {
  final TalentPolicy policy;
  const _PreviewCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标题：${policy.title}',
              style: const TextStyle(fontSize: 13)),
          if (policy.city != null)
            Text('城市：${policy.city}',
                style: const TextStyle(fontSize: 12)),
          if (policy.policyType != null)
            Text('类型：${policy.policyType}',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
