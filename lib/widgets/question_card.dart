import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../services/llm/llm_manager.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'ai_chat_dialog.dart';

/// 题目卡片组件
/// 支持单选、多选、判断、主观题
class QuestionCard extends StatelessWidget {
  final Question question;
  final int index;
  final String? userAnswer;
  final bool showAnswer;
  final bool readOnly;
  final void Function(String answer)? onAnswerChanged;

  const QuestionCard({
    super.key,
    required this.question,
    required this.index,
    this.userAnswer,
    this.showAnswer = false,
    this.readOnly = false,
    this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题号 + 类型标签
          Row(
            children: [
              // 渐变题号徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '第 $index 题',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(type: question.type),
              const Spacer(),
              Text(
                '难度：${'★' * question.difficulty}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFF7971E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 题目内容
          Text(
            question.content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 12),
          // 选项区域
          _buildOptions(context),
          // 答案解析（答题后显示）
          if (showAnswer) ...[
            const Divider(height: 24),
            _buildAnswerSection(context),
          ],
          // 主观题显示 AI 批改按钮
          if (question.type == 'subjective' &&
              userAnswer != null &&
              userAnswer!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _AiGradeButton(question: question, userAnswer: userAnswer!),
          ],
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    switch (question.type) {
      case 'single':
        return _SingleChoiceOptions(
          options: question.options,
          answer: question.answer,
          userAnswer: userAnswer,
          showAnswer: showAnswer,
          readOnly: readOnly,
          onChanged: onAnswerChanged,
        );
      case 'multiple':
        return _MultipleChoiceOptions(
          options: question.options,
          answer: question.answer,
          userAnswer: userAnswer,
          showAnswer: showAnswer,
          readOnly: readOnly,
          onChanged: onAnswerChanged,
        );
      case 'judge':
        return _JudgeOptions(
          answer: question.answer,
          userAnswer: userAnswer,
          showAnswer: showAnswer,
          readOnly: readOnly,
          onChanged: onAnswerChanged,
        );
      case 'subjective':
        return _SubjectiveInput(
          userAnswer: userAnswer,
          readOnly: readOnly,
          onChanged: onAnswerChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAnswerSection(BuildContext context) {
    final isCorrect = userAnswer != null &&
        userAnswer!.trim().toUpperCase() == question.answer.trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 对/错提示条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isCorrect ? AppTheme.successGradient : AppTheme.warmGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? '回答正确' : '回答错误',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '正确答案：${question.answer}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (question.explanation != null &&
            question.explanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '解析：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  question.explanation!,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, gradient) = switch (type) {
      'single' => ('单选', AppTheme.primaryGradient),
      'multiple' => (
          '多选',
          const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFF4776E6)])
        ),
      'judge' => ('判断', AppTheme.warningGradient),
      'subjective' => ('主观', AppTheme.warmGradient),
      _ => (
          '未知',
          const LinearGradient(colors: [Colors.grey, Colors.grey])
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }
}

class _SingleChoiceOptions extends StatelessWidget {
  final List<String> options;
  final String answer;
  final String? userAnswer;
  final bool showAnswer;
  final bool readOnly;
  final void Function(String)? onChanged;

  const _SingleChoiceOptions({
    required this.options,
    required this.answer,
    this.userAnswer,
    this.showAnswer = false,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Column(
      children: List.generate(options.length, (i) {
        final label = labels[i];
        final isSelected = userAnswer == label;
        final isCorrect = showAnswer && answer == label;
        final isWrong = showAnswer && isSelected && answer != label;

        // 渐变高亮选项
        Color? bgColor;
        if (isCorrect) bgColor = const Color(0xFF43E97B).withValues(alpha: 0.12);
        if (isWrong) bgColor = const Color(0xFFf5576c).withValues(alpha: 0.12);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF667eea), width: 1.5)
                : Border.all(
                    color: Colors.grey.withValues(alpha: 0.15), width: 1),
          ),
          child: GestureDetector(
            onTap: readOnly ? null : () => onChanged?.call(label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 自定义单选标记
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$label. ${options[i]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isCorrect
                            ? const Color(0xFF2E7D32)
                            : isWrong
                                ? const Color(0xFFB71C1C)
                                : null,
                        fontWeight: isSelected ? FontWeight.w500 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MultipleChoiceOptions extends StatelessWidget {
  final List<String> options;
  final String answer;
  final String? userAnswer;
  final bool showAnswer;
  final bool readOnly;
  final void Function(String)? onChanged;

  const _MultipleChoiceOptions({
    required this.options,
    required this.answer,
    this.userAnswer,
    this.showAnswer = false,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    final selected = (userAnswer ?? '').split('').toSet();
    final correctSet = answer.split('').toSet();

    return Column(
      children: List.generate(options.length, (i) {
        final label = labels[i];
        final isSelected = selected.contains(label);
        final isCorrect = showAnswer && correctSet.contains(label);
        final isWrong =
            showAnswer && isSelected && !correctSet.contains(label);

        Color? bgColor;
        if (isCorrect) bgColor = const Color(0xFF43E97B).withValues(alpha: 0.12);
        if (isWrong) bgColor = const Color(0xFFf5576c).withValues(alpha: 0.12);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: readOnly
                ? null
                : (checked) {
                    final newSet = Set<String>.from(selected);
                    if (checked == true) {
                      newSet.add(label);
                    } else {
                      newSet.remove(label);
                    }
                    final sorted = newSet.toList()..sort();
                    onChanged?.call(sorted.join(''));
                  },
            title: Text(
              '$label. ${options[i]}',
              style: TextStyle(
                fontSize: 14,
                color: isCorrect
                    ? const Color(0xFF2E7D32)
                    : isWrong
                        ? const Color(0xFFB71C1C)
                        : null,
              ),
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            activeColor: const Color(0xFF667eea),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }),
    );
  }
}

class _JudgeOptions extends StatelessWidget {
  final String answer;
  final String? userAnswer;
  final bool showAnswer;
  final bool readOnly;
  final void Function(String)? onChanged;

  const _JudgeOptions({
    required this.answer,
    this.userAnswer,
    this.showAnswer = false,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _JudgeButton(
            label: '正确 (√)',
            value: '√',
            selected: userAnswer == '√',
            isCorrect: showAnswer && answer == '√',
            isWrong: showAnswer && userAnswer == '√' && answer != '√',
            onTap: readOnly ? null : () => onChanged?.call('√'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _JudgeButton(
            label: '错误 (×)',
            value: '×',
            selected: userAnswer == '×',
            isCorrect: showAnswer && answer == '×',
            isWrong: showAnswer && userAnswer == '×' && answer != '×',
            onTap: readOnly ? null : () => onChanged?.call('×'),
          ),
        ),
      ],
    );
  }
}

class _JudgeButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  const _JudgeButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.isCorrect,
    required this.isWrong,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    LinearGradient? gradient;
    if (isCorrect) gradient = AppTheme.successGradient;
    if (isWrong) gradient = AppTheme.warmGradient;
    if (selected && !isCorrect && !isWrong) gradient = AppTheme.primaryGradient;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? null : null,
          borderRadius: BorderRadius.circular(10),
          border: gradient == null
              ? Border.all(color: Colors.grey.withValues(alpha: 0.25), width: 1)
              : null,
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: gradient != null ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectiveInput extends StatefulWidget {
  final String? userAnswer;
  final bool readOnly;
  final void Function(String)? onChanged;

  const _SubjectiveInput({
    this.userAnswer,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<_SubjectiveInput> createState() => _SubjectiveInputState();
}

class _SubjectiveInputState extends State<_SubjectiveInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.userAnswer);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      maxLines: 6,
      decoration: InputDecoration(
        hintText: '请在此输入答案...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
  }
}

/// 主观题 AI 批改按钮
class _AiGradeButton extends StatelessWidget {
  final Question question;
  final String userAnswer;

  const _AiGradeButton({
    required this.question,
    required this.userAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showGrading(context),
        icon: const Icon(Icons.smart_toy, size: 16),
        label: const Text('AI 批改'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  void _showGrading(BuildContext context) {
    final llmManager = context.read<LlmManager>();

    if (!llmManager.hasProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在"我的"页面配置 AI 模型')),
      );
      return;
    }

    AiChatDialog.show(
      context,
      initialPrompt: '''请批改以下主观题答案：

【题目】
${question.content}

【参考答案要点】
${question.answer.isNotEmpty ? question.answer : "（无参考答案）"}

【考生答案】
${userAnswer.trim().isEmpty ? "（未作答）" : userAnswer}

请从以下维度批改：
1. 要点覆盖（是否涵盖核心要点）
2. 逻辑结构（条理是否清晰）
3. 语言表达（是否规范得体）
4. 综合评分（满分100分，给出估分区间）
5. 改进建议（具体、可操作）''',
      title: 'AI 批改',
    );
  }
}
