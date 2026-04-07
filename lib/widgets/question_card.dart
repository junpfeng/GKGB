import 'package:flutter/material.dart';
import '../models/question.dart';

/// 题目卡片组件
/// 支持单选、多选、判断、主观题
class QuestionCard extends StatelessWidget {
  final Question question;
  final int index;             // 题号（1-based）
  final String? userAnswer;    // 当前选择
  final bool showAnswer;       // 是否显示答案解析
  final bool readOnly;         // 只读模式（查看错题/解析时）
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题号 + 类型标签
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '第 $index 题',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TypeBadge(type: question.type),
                const Spacer(),
                Text(
                  '难度：${'★' * question.difficulty}',
                  style: TextStyle(fontSize: 12, color: Colors.amber[700]),
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
          ],
        ),
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
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              isCorrect ? '回答正确' : '回答错误',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '正确答案：${question.answer}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (question.explanation != null && question.explanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('解析：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
    final (label, color) = switch (type) {
      'single' => ('单选', Colors.blue),
      'multiple' => ('多选', Colors.purple),
      'judge' => ('判断', Colors.orange),
      'subjective' => ('主观', Colors.red),
      _ => ('未知', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
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

        Color? tileColor;
        if (isCorrect) tileColor = Colors.green.withValues(alpha: 0.1);
        if (isWrong) tileColor = Colors.red.withValues(alpha: 0.1);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: isSelected ? 1.5 : 0,
            ),
          ),
          child: GestureDetector(
            onTap: readOnly ? null : () => onChanged?.call(label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  // 自定义单选标记，避免使用已弃用的 Radio.groupValue
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$label. ${options[i]}', style: const TextStyle(fontSize: 14))),
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
        final isWrong = showAnswer && isSelected && !correctSet.contains(label);

        Color? tileColor;
        if (isCorrect) tileColor = Colors.green.withValues(alpha: 0.1);
        if (isWrong) tileColor = Colors.red.withValues(alpha: 0.1);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(8),
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
                    // 按字母顺序排列
                    final sorted = newSet.toList()..sort();
                    onChanged?.call(sorted.join(''));
                  },
            title: Text('$label. ${options[i]}', style: const TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
    Color? bgColor;
    Color? borderColor;
    if (isCorrect) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      borderColor = Colors.green;
    } else if (isWrong) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      borderColor = Colors.red;
    } else if (selected) {
      borderColor = Theme.of(context).colorScheme.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? Colors.grey.withValues(alpha: 0.3),
            width: selected || isCorrect ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: isCorrect
                  ? Colors.green[700]
                  : isWrong
                      ? Colors.red[700]
                      : selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
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
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
  }
}
