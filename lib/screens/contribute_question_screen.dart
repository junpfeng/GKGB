import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../services/real_exam_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

/// 贡献真题页面：文字粘贴 → AI 解析 → 预览编辑 → 确认入库
class ContributeQuestionScreen extends StatefulWidget {
  const ContributeQuestionScreen({super.key});

  @override
  State<ContributeQuestionScreen> createState() =>
      _ContributeQuestionScreenState();
}

class _ContributeQuestionScreenState extends State<ContributeQuestionScreen> {
  final _textController = TextEditingController();

  // AI 解析状态
  bool _isParsing = false;
  String _parseBuffer = '';
  List<_EditableQuestion> _parsedQuestions = [];
  String? _parseError;

  // 入库元数据
  String _region = '';
  int _year = DateTime.now().year;
  String _examType = '国考';
  String _examSession = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startParsing() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴真题文本')),
      );
      return;
    }

    setState(() {
      _isParsing = true;
      _parseBuffer = '';
      _parsedQuestions = [];
      _parseError = null;
    });

    try {
      final rs = context.read<RealExamService>();
      final stream = rs.contributeQuestion(text);

      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() => _parseBuffer += chunk);
      }

      // 解析完成，尝试提取 JSON
      _tryParseJson();
    } catch (e) {
      if (mounted) {
        setState(() {
          _parseError = '解析失败：$e';
          _isParsing = false;
        });
      }
    }
  }

  void _tryParseJson() {
    try {
      // 尝试从 buffer 中提取 JSON 数组
      var jsonStr = _parseBuffer.trim();
      // 去除可能的 markdown 代码块标记
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json').last.split('```').first.trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].trim();
      }

      final decoded = jsonDecode(jsonStr);
      final list = decoded is List ? decoded : [decoded];

      setState(() {
        _parsedQuestions = list.map((item) {
          final map = item as Map<String, dynamic>;
          return _EditableQuestion(
            subject: map['subject'] as String? ?? '行测',
            category: map['category'] as String? ?? '',
            type: map['type'] as String? ?? 'single',
            content: map['content'] as String? ?? '',
            options: (map['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            answer: map['answer'] as String? ?? '',
            explanation: map['explanation'] as String? ?? '',
            difficulty: (map['difficulty'] as int?) ?? 3,
          );
        }).toList();
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _parseError = 'JSON 解析失败，请检查 AI 返回结果';
        _isParsing = false;
      });
    }
  }

  Future<void> _confirmContribution() async {
    if (_parsedQuestions.isEmpty) return;

    final rs = context.read<RealExamService>();
    int successCount = 0;

    for (final eq in _parsedQuestions) {
      final question = Question(
        subject: eq.subject,
        category: eq.category,
        type: eq.type,
        content: eq.content,
        options: eq.options,
        answer: eq.answer,
        explanation: eq.explanation,
        difficulty: eq.difficulty,
        region: _region,
        year: _year,
        examType: _examType,
        examSession: _examSession,
        isRealExam: 1,
      );
      await rs.confirmContribution(question);
      successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功入库 $successCount 道真题')),
      );
      setState(() {
        _parsedQuestions = [];
        _parseBuffer = '';
        _textController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('贡献真题')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 元数据选择
            _buildMetadataSection(),
            const SizedBox(height: 16),
            // 文字输入区
            _buildInputSection(),
            const SizedBox(height: 16),
            // AI 解析结果
            if (_isParsing) _buildParsingIndicator(),
            if (_parseError != null) _buildErrorCard(),
            if (_parsedQuestions.isNotEmpty) _buildParsedResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '真题信息',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _examType,
                  decoration: const InputDecoration(
                    labelText: '考试类型',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '国考', child: Text('国考')),
                    DropdownMenuItem(value: '省考', child: Text('省考')),
                    DropdownMenuItem(value: '事业编', child: Text('事业编')),
                    DropdownMenuItem(value: '选调', child: Text('选调')),
                  ],
                  onChanged: (v) => setState(() => _examType = v ?? '国考'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: _region,
                  decoration: const InputDecoration(
                    labelText: '地区',
                    hintText: '如：全国、北京',
                    isDense: true,
                  ),
                  onChanged: (v) => _region = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _year.toString(),
                  decoration: const InputDecoration(
                    labelText: '年份',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _year = int.tryParse(v) ?? _year,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _examSession.isEmpty ? null : _examSession,
                  decoration: const InputDecoration(
                    labelText: '场次',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('不限')),
                    DropdownMenuItem(value: '上半年', child: Text('上半年')),
                    DropdownMenuItem(value: '下半年', child: Text('下半年')),
                  ],
                  onChanged: (v) => setState(() => _examSession = v ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '粘贴真题文本',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '将真题文本粘贴到此处，AI 将自动解析为结构化题目...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: _isParsing ? null : _startParsing,
            label: _isParsing ? '正在解析...' : 'AI 解析',
            icon: Icons.auto_awesome,
            isLoading: _isParsing,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildParsingIndicator() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
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
              Text('AI 正在解析...', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          if (_parseBuffer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _parseBuffer,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        backgroundColor: Colors.red[50],
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _parseError!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '解析结果（${_parsedQuestions.length}题）',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ..._parsedQuestions.asMap().entries.map((entry) {
          final i = entry.key;
          final eq = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EditableQuestionCard(
              index: i + 1,
              question: eq,
              onChanged: (updated) {
                setState(() => _parsedQuestions[i] = updated);
              },
              onDelete: () {
                setState(() => _parsedQuestions.removeAt(i));
              },
            ),
          );
        }),
        const SizedBox(height: 12),
        GradientButton(
          onPressed: _confirmContribution,
          label: '确认入库（${_parsedQuestions.length}题）',
          icon: Icons.check_circle,
          width: double.infinity,
          gradient: AppTheme.successGradient,
        ),
      ],
    );
  }
}

/// 可编辑的解析结果
class _EditableQuestion {
  String subject;
  String category;
  String type;
  String content;
  List<String> options;
  String answer;
  String explanation;
  int difficulty;

  _EditableQuestion({
    required this.subject,
    required this.category,
    required this.type,
    required this.content,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.difficulty,
  });
}

/// 可编辑题目卡片
class _EditableQuestionCard extends StatefulWidget {
  final int index;
  final _EditableQuestion question;
  final ValueChanged<_EditableQuestion> onChanged;
  final VoidCallback onDelete;

  const _EditableQuestionCard({
    required this.index,
    required this.question,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_EditableQuestionCard> createState() => _EditableQuestionCardState();
}

class _EditableQuestionCardState extends State<_EditableQuestionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目头
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.content,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 16),
            // 科目和分类
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: q.subject,
                    decoration: const InputDecoration(
                      labelText: '科目',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      q.subject = v;
                      widget.onChanged(q);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: q.category,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      q.category = v;
                      widget.onChanged(q);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 题目内容
            TextFormField(
              initialValue: q.content,
              decoration: const InputDecoration(
                labelText: '题目内容',
                isDense: true,
              ),
              maxLines: 3,
              onChanged: (v) {
                q.content = v;
                widget.onChanged(q);
              },
            ),
            const SizedBox(height: 8),
            // 选项
            if (q.options.isNotEmpty)
              ...q.options.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextFormField(
                    initialValue: entry.value,
                    decoration: InputDecoration(
                      labelText: '选项${entry.key + 1}',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      q.options[entry.key] = v;
                      widget.onChanged(q);
                    },
                  ),
                );
              }),
            const SizedBox(height: 8),
            // 答案和难度
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: q.answer,
                    decoration: const InputDecoration(
                      labelText: '正确答案',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      q.answer = v;
                      widget.onChanged(q);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: q.difficulty.clamp(1, 5),
                    decoration: const InputDecoration(
                      labelText: '难度',
                      isDense: true,
                    ),
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      q.difficulty = v ?? 3;
                      widget.onChanged(q);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 解析
            TextFormField(
              initialValue: q.explanation,
              decoration: const InputDecoration(
                labelText: '解析',
                isDense: true,
              ),
              maxLines: 3,
              onChanged: (v) {
                q.explanation = v;
                widget.onChanged(q);
              },
            ),
          ],
        ],
      ),
    );
  }
}
