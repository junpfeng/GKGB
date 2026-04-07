import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/interview_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'interview_report_screen.dart';

/// 面试进行页：逐题展示 + 计时 + 作答 + AI 流式评分 + 追问
class InterviewSessionScreen extends StatefulWidget {
  const InterviewSessionScreen({super.key});

  @override
  State<InterviewSessionScreen> createState() => _InterviewSessionScreenState();
}

class _InterviewSessionScreenState extends State<InterviewSessionScreen> {
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _aiComment = '';
  bool _answerSubmitted = false;
  bool _followUpSubmitted = false;
  String _followUpComment = '';
  int _answerStartTime = 0;
  StreamSubscription<String>? _commentSubscription;

  @override
  void dispose() {
    _answerController.dispose();
    _followUpController.dispose();
    _scrollController.dispose();
    _commentSubscription?.cancel();
    super.dispose();
  }

  void _submitAnswer() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入你的回答')),
      );
      return;
    }

    final service = context.read<InterviewService>();
    final timeSpent = InterviewService.answeringDuration - service.remainingSeconds;

    setState(() {
      _answerSubmitted = true;
      _aiComment = '';
    });

    _commentSubscription?.cancel();
    final stream = service.submitAnswer(answer, timeSpent);
    _commentSubscription = stream.listen(
      (chunk) {
        if (mounted) {
          setState(() => _aiComment += chunk);
          _scrollToBottom();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _aiComment += '\n\n评分服务暂时不可用: $e');
        }
      },
    );
  }

  Future<void> _submitFollowUp() async {
    final answer = _followUpController.text.trim();
    if (answer.isEmpty) return;

    final service = context.read<InterviewService>();
    final comment = await service.submitFollowUp(answer);
    if (mounted) {
      setState(() {
        _followUpSubmitted = true;
        _followUpComment = comment;
      });
      _scrollToBottom();
    }
  }

  void _nextQuestion() {
    _commentSubscription?.cancel();
    final service = context.read<InterviewService>();
    service.nextQuestion();
    setState(() {
      _answerController.clear();
      _followUpController.clear();
      _aiComment = '';
      _answerSubmitted = false;
      _followUpSubmitted = false;
      _followUpComment = '';
      _answerStartTime = 0;
    });
  }

  void _goToReport() {
    _commentSubscription?.cancel();
    final service = context.read<InterviewService>();
    final sessionId = service.currentSession!.id!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InterviewReportScreen(
          sessionId: sessionId,
          isLive: true,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<InterviewService>(
            builder: (_, service, _) {
              final total = service.sessionQuestions.length;
              final current = service.currentQuestionIndex + 1;
              return Text('模拟面试 $current/$total');
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitDialog,
          ),
        ),
        body: Consumer<InterviewService>(
          builder: (context, service, _) {
            final question = service.currentQuestion;
            if (question == null) {
              return const Center(child: Text('没有题目'));
            }

            return Column(
              children: [
                // 计时器条
                _buildTimerBar(service),

                // 内容区
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      // 题目卡片
                      _buildQuestionCard(service),
                      const SizedBox(height: 16),

                      // 作答区
                      if (!_answerSubmitted) ...[
                        _buildAnswerArea(service),
                      ] else ...[
                        // 用户答案展示
                        _buildUserAnswerCard(),
                        const SizedBox(height: 12),

                        // AI 点评
                        _buildAiCommentCard(service),

                        // 追问区
                        if (service.scores.isNotEmpty &&
                            service.scores.last.followUpQuestion != null &&
                            service.scores.last.followUpQuestion!.isNotEmpty)
                          _buildFollowUpArea(service),
                      ],
                    ],
                  ),
                ),

                // 底部按钮
                _buildBottomButtons(service),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimerBar(InterviewService service) {
    final isThinking = service.isThinkingPhase;
    final color = isThinking ? const Color(0xFF667eea) : const Color(0xFFF7971E);
    final label = isThinking ? '思考时间' : '作答时间';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(
            isThinking ? Icons.psychology : Icons.edit_note,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              service.formatRemainingTime(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: service.remainingSeconds <= 30 ? Colors.red : color,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (isThinking) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => service.switchToAnswering(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '开始作答',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(InterviewService service) {
    final question = service.currentQuestion!;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.category,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '第 ${service.currentQuestionIndex + 1} 题',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(InterviewService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你的回答',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _answerController,
          maxLines: 8,
          minLines: 4,
          decoration: InputDecoration(
            hintText: service.isThinkingPhase
                ? '思考中...准备好后点击「开始作答」'
                : '请输入你的回答...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          enabled: !service.isThinkingPhase,
          onTap: () {
            if (_answerStartTime == 0) {
              _answerStartTime = DateTime.now().millisecondsSinceEpoch;
            }
          },
        ),
      ],
    );
  }

  Widget _buildUserAnswerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF667eea)),
              const SizedBox(width: 6),
              const Text(
                '我的回答',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _answerController.text,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCommentCard(InterviewService service) {
    // 评分信息
    Widget? scoreRow;
    if (service.scores.isNotEmpty) {
      final s = service.scores.last;
      scoreRow = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            _buildScoreBadge('内容', s.contentScore, const Color(0xFF667eea)),
            const SizedBox(width: 8),
            _buildScoreBadge('表达', s.expressionScore, const Color(0xFF43E97B)),
            const SizedBox(width: 8),
            _buildScoreBadge('时间', s.timeScore, const Color(0xFFF7971E)),
            const SizedBox(width: 8),
            _buildScoreBadge('综合', s.totalScore, const Color(0xFFf5576c)),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, size: 16, color: Color(0xFF764ba2)),
              const SizedBox(width: 6),
              const Text(
                'AI 考官点评',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (service.isScoring) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ?scoreRow,
          if (_aiComment.isNotEmpty)
            MarkdownBody(data: _aiComment)
          else if (service.isScoring)
            const Text('正在评分...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, double score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpArea(InterviewService service) {
    final followUp = service.scores.last.followUpQuestion!;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.question_answer, size: 16, color: Color(0xFFF7971E)),
                const SizedBox(width: 6),
                const Text(
                  '考官追问',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF7971E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(followUp, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 12),
            if (!_followUpSubmitted) ...[
              TextField(
                controller: _followUpController,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: '请输入追问回答...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GradientButton(
                  onPressed: _submitFollowUp,
                  label: '提交追问回答',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: 10,
                ),
              ),
            ] else ...[
              GlassCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '追问回答',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _followUpController.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (_followUpComment.isNotEmpty) ...[
                      const Divider(height: 16),
                      const Text(
                        '追问点评',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      MarkdownBody(data: _followUpComment),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(InterviewService service) {
    final isLastQuestion =
        service.currentQuestionIndex >= service.sessionQuestions.length - 1;
    final canProceed = _answerSubmitted && !service.isScoring;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!_answerSubmitted)
              Expanded(
                child: GradientButton(
                  onPressed: service.isThinkingPhase ? null : _submitAnswer,
                  label: '提交回答',
                  icon: Icons.send,
                  width: double.infinity,
                ),
              )
            else
              Expanded(
                child: GradientButton(
                  onPressed: canProceed
                      ? (isLastQuestion ? _goToReport : _nextQuestion)
                      : null,
                  label: isLastQuestion ? '查看报告' : '下一题',
                  icon: isLastQuestion ? Icons.assessment : Icons.arrow_forward,
                  width: double.infinity,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出面试'),
        content: const Text('确定要退出本次模拟面试吗？进度将被取消。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续面试'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InterviewService>().cancelInterview();
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
