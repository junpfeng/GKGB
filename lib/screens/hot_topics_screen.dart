import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/hot_topic.dart';
import '../services/hot_topic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// 时政热点浏览页
class HotTopicsScreen extends StatefulWidget {
  const HotTopicsScreen({super.key});

  @override
  State<HotTopicsScreen> createState() => _HotTopicsScreenState();
}

class _HotTopicsScreenState extends State<HotTopicsScreen> {
  String? _selectedCategory;
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTopics();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadTopics() async {
    final service = context.read<HotTopicService>();
    await service.loadTopics(category: _selectedCategory);
    setState(() {
      _hasMore = service.topics.length >= 20;
    });
  }

  Future<void> _loadMore() async {
    final service = context.read<HotTopicService>();
    if (service.isLoading) return;
    final offset = service.topics.length;
    await service.loadTopics(
      category: _selectedCategory,
      offset: offset,
    );
    setState(() {
      _hasMore = service.topics.length > offset;
    });
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _hasMore = true;
    });
    _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('时政热点')),
      body: Column(
        children: [
          // 分类筛选
          _buildCategoryFilter(),
          // 热点列表
          Expanded(
            child: Consumer<HotTopicService>(
              builder: (context, service, _) {
                if (service.isLoading && service.topics.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (service.topics.isEmpty) {
                  return const Center(
                    child: Text('暂无热点数据', style: TextStyle(color: Colors.grey)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _loadTopics,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: service.topics.length,
                    itemBuilder: (context, index) {
                      return _TopicCard(
                        topic: service.topics[index],
                        onTap: () => _showTopicDetail(service.topics[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTopicDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: '全部',
            selected: _selectedCategory == null,
            onTap: () => _onCategoryChanged(null),
          ),
          const SizedBox(width: 8),
          ...HotTopicService.categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: cat,
                  selected: _selectedCategory == cat,
                  onTap: () => _onCategoryChanged(cat),
                ),
              )),
        ],
      ),
    );
  }

  void _showTopicDetail(HotTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TopicDetailPage(topic: topic),
      ),
    );
  }

  void _showAddTopicDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加热点'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '输入热点标题',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '内容摘要',
                  hintText: '输入热点内容，AI 将自动生成考点分析',
                ),
                maxLines: 5,
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
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              final service = context.read<HotTopicService>();
              await service.addTopic(title, content);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

/// 分类筛选芯片
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 热点卡片
class _TopicCard extends StatelessWidget {
  final HotTopic topic;
  final VoidCallback onTap;
  const _TopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _RelevanceBadge(score: topic.relevanceScore),
              ],
            ),
            if (topic.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                topic.summary,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            // 底部信息行
            Row(
              children: [
                if (topic.category.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGradient.colors.first
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      topic.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryGradient.colors.first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (topic.source.isNotEmpty)
                  Text(
                    topic.source,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                const Spacer(),
                if (topic.publishDate != null)
                  Text(
                    topic.publishDate!.substring(0, 10),
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

/// 关联度角标
class _RelevanceBadge extends StatelessWidget {
  final int score;
  const _RelevanceBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 8
        ? Colors.red
        : score >= 5
            ? Colors.orange
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$score/10',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 热点详情页（含 AI 考点分析）
class _TopicDetailPage extends StatefulWidget {
  final HotTopic topic;
  const _TopicDetailPage({required this.topic});

  @override
  State<_TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<_TopicDetailPage> {
  String _analysisText = '';
  bool _isStreaming = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('热点详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 标题
          Text(
            widget.topic.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 元信息
          Row(
            children: [
              if (widget.topic.category.isNotEmpty)
                Chip(
                  label: Text(widget.topic.category,
                      style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              _RelevanceBadge(score: widget.topic.relevanceScore),
              const Spacer(),
              if (widget.topic.publishDate != null)
                Text(
                  widget.topic.publishDate!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 摘要
          if (widget.topic.summary.isNotEmpty) ...[
            _SectionHeader('摘要'),
            const SizedBox(height: 8),
            Text(widget.topic.summary, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
          ],
          // 考点分析
          if (widget.topic.examPoints.isNotEmpty) ...[
            _SectionHeader('考点分析'),
            const SizedBox(height: 8),
            MarkdownBody(data: widget.topic.examPoints),
            const SizedBox(height: 16),
          ],
          // 申论角度
          if (widget.topic.essayAngles.isNotEmpty) ...[
            _SectionHeader('申论角度'),
            const SizedBox(height: 8),
            MarkdownBody(data: widget.topic.essayAngles),
            const SizedBox(height: 16),
          ],
          // AI 深度分析按钮
          FilledButton.icon(
            onPressed: _isStreaming ? null : _startAnalysis,
            icon: const Icon(Icons.auto_awesome),
            label: Text(_isStreaming ? '分析中...' : 'AI 深度考点分析'),
          ),
          // 流式分析结果
          if (_analysisText.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader('AI 深度分析'),
            const SizedBox(height: 8),
            MarkdownBody(data: _analysisText),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _startAnalysis() {
    setState(() {
      _isStreaming = true;
      _analysisText = '';
    });

    final service = context.read<HotTopicService>();
    service.aiAnalyzeTopic(widget.topic.id!).listen(
      (chunk) {
        setState(() {
          _analysisText += chunk;
        });
      },
      onError: (e) {
        setState(() => _isStreaming = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('分析失败: $e')),
          );
        }
      },
      onDone: () {
        setState(() => _isStreaming = false);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
