import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/idiom.dart';
import '../models/idiom_example.dart';
import '../services/idiom_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// 成语整理页面
/// 展示从选词填空题中提取的成语释义和人民日报例句
class IdiomListScreen extends StatefulWidget {
  const IdiomListScreen({super.key});

  @override
  State<IdiomListScreen> createState() => _IdiomListScreenState();
}

class _IdiomListScreenState extends State<IdiomListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IdiomService>().loadIdioms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<IdiomService>();

    return Scaffold(
      appBar: AppBar(title: const Text('成语整理')),
      body: _buildBody(service),
    );
  }

  Widget _buildBody(IdiomService service) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.idioms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              '暂无成语数据',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              '成语数据将随题库更新自动导入',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 统计信息
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                '共 ${service.idioms.length} 个成语',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // 成语列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: service.idioms.length,
            itemBuilder: (context, index) {
              return _IdiomExpandableCard(idiom: service.idioms[index]);
            },
          ),
        ),
      ],
    );
  }
}

/// 单个成语的手风琴卡片
class _IdiomExpandableCard extends StatefulWidget {
  final Idiom idiom;
  const _IdiomExpandableCard({required this.idiom});

  @override
  State<_IdiomExpandableCard> createState() => _IdiomExpandableCardState();
}

class _IdiomExpandableCardState extends State<_IdiomExpandableCard> {
  bool _expanded = false;
  List<IdiomExample>? _examples;

  Future<void> _loadExamples() async {
    if (_examples != null || widget.idiom.id == null) return;
    final service = context.read<IdiomService>();
    final examples = await service.getExamples(widget.idiom.id!);
    if (mounted) {
      setState(() => _examples = examples);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _expanded = !_expanded);
          if (_expanded) _loadExamples();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 成语标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.idiom.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              // 释义
              if (widget.idiom.definition.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.idiom.definition,
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
              // 展开：人民日报例句
              if (_expanded) ...[
                const SizedBox(height: 12),
                _buildExamplesSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamplesSection() {
    if (_examples == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_examples!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '暂无人民日报例句',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.newspaper, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '人民日报用法 (${_examples!.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._examples!.map((ex) => _buildExampleItem(ex)),
      ],
    );
  }

  Widget _buildExampleItem(IdiomExample example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${example.year}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667eea),
              ),
            ),
          ),
          Expanded(
            child: Text(
              example.sentence,
              style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
