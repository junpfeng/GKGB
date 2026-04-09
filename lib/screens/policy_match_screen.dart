import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../services/match_service.dart';
import '../services/crawler_service.dart';
import '../services/profile_service.dart';
import '../services/exam_category_service.dart';
import '../models/talent_policy.dart';
import '../models/match_result.dart';
import '../widgets/match_reason_card.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final matchService = context.read<MatchService>();
      await matchService.loadPolicies();
      await matchService.loadMatchResults();

      // 人才引进目标：自动加载预置公告+岗位 → 自动匹配
      if (mounted) {
        final ecService = context.read<ExamCategoryService>();
        if (ecService.activeCategory?.id == 'rencaiyinjin') {
          final added = await matchService.loadPresetPolicies();
          if (added > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已加载 $added 条全国人才引进公告及岗位数据')),
            );
          }

          // 有岗位数据且用户已填个人信息 → 自动运行匹配
          if (mounted) {
            final profile = context.read<ProfileService>().profile;
            if (profile != null && profile.education != null) {
              try {
                await matchService.runMatching();
                // 匹配完成，有结果时切到"匹配结果"Tab
                if (mounted && matchService.matchResults.isNotEmpty) {
                  _tabController.animateTo(1);
                }
              } catch (e) {
                debugPrint('自动匹配失败: $e');
              }
            }
          }
        }
      }
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
          Consumer<CrawlerService>(
            builder: (ctx, crawler, _) => IconButton(
              icon: crawler.isCrawling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              tooltip: '抓取公告',
              onPressed: crawler.isCrawling
                  ? null
                  : () => _showCrawlDialog(context),
            ),
          ),
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
              onPressed:
                  service.isMatching ? null : () => _runMatching(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '公告管理'),
            Tab(text: '匹配结果'),
          ],
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PolicyListTab(),
          _MatchResultTab(),
        ],
      ),
      // 渐变 FAB
      floatingActionButton: GradientFab(
        onPressed: () => _showAddPolicyDialog(context),
        icon: Icons.add,
        label: '添加公告',
        gradient: AppTheme.primaryGradient,
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

  void _showCrawlDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CrawlProgressDialog(),
    );
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
                    DropdownMenuItem(value: '国家公务员招录', child: Text('国考')),
                    DropdownMenuItem(value: '省公务员招录', child: Text('省考')),
                    DropdownMenuItem(value: '事业单位招聘', child: Text('事业单位')),
                    DropdownMenuItem(value: '人才引进', child: Text('人才引进')),
                    DropdownMenuItem(value: '选调生', child: Text('选调生')),
                    DropdownMenuItem(value: '国企招聘', child: Text('国企招聘')),
                    DropdownMenuItem(value: '高校招聘', child: Text('高校招聘')),
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
                  decoration: const InputDecoration(
                      labelText: '公告内容（粘贴原文，AI 可解析）'),
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

  Future<void> _showOnlineSearchDialog(BuildContext context) async {
    final profile = context.read<ProfileService>().profile;
    final defaultCities = profile?.targetCities ?? [];
    await showDialog(
      context: context,
      builder: (_) => _OnlineSearchDialog(defaultCities: defaultCities),
    );
  }

  Future<void> _showUrlImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _UrlImportDialog(),
    );
  }

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

/// 公告列表 Tab（含省份/城市筛选）
class _PolicyListTab extends StatefulWidget {
  const _PolicyListTab();

  @override
  State<_PolicyListTab> createState() => _PolicyListTabState();
}

class _PolicyListTabState extends State<_PolicyListTab> {
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedExamType;

  // 报考类型分类
  static const _examTypes = ['国考', '省考', '事业单位', '人才引进', '其他'];

  /// 将公告的 policyType 映射到报考类型筛选分类
  static String _classifyExamType(String? policyType) {
    if (policyType == null || policyType.isEmpty) return '其他';
    if (policyType.contains('国考') || policyType.contains('国家公务员')) return '国考';
    if (policyType.contains('省考') || policyType.contains('省公务员') || policyType.contains('地方公务员')) return '省考';
    if (policyType.contains('人才引进')) return '人才引进';
    if (policyType.contains('事业')) return '事业单位';
    // 选调生、国企、高校等归入"其他"
    return '其他';
  }

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

        // 提取所有省份和城市（去重排序）
        final provinces = service.policies
            .map((p) => p.province)
            .whereType<String>()
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final cities = service.policies
            .where((p) => _selectedProvince == null || p.province == _selectedProvince)
            .map((p) => p.city)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        // 筛选后的公告列表
        final filtered = service.policies.where((p) {
          if (_selectedProvince != null && p.province != _selectedProvince) return false;
          if (_selectedCity != null && p.city != _selectedCity) return false;
          if (_selectedExamType != null && _classifyExamType(p.policyType) != _selectedExamType) return false;
          return true;
        }).toList();

        final hasAnyFilter = _selectedProvince != null || _selectedCity != null || _selectedExamType != null;

        return Column(
          children: [
            // 筛选栏：报考类型
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      icon: Icons.category_outlined,
                      hint: '全部类型',
                      value: _selectedExamType,
                      items: _examTypes,
                      onChanged: (v) => setState(() => _selectedExamType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 省份筛选
                  Expanded(
                    child: _FilterDropdown(
                      icon: Icons.map_outlined,
                      hint: '全部省份',
                      value: _selectedProvince,
                      items: provinces,
                      onChanged: (v) => setState(() {
                        _selectedProvince = v;
                        if (v != null && _selectedCity != null) {
                          final citiesInProvince = service.policies
                              .where((p) => p.province == v)
                              .map((p) => p.city)
                              .toSet();
                          if (!citiesInProvince.contains(_selectedCity)) {
                            _selectedCity = null;
                          }
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 城市筛选
                  Expanded(
                    child: _FilterDropdown(
                      icon: Icons.location_city_outlined,
                      hint: '全部城市',
                      value: _selectedCity,
                      items: cities,
                      onChanged: (v) => setState(() => _selectedCity = v),
                    ),
                  ),
                  // 清除筛选
                  if (hasAnyFilter)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: '清除筛选',
                      onPressed: () => setState(() {
                        _selectedProvince = null;
                        _selectedCity = null;
                        _selectedExamType = null;
                      }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ),
            // 筛选结果计数
            if (hasAnyFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '共 ${filtered.length} 条公告',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
            // 公告列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '当前筛选条件下暂无公告',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final policy = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PolicyCard(policy: policy),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 筛选下拉框组件
class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: value != null
            ? const Color(0xFF667eea).withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: value != null
            ? Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3))
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[500]),
          style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            ...items.map((item) => DropdownMenuItem<String?>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 12)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final TalentPolicy policy;
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolicyContentScreen(policy: policy),
        ),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.article, color: Colors.white, size: 20),
            ),
            title: Text(policy.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
              child: Row(
                children: [
                  GradientButton(
                    onPressed: () => _aiParsePolicy(context, policy),
                    label: 'AI 解析岗位',
                    icon: Icons.smart_toy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    borderRadius: 8,
                    gradient: AppTheme.infoGradient,
                    textStyle: const TextStyle(
                        color: Colors.white, fontSize: 12),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功解析 ${positions.length} 个岗位')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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
                const Text(
                  '请先添加公告，然后点击右上角搜索开始匹配',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: () {},
                  label: '完善个人信息',
                  gradient: AppTheme.primaryGradient,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  borderRadius: 10,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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

/// 岗位详情页（含岗位要求 + 公告原文）
class PositionDetailScreen extends StatefulWidget {
  final MatchResult result;
  const PositionDetailScreen({super.key, required this.result});

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  Map<String, dynamic>? _position;
  Map<String, dynamic>? _policy;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final db = DatabaseHelper.instance;
    final posRow = await db.queryPositionById(widget.result.positionId);
    if (posRow != null) {
      final policyId = posRow['policy_id'] as int?;
      if (policyId != null) {
        final polRow = await db.queryPolicyById(policyId);
        if (mounted) setState(() => _policy = polRow);
      }
    }
    if (mounted) {
      setState(() {
        _position = posRow;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.result.positionName ?? '岗位详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiChatDialog.show(
              context,
              initialPrompt: '请详细分析我报考"${widget.result.positionName}"岗位的可能性，'
                  '匹配分数为${widget.result.matchScore}分，'
                  '符合项：${widget.result.matchedItems.join("、")}，'
                  '风险项：${widget.result.riskItems.join("、")}，'
                  '不符项：${widget.result.unmatchedItems.join("、")}。'
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
            // 匹配分析卡片
            MatchReasonCard(
              result: widget.result,
              onSetTarget: () =>
                  context.read<MatchService>().toggleTarget(widget.result.id!),
            ),
            const SizedBox(height: 16),

            // 岗位要求详情
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else ...[
              if (_position != null) _buildPositionRequirements(),
              const SizedBox(height: 16),

              // 公告原文
              if (_policy != null) _buildPolicyContent(),
              const SizedBox(height: 16),
            ],

            // AI 深度分析按钮
            GradientButton(
              onPressed: () => AiChatDialog.show(
                context,
                initialPrompt: '请分析"${widget.result.positionName}"岗位的报考建议',
                title: 'AI 报考分析',
              ),
              label: 'AI 深度分析',
              icon: Icons.smart_toy,
              width: double.infinity,
              gradient: AppTheme.infoGradient,
            ),
          ],
        ),
      ),
    );
  }

  /// 岗位要求详情卡片
  Widget _buildPositionRequirements() {
    final pos = _position!;
    final requirements = <_ReqItem>[
      if (pos['education_req'] != null)
        _ReqItem('学历要求', pos['education_req'] as String, Icons.school),
      if (pos['degree_req'] != null)
        _ReqItem('学位要求', pos['degree_req'] as String, Icons.workspace_premium),
      if (pos['major_req'] != null)
        _ReqItem('专业要求', pos['major_req'] as String, Icons.menu_book),
      if (pos['age_req'] != null)
        _ReqItem('年龄要求', pos['age_req'] as String, Icons.cake),
      if (pos['political_req'] != null)
        _ReqItem('政治面貌', pos['political_req'] as String, Icons.flag),
      if (pos['work_exp_req'] != null)
        _ReqItem('工作经验', pos['work_exp_req'] as String, Icons.work_history),
      if (pos['gender_req'] != null)
        _ReqItem('性别要求', pos['gender_req'] as String, Icons.people),
      if (pos['hukou_req'] != null)
        _ReqItem('户籍要求', pos['hukou_req'] as String, Icons.location_on),
      if (pos['certificate_req'] != null)
        _ReqItem('证书要求', pos['certificate_req'] as String, Icons.card_membership),
      if (pos['exam_subjects'] != null)
        _ReqItem('考试科目', pos['exam_subjects'] as String, Icons.edit_note),
      if (pos['exam_date'] != null)
        _ReqItem('考试时间', pos['exam_date'] as String, Icons.event),
      if (pos['other_req'] != null)
        _ReqItem('其他要求', pos['other_req'] as String, Icons.info_outline),
    ];

    if (requirements.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('岗位要求',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (pos['recruit_count'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '招${pos['recruit_count']}人',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements.map((req) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(req.icon, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: Text(
                    req.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                Expanded(
                  child: Text(
                    req.value,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 公告原文卡片
  Widget _buildPolicyContent() {
    final title = _policy!['title'] as String? ?? '公告';
    final content = _policy!['content'] as String?;
    final province = _policy!['province'] as String?;
    final city = _policy!['city'] as String?;
    final deadline = _policy!['deadline'] as String?;
    final policyType = _policy!['policy_type'] as String?;
    final sourceUrl = _policy!['source_url'] as String?;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.infoGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.article, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('公告详情',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 公告标题
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // 公告元信息
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (province != null || city != null)
                _metaChip(Icons.location_on, [province, city].whereType<String>().join(' ')),
              if (policyType != null)
                _metaChip(Icons.label_outline, policyType),
              if (deadline != null)
                _metaChip(Icons.event, '截止：$deadline'),
            ],
          ),
          // 来源链接
          if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(sourceUrl);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('无法打开链接：$e')),
                      );
                    }
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: Color(0xFF667eea)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '查看公告原文',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 13, color: Color(0xFF667eea)),
                  ],
                ),
              ),
            ),
          ],
          if (content != null && content.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              sourceUrl != null ? '点击上方链接查看公告原文' : '暂无公告正文内容',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

/// 岗位要求条目
class _ReqItem {
  final String label;
  final String value;
  final IconData icon;
  const _ReqItem(this.label, this.value, this.icon);
}

/// 公告详情页（从公告管理列表点击进入）
class PolicyContentScreen extends StatelessWidget {
  final TalentPolicy policy;
  const PolicyContentScreen({super.key, required this.policy});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告详情'),
        actions: [
          if (policy.content != null && policy.content!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.smart_toy),
              tooltip: 'AI 解析岗位',
              onPressed: () => _aiParsePolicy(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 公告标题
            Text(
              policy.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 元信息
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (policy.province != null)
                  _metaChip(Icons.map_outlined, policy.province!),
                if (policy.city != null)
                  _metaChip(Icons.location_city, policy.city!),
                if (policy.policyType != null)
                  _metaChip(Icons.label_outline, policy.policyType!),
                if (policy.deadline != null)
                  _metaChip(Icons.event, '截止：${policy.deadline}'),
                if (policy.publishDate != null)
                  _metaChip(Icons.calendar_today, '发布：${policy.publishDate}'),
              ],
            ),

            // 来源链接
            if (policy.sourceUrl != null && policy.sourceUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(12),
                onTap: () => _launchUrl(context, policy.sourceUrl!),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.infoGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.link, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '公告原文链接',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            policy.sourceUrl!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667eea),
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 16, color: Color(0xFF667eea)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 公告正文
            if (policy.content != null && policy.content!.isNotEmpty) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '公告正文',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      policy.content!,
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ],
                ),
              ),
            ] else ...[
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        policy.sourceUrl != null
                            ? '暂无正文内容，请点击上方链接查看原文'
                            : '暂无公告正文内容',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // AI 解析按钮
            if (policy.content != null && policy.content!.isNotEmpty) ...[
              const SizedBox(height: 16),
              GradientButton(
                onPressed: () => _aiParsePolicy(context),
                label: 'AI 解析岗位',
                icon: Icons.smart_toy,
                width: double.infinity,
                gradient: AppTheme.infoGradient,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接：$e')),
        );
      }
    }
  }

  Future<void> _aiParsePolicy(BuildContext context) async {
    if (policy.content == null || policy.content!.isEmpty) return;

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
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功解析 ${positions.length} 个岗位')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 解析失败：$e')),
        );
      }
    }
  }
}

// ===== 对话框组件 =====

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
                      title: Text(p.title, style: const TextStyle(fontSize: 13)),
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
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
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
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
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
      final result = await context.read<MatchService>().importFromUrl(url);
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
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F8F2), Color(0xFFD4F5E9)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF43E97B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标题：${policy.title}', style: const TextStyle(fontSize: 13)),
          if (policy.city != null)
            Text('城市：${policy.city}', style: const TextStyle(fontSize: 12)),
          if (policy.policyType != null)
            Text('类型：${policy.policyType}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 抓取进度对话框
class _CrawlProgressDialog extends StatefulWidget {
  const _CrawlProgressDialog();

  @override
  State<_CrawlProgressDialog> createState() => _CrawlProgressDialogState();
}

class _CrawlProgressDialogState extends State<_CrawlProgressDialog> {
  String? _selectedProvince;
  bool _started = false;
  CrawlReport? _report;

  @override
  Widget build(BuildContext context) {
    final crawler = context.watch<CrawlerService>();

    return AlertDialog(
      title: const Text('抓取公告'),
      content: SizedBox(
        width: 400,
        child: _started ? _buildProgress(crawler) : _buildSetup(),
      ),
      actions: [
        if (!_started) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _startCrawl(),
            child: const Text('开始抓取'),
          ),
        ] else if (crawler.isCrawling) ...[
          TextButton(
            onPressed: () {
              crawler.cancelCrawl();
            },
            child: const Text('停止'),
          ),
        ] else ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 刷新列表
              context.read<MatchService>().loadPolicies();
            },
            child: const Text('关闭'),
          ),
        ],
      ],
    );
  }

  Widget _buildSetup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '从江浙沪皖鲁五省 ${CrawlerService.totalSiteCount} 个政府人社网站抓取人才引进和事业编招聘公告。',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _selectedProvince,
          decoration: const InputDecoration(
            labelText: '选择省份',
            helperText: '留空则抓取全部五省',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('全部五省'),
            ),
            ...CrawlerService.provinces.map((p) => DropdownMenuItem(
              value: p,
              child: Text('$p（${CrawlerService.getSitesByProvince(p).length}个站点）'),
            )),
          ],
          onChanged: (v) => setState(() => _selectedProvince = v),
        ),
        const SizedBox(height: 8),
        const Text(
          '提示：抓取过程需要调用 AI 解析，请确保已配置 LLM。每个站点间隔 ≥2s。',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgress(CrawlerService crawler) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: crawler.isCrawling ? crawler.progress : 1.0,
        ),
        const SizedBox(height: 12),
        Text(
          crawler.currentStatus,
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          '已发现公告: ${crawler.policiesFound} 条',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        if (_report != null && !crawler.isCrawling) ...[
          const Divider(),
          Text('成功站点: ${_report!.successSources} / ${_report!.totalSources}'),
          Text('失败站点: ${_report!.failedSources}'),
          Text('新增公告: ${_report!.newPolicies} 条'),
          Text('新增岗位: ${_report!.newPositions} 个'),
          if (_report!.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('错误:', style: TextStyle(color: Colors.red, fontSize: 12)),
            ...(_report!.errors.take(5).map((e) => Text(
              e,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ))),
            if (_report!.errors.length > 5)
              Text('... 共 ${_report!.errors.length} 个错误',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ],
      ],
    );
  }

  Future<void> _startCrawl() async {
    setState(() => _started = true);

    final crawler = context.read<CrawlerService>();

    // 初始化站点数据到数据库
    await crawler.initSources();

    CrawlReport report;
    if (_selectedProvince != null) {
      report = await crawler.crawlProvince(_selectedProvince!);
    } else {
      report = await crawler.crawlAllProvinces();
    }

    if (mounted) {
      setState(() => _report = report);
    }
  }
}
