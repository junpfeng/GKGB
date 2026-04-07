import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/essay_material.dart';
import '../services/hot_topic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// 申论素材库页面
class EssayMaterialScreen extends StatefulWidget {
  const EssayMaterialScreen({super.key});

  @override
  State<EssayMaterialScreen> createState() => _EssayMaterialScreenState();
}

class _EssayMaterialScreenState extends State<EssayMaterialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: HotTopicService.themes.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMaterials();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (!_showFavorites) {
      _loadMaterials();
    }
  }

  Future<void> _loadMaterials() async {
    final service = context.read<HotTopicService>();
    final theme = HotTopicService.themes[_tabController.index];
    await service.loadMaterials(theme: theme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('申论素材库'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showFavorites ? Colors.red : null,
            ),
            onPressed: () {
              setState(() => _showFavorites = !_showFavorites);
              if (_showFavorites) {
                context.read<HotTopicService>().loadFavoriteMaterials();
              } else {
                _loadMaterials();
              }
            },
            tooltip: '收藏素材',
          ),
        ],
        bottom: _showFavorites
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: HotTopicService.themes
                    .map((t) => Tab(text: t))
                    .toList(),
              ),
      ),
      body: _showFavorites ? _buildFavoritesList() : _buildTabContent(),
    );
  }

  Widget _buildTabContent() {
    return Consumer<HotTopicService>(
      builder: (context, service, _) {
        if (service.isLoading && service.materials.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (service.materials.isEmpty) {
          return const Center(
            child: Text('暂无素材', style: TextStyle(color: Colors.grey)),
          );
        }
        // 按类型分组
        return _MaterialGroupList(materials: service.materials);
      },
    );
  }

  Widget _buildFavoritesList() {
    return Consumer<HotTopicService>(
      builder: (context, service, _) {
        if (service.favoriteMaterials.isEmpty) {
          return const Center(
            child: Text('暂无收藏素材', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.favoriteMaterials.length,
          itemBuilder: (context, index) {
            return _MaterialCard(
              material: service.favoriteMaterials[index],
            );
          },
        );
      },
    );
  }
}

/// 按类型分组显示素材
class _MaterialGroupList extends StatelessWidget {
  final List<EssayMaterial> materials;
  const _MaterialGroupList({required this.materials});

  @override
  Widget build(BuildContext context) {
    // 按 materialType 分组
    final groups = <String, List<EssayMaterial>>{};
    for (final m in materials) {
      groups.putIfAbsent(m.materialType, () => []).add(m);
    }

    final typeOrder = HotTopicService.materialTypes;
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final ia = typeOrder.indexOf(a);
        final ib = typeOrder.indexOf(b);
        return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final type = sortedKeys[index];
        final items = groups[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _typeIcon(type),
                    size: 18,
                    color: AppTheme.primaryGradient.colors.first,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length}条',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            ...items.map((m) => _MaterialCard(material: m)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case '名言金句':
        return Icons.format_quote;
      case '典型案例':
        return Icons.lightbulb_outline;
      case '政策表述':
        return Icons.policy;
      case '数据支撑':
        return Icons.bar_chart;
      default:
        return Icons.article;
    }
  }
}

/// 素材卡片
class _MaterialCard extends StatelessWidget {
  final EssayMaterial material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              material.content,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (material.source.isNotEmpty)
                  Text(
                    '—— ${material.source}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    context
                        .read<HotTopicService>()
                        .toggleMaterialFavorite(material.id!);
                  },
                  child: Icon(
                    material.favorited
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 20,
                    color: material.favorited ? Colors.red : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
