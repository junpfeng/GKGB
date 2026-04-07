import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_calendar_event.dart';
import '../models/user_registration.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'exam_calendar_edit_screen.dart';

/// 考试日历详情页（时间线 + 报名信息）
class ExamCalendarDetailScreen extends StatefulWidget {
  final int eventId;

  const ExamCalendarDetailScreen({super.key, required this.eventId});

  @override
  State<ExamCalendarDetailScreen> createState() =>
      _ExamCalendarDetailScreenState();
}

class _ExamCalendarDetailScreenState extends State<ExamCalendarDetailScreen> {
  ExamCalendarEvent? _event;
  bool _loading = true;

  // 报名信息编辑控制器
  final _ticketCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _seatCtrl = TextEditingController();
  final _regNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _ticketCtrl.dispose();
    _locationCtrl.dispose();
    _seatCtrl.dispose();
    _regNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final service = context.read<CalendarService>();
    final event = await service.getById(widget.eventId);
    final reg = await service.getRegistration(widget.eventId);
    if (mounted) {
      setState(() {
        _event = event;
        _loading = false;
        if (reg != null) {
          _ticketCtrl.text = reg.ticketNumber;
          _locationCtrl.text = reg.examLocation;
          _seatCtrl.text = reg.seatNumber;
          _regNotesCtrl.text = reg.notes;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_event?.name ?? '考试详情'),
        actions: [
          if (_event != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEdit(),
            ),
          if (_event != null)
            IconButton(
              icon: Icon(
                _event!.subscribed ? Icons.star : Icons.star_border,
                color: _event!.subscribed ? Colors.amber : null,
              ),
              onPressed: _toggleSubscribe,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? const Center(child: Text('考试不存在'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCountdown(),
                    const SizedBox(height: 16),
                    _buildTimeline(),
                    const SizedBox(height: 16),
                    _buildRegistrationInfo(),
                    const SizedBox(height: 16),
                    _buildExamInfo(),
                    const SizedBox(height: 24),
                    _buildDeleteButton(),
                  ],
                ),
    );
  }

  /// 倒计时卡片
  Widget _buildCountdown() {
    final milestone = _event!.nextMilestone;
    if (milestone == null) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green[400], size: 28),
            const SizedBox(width: 12),
            const Text(
              '所有时间节点已过',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return GradientCard(
      gradient: milestone.daysLeft <= 3
          ? AppTheme.warmGradient
          : AppTheme.primaryGradient,
      borderRadius: AppTheme.radiusMedium,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '距${milestone.label}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${milestone.daysLeft}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '天',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 时间线可视化（纵向时间轴）
  Widget _buildTimeline() {
    final milestones = <({String label, String? dateStr, DateTime? date})>[
      (label: '公告发布', dateStr: _event!.announcementDate, date: ExamCalendarEvent.tryParseDate(_event!.announcementDate)),
      (label: '报名开始', dateStr: _event!.regStartDate, date: ExamCalendarEvent.tryParseDate(_event!.regStartDate)),
      (label: '报名截止', dateStr: _event!.regEndDate, date: ExamCalendarEvent.tryParseDate(_event!.regEndDate)),
      (label: '缴费截止', dateStr: _event!.paymentDeadline, date: ExamCalendarEvent.tryParseDate(_event!.paymentDeadline)),
      (label: '准考证打印', dateStr: _event!.ticketPrintDate, date: ExamCalendarEvent.tryParseDate(_event!.ticketPrintDate)),
      (label: '笔试', dateStr: _event!.examDate, date: ExamCalendarEvent.tryParseDate(_event!.examDate)),
      (label: '成绩公布', dateStr: _event!.scoreReleaseDate, date: ExamCalendarEvent.tryParseDate(_event!.scoreReleaseDate)),
      (label: '面试', dateStr: _event!.interviewDate, date: ExamCalendarEvent.tryParseDate(_event!.interviewDate)),
    ];

    final now = DateTime.now();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时间线',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...List.generate(milestones.length, (index) {
            final m = milestones[index];
            final isLast = index == milestones.length - 1;

            // 状态：已过/即将/未来/未设置
            _TimelineStatus status;
            Color nodeColor;
            if (m.date == null) {
              status = _TimelineStatus.unset;
              nodeColor = Colors.grey[300]!;
            } else if (m.date!.isBefore(now)) {
              status = _TimelineStatus.past;
              nodeColor = Colors.green;
            } else if (m.date!.difference(now).inDays <= 7) {
              status = _TimelineStatus.upcoming;
              nodeColor = Colors.orange;
            } else {
              status = _TimelineStatus.future;
              nodeColor = const Color(0xFF667eea);
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间轴线 + 节点
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: nodeColor,
                            shape: BoxShape.circle,
                            border: status == _TimelineStatus.upcoming
                                ? Border.all(color: Colors.orange, width: 2)
                                : null,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey[300],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 内容
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: status == _TimelineStatus.upcoming
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: status == _TimelineStatus.unset
                                  ? Colors.grey
                                  : null,
                            ),
                          ),
                          Text(
                            m.dateStr ?? '待定',
                            style: TextStyle(
                              fontSize: 13,
                              color: status == _TimelineStatus.unset
                                  ? Colors.grey[400]
                                  : status == _TimelineStatus.past
                                      ? Colors.grey
                                      : null,
                              fontWeight: status == _TimelineStatus.upcoming
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 报名信息编辑区
  Widget _buildRegistrationInfo() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '报名信息',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _saveRegistration,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildField('准考证号', _ticketCtrl, Icons.badge),
          const SizedBox(height: 8),
          _buildField('考场地址', _locationCtrl, Icons.location_on),
          const SizedBox(height: 8),
          _buildField('座位号', _seatCtrl, Icons.event_seat),
          const SizedBox(height: 8),
          _buildField('备注', _regNotesCtrl, Icons.note, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  /// 考试基本信息
  Widget _buildExamInfo() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '考试信息',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '考试类型', value: _event!.examType),
          if (_event!.province.isNotEmpty)
            _InfoRow(label: '省份', value: _event!.province),
          if (_event!.sourceUrl.isNotEmpty)
            _InfoRow(label: '公告链接', value: _event!.sourceUrl),
          if (_event!.notes.isNotEmpty)
            _InfoRow(label: '备注', value: _event!.notes),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
        label: const Text('删除此考试', style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Future<void> _saveRegistration() async {
    final reg = UserRegistration(
      calendarId: widget.eventId,
      ticketNumber: _ticketCtrl.text.trim(),
      examLocation: _locationCtrl.text.trim(),
      seatNumber: _seatCtrl.text.trim(),
      notes: _regNotesCtrl.text.trim(),
    );
    await context.read<CalendarService>().saveRegistration(reg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('报名信息已保存')),
      );
    }
  }

  Future<void> _toggleSubscribe() async {
    await context.read<CalendarService>().toggleSubscription(widget.eventId);
    await _loadData();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后报名信息和通知提醒将一并移除，确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CalendarService>().deleteExam(widget.eventId);
      if (mounted) Navigator.pop(context);
    }
  }

  void _navigateToEdit() {
    if (_event == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ExamCalendarEditScreen(event: _event),
          ),
        )
        .then((_) => _loadData());
  }
}

enum _TimelineStatus { past, upcoming, future, unset }

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
