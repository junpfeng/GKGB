import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/interview_service.dart';
import '../services/voice_service.dart';
import '../models/interview_session.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'interview_session_screen.dart';
import 'interview_report_screen.dart';

/// 面试辅导主页：题型选择 + 开始模拟 + 历史记录
class InterviewHomeScreen extends StatefulWidget {
  const InterviewHomeScreen({super.key});

  @override
  State<InterviewHomeScreen> createState() => _InterviewHomeScreenState();
}

class _InterviewHomeScreenState extends State<InterviewHomeScreen> {
  String _selectedCategory = '综合随机';
  String _selectedMode = 'text'; // text / voice
  bool _initialized = false;
  Map<String, int> _categoryCounts = {};
  final ScrollController _scrollController = ScrollController();

  // 题型配置
  static const List<Map<String, dynamic>> _categoryConfigs = [
    {
      'name': '综合随机',
      'icon': Icons.shuffle,
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
    },
    {
      'name': '综合分析',
      'icon': Icons.analytics_outlined,
      'gradient': [Color(0xFFf093fb), Color(0xFFf5576c)],
    },
    {
      'name': '计划组织',
      'icon': Icons.event_note,
      'gradient': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    },
    {
      'name': '人际关系',
      'icon': Icons.people_outline,
      'gradient': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    },
    {
      'name': '应急应变',
      'icon': Icons.flash_on,
      'gradient': [Color(0xFFF7971E), Color(0xFFFFD200)],
    },
    {
      'name': '自我认知',
      'icon': Icons.person_outline,
      'gradient': [Color(0xFF0ED2F7), Color(0xFF09A6C3)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _init();
    }
  }

  Future<void> _init() async {
    final service = context.read<InterviewService>();
    await service.importPresetQuestions();
    _categoryCounts = await service.countByCategory();
    await service.loadHistory(limit: 20, offset: 0);
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      final service = context.read<InterviewService>();
      service.loadHistory(
        limit: 20,
        offset: service.history.length,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    final service = context.read<InterviewService>();

    // 语音模式检查：STT 不可用时降级到文字模式
    var mode = _selectedMode;
    if (mode == 'voice') {
      final voiceService = context.read<VoiceService>();
      await voiceService.initialize();
      if (!voiceService.isAvailable) {
        mode = 'text';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('语音识别不可用，已自动切换为文字模式'),
            ),
          );
        }
      }
    }
    try {
      await service.startInterview(
        category: _selectedCategory,
        mode: mode,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InterviewSessionScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面试练习')),
      body: Consumer<InterviewService>(
        builder: (context, service, _) {
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // 题型选择
              const Text(
                '选择题型',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildCategoryGrid(),
              const SizedBox(height: 16),

              // 模式选择（文字/语音）
              _buildModeSelector(),
              const SizedBox(height: 16),

              // 开始按钮
              GradientButton(
                onPressed: service.isLoading ? null : _startInterview,
                label: service.isLoading
                    ? '准备中...'
                    : _selectedMode == 'voice'
                        ? '开始语音面试（4题）'
                        : '开始模拟面试（4题）',
                icon: _selectedMode == 'voice'
                    ? Icons.mic
                    : Icons.play_arrow,
                isLoading: service.isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 24),

              // 历史记录
              Row(
                children: [
                  const Text(
                    '历史记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${service.history.length} 次',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (service.history.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('暂无面试记录，开始你的第一次模拟面试吧！',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...service.history.map((s) => _buildHistoryCard(s)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        const Text(
          '面试模式',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeChip('text', '文字', Icons.keyboard),
              _buildModeChip('voice', '语音', Icons.mic),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categoryConfigs.map((config) {
        final name = config['name'] as String;
        final icon = config['icon'] as IconData;
        final colors = config['gradient'] as List<Color>;
        final isSelected = _selectedCategory == name;
        final count = name == '综合随机'
            ? _categoryCounts.values.fold(0, (a, b) => a + b)
            : _categoryCounts[name] ?? 0;

        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 42) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: colors)
                  : null,
              color: isSelected ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(color: Colors.grey[300]!, width: 0.5),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : colors.first,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '$count 题',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: Colors.white),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryCard(InterviewSession session) {
    final isFinished = session.status == 'finished';
    final scoreColor = session.totalScore >= 7
        ? const Color(0xFF43E97B)
        : session.totalScore >= 5
            ? const Color(0xFFF7971E)
            : const Color(0xFFf5576c);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: isFinished
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InterviewReportScreen(
                      sessionId: session.id!,
                    ),
                  ),
                )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 分数圆
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  isFinished ? session.totalScore.toStringAsFixed(1) : '--',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${session.category} · ${session.totalQuestions}题',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (session.mode == 'voice') ...[
                        const SizedBox(width: 6),
                        Icon(Icons.mic, size: 14, color: Colors.grey[500]),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.startedAt?.substring(0, 16).replaceAll('T', ' ') ??
                        '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            _buildStatusChip(session.status),
            const SizedBox(width: 4),
            if (isFinished)
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final config = switch (status) {
      'finished' => ('已完成', const Color(0xFF43E97B)),
      'ongoing' => ('进行中', const Color(0xFFF7971E)),
      _ => ('已取消', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.$2.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.$1,
        style: TextStyle(fontSize: 10, color: config.$2),
      ),
    );
  }
}
