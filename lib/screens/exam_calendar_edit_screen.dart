import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_calendar_event.dart';
import '../services/calendar_service.dart';

/// 添加/编辑考试表单
class ExamCalendarEditScreen extends StatefulWidget {
  final ExamCalendarEvent? event;

  const ExamCalendarEditScreen({super.key, this.event});

  @override
  State<ExamCalendarEditScreen> createState() => _ExamCalendarEditScreenState();
}

class _ExamCalendarEditScreenState extends State<ExamCalendarEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sourceUrlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _examType = '国考';
  String _province = '';

  // 8 个日期字段
  String? _announcementDate;
  String? _regStartDate;
  String? _regEndDate;
  String? _paymentDeadline;
  String? _ticketPrintDate;
  String? _examDate;
  String? _scoreReleaseDate;
  String? _interviewDate;

  bool _isSubscribed = false;
  bool _saving = false;

  bool get _isEditing => widget.event != null;

  static const _examTypes = ['国考', '省考', '事业编', '选调'];
  static const _provinces = [
    '', '北京', '天津', '上海', '重庆',
    '广东', '江苏', '浙江', '山东', '河南', '四川',
    '湖北', '湖南', '河北', '福建', '安徽', '辽宁',
    '陕西', '江西', '广西', '云南', '贵州', '山西',
    '甘肃', '吉林', '黑龙江', '内蒙古', '新疆', '海南',
    '宁夏', '青海', '西藏',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.event!;
      _nameCtrl.text = e.name;
      _examType = e.examType;
      _province = e.province;
      _announcementDate = e.announcementDate;
      _regStartDate = e.regStartDate;
      _regEndDate = e.regEndDate;
      _paymentDeadline = e.paymentDeadline;
      _ticketPrintDate = e.ticketPrintDate;
      _examDate = e.examDate;
      _scoreReleaseDate = e.scoreReleaseDate;
      _interviewDate = e.interviewDate;
      _sourceUrlCtrl.text = e.sourceUrl;
      _notesCtrl.text = e.notes;
      _isSubscribed = e.subscribed;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sourceUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑考试' : '添加考试'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 考试名称
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '考试名称 *',
                      hintText: '例：2025年国家公务员考试',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入考试名称' : null,
                  ),
                  const SizedBox(height: 16),

                  // 考试类型 + 省份
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _examType,
                          decoration: const InputDecoration(
                            labelText: '考试类型',
                            border: OutlineInputBorder(),
                          ),
                          items: _examTypes
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _examType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _province,
                          decoration: const InputDecoration(
                            labelText: '省份',
                            border: OutlineInputBorder(),
                          ),
                          items: _provinces
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.isEmpty ? '全国' : e),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _province = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 8 个日期选择器
                  Text(
                    '时间节点',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildDatePicker('公告发布', _announcementDate,
                      (d) => setState(() => _announcementDate = d)),
                  _buildDatePicker('报名开始', _regStartDate,
                      (d) => setState(() => _regStartDate = d)),
                  _buildDatePicker('报名截止', _regEndDate,
                      (d) => setState(() => _regEndDate = d)),
                  _buildDatePicker('缴费截止', _paymentDeadline,
                      (d) => setState(() => _paymentDeadline = d)),
                  _buildDatePicker('准考证打印', _ticketPrintDate,
                      (d) => setState(() => _ticketPrintDate = d)),
                  _buildDatePicker(
                      '笔试', _examDate, (d) => setState(() => _examDate = d)),
                  _buildDatePicker('成绩公布', _scoreReleaseDate,
                      (d) => setState(() => _scoreReleaseDate = d)),
                  _buildDatePicker('面试', _interviewDate,
                      (d) => setState(() => _interviewDate = d)),

                  const SizedBox(height: 16),
                  // 公告链接
                  TextFormField(
                    controller: _sourceUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '公告链接',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 备注
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 关注开关
                  SwitchListTile(
                    title: const Text('关注此考试'),
                    subtitle: const Text('关注后将收到报名和缴费提醒'),
                    value: _isSubscribed,
                    onChanged: (v) => setState(() => _isSubscribed = v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDatePicker(
      String label, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _pickDate(label, value, onChanged),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onChanged(null),
                  ),
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
              ],
            ),
          ),
          child: Text(
            value ?? '点击选择日期',
            style: TextStyle(
              color: value != null ? null : Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(
      String label, String? current, ValueChanged<String?> onChanged) async {
    DateTime initial = DateTime.now();
    if (current != null) {
      try {
        initial = DateTime.parse(current);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: '选择$label日期',
    );
    if (picked != null) {
      onChanged(picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final service = context.read<CalendarService>();

    final event = ExamCalendarEvent(
      id: widget.event?.id,
      name: _nameCtrl.text.trim(),
      examType: _examType,
      province: _province,
      announcementDate: _announcementDate,
      regStartDate: _regStartDate,
      regEndDate: _regEndDate,
      paymentDeadline: _paymentDeadline,
      ticketPrintDate: _ticketPrintDate,
      examDate: _examDate,
      scoreReleaseDate: _scoreReleaseDate,
      interviewDate: _interviewDate,
      sourceUrl: _sourceUrlCtrl.text.trim(),
      isSubscribed: _isSubscribed ? 1 : 0,
      notes: _notesCtrl.text.trim(),
    );

    if (_isEditing) {
      await service.updateExam(event);
    } else {
      await service.addExam(event);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
