import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/political_document.dart';
import '../models/exam_point.dart';
import '../models/mnemonic.dart';
import '../models/concept_comparison.dart';
import '../services/political_theory_service.dart';
import '../widgets/glass_card.dart';

/// 政治理论文件解读与口诀记忆页面（3 Tab）
class PoliticalTheoryScreen extends StatelessWidget {
  const PoliticalTheoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('政治理论专项'),
          bottom: TabBar(
            tabs: const [
              Tab(text: '文件解读'),
              Tab(text: '口诀记忆'),
              Tab(text: '概念对比'),
            ],
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            indicatorColor: const Color(0xFFE53935),
            dividerColor: Colors.transparent,
          ),
        ),
        body: const TabBarView(
          children: [
            _DocumentTab(),
            _MnemonicTab(),
            _ComparisonTab(),
          ],
        ),
      ),
    );
  }
}

// ===== Tab 1: 文件解读 =====

class _DocumentTab extends StatefulWidget {
  const _DocumentTab();

  @override
  State<_DocumentTab> createState() => _DocumentTabState();
}

class _DocumentTabState extends State<_DocumentTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticalTheoryService>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PoliticalTheoryService>();

    if (service.isLoading && service.documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.documents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无政治文件数据'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: service.documents.length,
      itemBuilder: (context, index) {
        final doc = service.documents[index];
        return _DocumentCard(document: doc);
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final PoliticalDocument document;
  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AccentCard(
        accentGradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFF7043)],
        ),
        accentWidth: 5,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ExamPointListScreen(document: document),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x1AE53935),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, color: Color(0xFFE53935), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0x1AE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          document.docTypeLabel,
                          style: const TextStyle(fontSize: 10, color: Color(0xFFE53935)),
                        ),
                      ),
                      if (document.publishDate != null && document.publishDate!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          document.publishDate!,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

// ===== 考点列表页 =====

class _ExamPointListScreen extends StatefulWidget {
  final PoliticalDocument document;
  const _ExamPointListScreen({required this.document});

  @override
  State<_ExamPointListScreen> createState() => _ExamPointListScreenState();
}

class _ExamPointListScreenState extends State<_ExamPointListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticalTheoryService>().loadExamPoints(widget.document.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PoliticalTheoryService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: service.isLoading && service.examPoints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : service.examPoints.isEmpty
              ? const Center(child: Text('暂无考点数据'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: service.examPoints.length,
                  itemBuilder: (context, index) {
                    final point = service.examPoints[index];
                    return _ExamPointCard(
                      point: point,
                      documentId: widget.document.id!,
                    );
                  },
                ),
    );
  }
}

class _ExamPointCard extends StatelessWidget {
  final ExamPoint point;
  final int documentId;
  const _ExamPointCard({required this.point, required this.documentId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AccentCard(
        accentGradient: const LinearGradient(
          colors: [Color(0xFFFF7043), Color(0xFFFFCA28)],
        ),
        accentWidth: 4,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ExamPointDetailScreen(
              point: point,
              documentId: documentId,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (point.section.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  point.section,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            Text(
              point.pointText,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < point.importance ? Icons.star : Icons.star_border,
                    size: 14,
                    color: i < point.importance
                        ? const Color(0xFFFFCA28)
                        : Colors.grey[300],
                  ),
                ),
                const SizedBox(width: 12),
                if (point.frequency > 0)
                  Text(
                    '考频 ${point.frequency}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 考点详情页（含口诀生成） =====

class _ExamPointDetailScreen extends StatefulWidget {
  final ExamPoint point;
  final int documentId;
  const _ExamPointDetailScreen({
    required this.point,
    required this.documentId,
  });

  @override
  State<_ExamPointDetailScreen> createState() => _ExamPointDetailScreenState();
}

class _ExamPointDetailScreenState extends State<_ExamPointDetailScreen> {
  Mnemonic? _latestMnemonic;
  String _selectedStyle = 'rhyme';
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _loadLatestMnemonic();
  }

  Future<void> _loadLatestMnemonic() async {
    final service = context.read<PoliticalTheoryService>();
    final mnemonic = await service.getLatestMnemonic(widget.point.id!);
    if (mounted) {
      setState(() => _latestMnemonic = mnemonic);
    }
  }

  Future<void> _generateMnemonic() async {
    final service = context.read<PoliticalTheoryService>();
    try {
      final mnemonic = await service.generateMnemonic(
        widget.point.id!,
        style: _selectedStyle,
        documentId: widget.documentId,
      );
      if (mnemonic != null && mounted) {
        setState(() {
          _latestMnemonic = mnemonic;
          _showExplanation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PoliticalTheoryService>();

    return Scaffold(
      appBar: AppBar(title: const Text('考点详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 考点内容
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.point.section.isNotEmpty) ...[
                      Text(
                        widget.point.section,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      widget.point.pointText,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < widget.point.importance ? Icons.star : Icons.star_border,
                          size: 16,
                          color: i < widget.point.importance
                              ? const Color(0xFFFFCA28)
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 口诀生成区域
            const Text(
              '口诀记忆',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // 风格选择
            Wrap(
              spacing: 8,
              children: Mnemonic.styleValues.map((style) {
                final isSelected = _selectedStyle == style;
                return ChoiceChip(
                  label: Text(Mnemonic.styleLabels[style] ?? style),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE53935).withValues(alpha: 0.15),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedStyle = style);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 流式生成展示
            if (service.isGenerating) ...[
              Card(
                color: const Color(0xFFFFF3E0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('AI 正在创作口诀...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (service.streamingContent.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          service.streamingContent,
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else if (_latestMnemonic != null) ...[
              _MnemonicCard(
                mnemonic: _latestMnemonic!,
                showExplanation: _showExplanation,
                onToggleExplanation: () {
                  setState(() => _showExplanation = !_showExplanation);
                },
              ),
            ],

            const SizedBox(height: 12),
            // 生成 / 换一个 按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: service.isGenerating ? null : _generateMnemonic,
                icon: Icon(
                  _latestMnemonic != null ? Icons.refresh : Icons.auto_awesome,
                  size: 18,
                ),
                label: Text(_latestMnemonic != null ? '换一个' : '生成口诀'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Tab 2: 口诀记忆 =====

class _MnemonicTab extends StatefulWidget {
  const _MnemonicTab();

  @override
  State<_MnemonicTab> createState() => _MnemonicTabState();
}

class _MnemonicTabState extends State<_MnemonicTab> {
  bool _favoritedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticalTheoryService>().loadMnemonics();
    });
  }

  void _refresh() {
    context.read<PoliticalTheoryService>().loadMnemonics(
      favoritedOnly: _favoritedOnly ? true : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PoliticalTheoryService>();

    return Column(
      children: [
        // 筛选栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('仅收藏'),
                selected: _favoritedOnly,
                selectedColor: const Color(0xFFE53935).withValues(alpha: 0.15),
                onSelected: (v) {
                  setState(() => _favoritedOnly = v);
                  _refresh();
                },
              ),
              const Spacer(),
              Text(
                '共 ${service.mnemonics.length} 条',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Expanded(
          child: service.isLoading && service.mnemonics.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : service.mnemonics.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无口诀，去考点页面生成'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: service.mnemonics.length,
                      itemBuilder: (context, index) {
                        final m = service.mnemonics[index];
                        return _MnemonicListCard(mnemonic: m);
                      },
                    ),
        ),
      ],
    );
  }
}

class _MnemonicListCard extends StatefulWidget {
  final Mnemonic mnemonic;
  const _MnemonicListCard({required this.mnemonic});

  @override
  State<_MnemonicListCard> createState() => _MnemonicListCardState();
}

class _MnemonicListCardState extends State<_MnemonicListCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _MnemonicCard(
      mnemonic: widget.mnemonic,
      showExplanation: _expanded,
      onToggleExplanation: () => setState(() => _expanded = !_expanded),
      showFavorite: true,
      padding: const EdgeInsets.only(bottom: 10),
    );
  }
}

/// 通用口诀卡片
class _MnemonicCard extends StatelessWidget {
  final Mnemonic mnemonic;
  final bool showExplanation;
  final VoidCallback onToggleExplanation;
  final bool showFavorite;
  final EdgeInsets padding;

  const _MnemonicCard({
    required this.mnemonic,
    required this.showExplanation,
    required this.onToggleExplanation,
    this.showFavorite = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Card(
        color: const Color(0xFFFFF8E1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主题
              Text(
                mnemonic.topic,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              // 口诀大字
              Text(
                mnemonic.mnemonicText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
              if (mnemonic.explanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onToggleExplanation,
                  child: Row(
                    children: [
                      Icon(
                        showExplanation ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      Text(
                        showExplanation ? '收起解释' : '查看解释',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (showExplanation)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      mnemonic.explanation,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              // 操作栏
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mnemonic.styleLabel,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  if (showFavorite)
                    IconButton(
                      icon: Icon(
                        mnemonic.isFavorited ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: mnemonic.isFavorited ? const Color(0xFFE53935) : Colors.grey,
                      ),
                      tooltip: mnemonic.isFavorited ? '取消收藏' : '收藏',
                      onPressed: () {
                        context.read<PoliticalTheoryService>().toggleFavorite(mnemonic.id!);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: '复制到剪贴板',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mnemonic.mnemonicText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Tab 3: 概念对比 =====

class _ComparisonTab extends StatefulWidget {
  const _ComparisonTab();

  @override
  State<_ComparisonTab> createState() => _ComparisonTabState();
}

class _ComparisonTabState extends State<_ComparisonTab> {
  final _conceptAController = TextEditingController();
  final _conceptBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticalTheoryService>().loadComparisons();
    });
  }

  @override
  void dispose() {
    _conceptAController.dispose();
    _conceptBController.dispose();
    super.dispose();
  }

  Future<void> _generateCustomComparison() async {
    final a = _conceptAController.text.trim();
    final b = _conceptBController.text.trim();
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入两个概念')),
      );
      return;
    }
    try {
      await context.read<PoliticalTheoryService>().generateComparison(a, b);
      _conceptAController.clear();
      _conceptBController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PoliticalTheoryService>();

    return Column(
      children: [
        // 自定义对比输入
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自定义概念对比',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _conceptAController,
                          decoration: const InputDecoration(
                            hintText: '概念 A',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('vs', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _conceptBController,
                          decoration: const InputDecoration(
                            hintText: '概念 B',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: service.isGenerating ? null : _generateCustomComparison,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: service.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('AI 生成对比表'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 流式生成提示
        if (service.isGenerating && service.streamingContent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              color: const Color(0xFFFFF3E0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text('AI 正在分析...', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.streamingContent,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // 对比列表
        Expanded(
          child: service.isLoading && service.comparisons.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : service.comparisons.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无概念对比'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: service.comparisons.length,
                      itemBuilder: (context, index) {
                        return _ComparisonCard(
                          comparison: service.comparisons[index],
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final ConceptComparison comparison;
  const _ComparisonCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final dims = comparison.dimensions;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${comparison.conceptA}  vs  ${comparison.conceptB}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // 对比表格
              if (dims.isEmpty)
                const Text('暂无对比维度', style: TextStyle(color: Colors.grey))
              else
                Table(
                  border: TableBorder.all(
                    color: Colors.grey[300]!,
                    width: 0.5,
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    // 表头
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableCell('维度', isHeader: true),
                        _tableCell(comparison.conceptA, isHeader: true),
                        _tableCell(comparison.conceptB, isHeader: true),
                      ],
                    ),
                    // 数据行
                    ...dims.map(
                      (d) => TableRow(
                        children: [
                          _tableCell(d.name, isHeader: true),
                          _tableCell(d.aDesc),
                          _tableCell(d.bDesc),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          height: 1.4,
        ),
      ),
    );
  }
}
