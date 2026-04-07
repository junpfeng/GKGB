import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/essay_submission.dart';
import '../services/essay_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// 申论写作训练页
class EssayTrainingScreen extends StatefulWidget {
  const EssayTrainingScreen({super.key});

  @override
  State<EssayTrainingScreen> createState() => _EssayTrainingScreenState();
}

class _EssayTrainingScreenState extends State<EssayTrainingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EssayService>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EssayService>(
      builder: (context, service, _) {
        if (service.isWriting) {
          return _WritingPage(topic: service.currentTopic ?? '');
        }
        if (service.isGrading) {
          return _GradingPage();
        }
        return _MainPage();
      },
    );
  }
}

/// 主页：选题 + 历史
class _MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('申论训练')),
      body: Consumer<EssayService>(
        builder: (context, service, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 选题区
              _SectionHeader('选择主题开始写作'),
              const SizedBox(height: 12),
              ...EssayService.presetTopics.map((topic) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AccentCard(
                      accentGradient: AppTheme.primaryGradient,
                      onTap: () => _startWriting(context, topic),
                      child: Text(
                        topic,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )),
              // 自定义主题
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AccentCard(
                  accentGradient: AppTheme.infoGradient,
                  onTap: () => _showCustomTopicDialog(context),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('自定义主题', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              // 历史记录
              if (service.history.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionHeader('写作历史'),
                const SizedBox(height: 12),
                ...service.history.map((sub) => _HistoryCard(submission: sub)),
              ],
            ],
          );
        },
      ),
    );
  }

  void _startWriting(BuildContext context, String topic) {
    context.read<EssayService>().startEssay(topic);
  }

  void _showCustomTopicDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义主题'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入申论写作主题',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final topic = controller.text.trim();
              if (topic.isEmpty) return;
              Navigator.pop(ctx);
              context.read<EssayService>().startEssay(topic);
            },
            child: const Text('开始写作'),
          ),
        ],
      ),
    );
  }
}

/// 写作页（限时倒计时）
class _WritingPage extends StatefulWidget {
  final String topic;
  const _WritingPage({required this.topic});

  @override
  State<_WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<_WritingPage> {
  final _contentController = TextEditingController();
  Timer? _timer;
  int _elapsedSeconds = 0;
  static const int _timeLimitSeconds = 3600; // 60分钟

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  int get _remainingSeconds =>
      (_timeLimitSeconds - _elapsedSeconds).clamp(0, _timeLimitSeconds);

  String get _timeDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _wordCount =>
      _contentController.text.replaceAll(RegExp(r'\s'), '').length;

  @override
  Widget build(BuildContext context) {
    final isOvertime = _remainingSeconds <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('申论写作'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmCancel(context),
        ),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOvertime ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _timeDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isOvertime ? Colors.red : Colors.green,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 题目区
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryGradient.colors.first.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '题目',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.topic,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          // 写作区
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '在此输入你的申论作文...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 15, height: 1.8),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          // 底部状态栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '字数：$_wordCount',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _wordCount > 0 ? _submit : null,
                  child: const Text('提交批改'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final service = context.read<EssayService>();
    service.submitEssay(_contentController.text);
  }

  void _confirmCancel(BuildContext context) {
    if (_wordCount == 0) {
      context.read<EssayService>().cancelWriting();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃写作？'),
        content: const Text('当前内容将不会保存'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续写作'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<EssayService>().cancelWriting();
            },
            child: const Text('确定放弃'),
          ),
        ],
      ),
    );
  }
}

/// AI 批改页（流式展示）
class _GradingPage extends StatefulWidget {
  @override
  State<_GradingPage> createState() => _GradingPageState();
}

class _GradingPageState extends State<_GradingPage> {
  String _gradingText = '';
  bool _done = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    // EssayService.submitEssay 已经调用过了，这里监听 isGrading 状态
    // 实际 stream 在 service 内部处理，UI 通过 Consumer 更新
    // 但为了流式展示，我们需要额外监听
    _startListening();
  }

  void _startListening() {
    // 批改结果通过 service.currentSubmission 获取
    // 流式过程中我们通过 notifyListeners 观测 isGrading 变化
    // 使用 Timer 轮询 ai_comment 变化（简化实现）
    _pollForResult();
  }

  void _pollForResult() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final service = context.read<EssayService>();
      if (!service.isGrading && service.currentSubmission != null) {
        setState(() {
          _gradingText = service.currentSubmission!.aiComment;
          _done = true;
        });
      } else {
        _pollForResult();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 批改结果')),
      body: Consumer<EssayService>(
        builder: (context, service, _) {
          if (service.isGrading && _gradingText.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI 正在批改中...'),
                ],
              ),
            );
          }

          final submission = service.currentSubmission;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (submission != null) ...[
                // 评分卡
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem('总分', '${submission.aiScore.toInt()}', '/100'),
                      _StatItem('字数', '${submission.wordCount}', '字'),
                      _StatItem(
                        '用时',
                        '${submission.timeSpent ~/ 60}',
                        '分钟',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 批改详情
              if (_gradingText.isNotEmpty)
                MarkdownBody(data: _gradingText)
              else if (service.isGrading)
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              if (_done)
                FilledButton(
                  onPressed: () {
                    service.loadHistory();
                    service.cancelWriting();
                  },
                  child: const Text('返回'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatItem(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGradient.colors.first,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 历史卡片
class _HistoryCard extends StatelessWidget {
  final EssaySubmission submission;
  const _HistoryCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _showDetail(context),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 分数圆圈
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: submission.aiScore >= 70
                    ? AppTheme.successGradient
                    : submission.aiScore >= 50
                        ? AppTheme.warningGradient
                        : AppTheme.warmGradient,
              ),
              child: Center(
                child: Text(
                  '${submission.aiScore.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${submission.wordCount}字 · ${submission.timeSpent ~/ 60}分钟 · ${submission.createdAt?.substring(0, 10) ?? ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SubmissionDetailPage(submissionId: submission.id!),
      ),
    );
  }
}

/// 历史详情页
class _SubmissionDetailPage extends StatefulWidget {
  final int submissionId;
  const _SubmissionDetailPage({required this.submissionId});

  @override
  State<_SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends State<_SubmissionDetailPage> {
  EssaySubmission? _submission;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final service = context.read<EssayService>();
    final sub = await service.getSubmission(widget.submissionId);
    setState(() => _submission = sub);
  }

  @override
  Widget build(BuildContext context) {
    if (_submission == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('写作详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sub = _submission!;
    return Scaffold(
      appBar: AppBar(title: const Text('写作详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 评分概览
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem('总分', '${sub.aiScore.toInt()}', '/100'),
                _StatItem('字数', '${sub.wordCount}', '字'),
                _StatItem('用时', '${sub.timeSpent ~/ 60}', '分钟'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 题目
          _SectionHeader('题目'),
          const SizedBox(height: 8),
          Text(sub.topic, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          // 作文
          _SectionHeader('作文内容'),
          const SizedBox(height: 8),
          Text(
            sub.content,
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
          const SizedBox(height: 16),
          // AI 批改
          if (sub.aiComment.isNotEmpty) ...[
            _SectionHeader('AI 批改'),
            const SizedBox(height: 8),
            MarkdownBody(data: sub.aiComment),
          ],
          const SizedBox(height: 32),
        ],
      ),
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
