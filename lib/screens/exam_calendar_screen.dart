import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/exam_calendar_event.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'exam_calendar_detail_screen.dart';
import 'exam_calendar_edit_screen.dart';

/// 考试日历主页（月视图 + 列表 + 筛选）
class ExamCalendarScreen extends StatefulWidget {
  const ExamCalendarScreen({super.key});

  @override
  State<ExamCalendarScreen> createState() => _ExamCalendarScreenState();
}

class _ExamCalendarScreenState extends State<ExamCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 筛选条件
  String? _filterExamType;
  String? _filterProvince;
  bool _subscribedOnly = false;

  static const _examTypes = ['国考', '省考', '事业编', '选调'];
  static const _provinces = [
    '北京', '天津', '上海', '重庆',
    '广东', '江苏', '浙江', '山东', '河南', '四川',
    '湖北', '湖南', '河北', '福建', '安徽', '辽宁',
    '陕西', '江西', '广西', '云南', '贵州', '山西',
    '甘肃', '吉林', '黑龙江', '内蒙古', '新疆', '海南',
    '宁夏', '青海', '西藏',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final service = context.read<CalendarService>();
    await service.loadMonthEvents(_focusedDay.year, _focusedDay.month);
    await service.loadFiltered(
      examType: _filterExamType,
      province: _filterProvince,
      subscribedOnly: _subscribedOnly,
    );
  }

  List<ExamCalendarEvent> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return context.read<CalendarService>().monthEvents[key] ?? [];
  }

  /// 获取选中日期或当前筛选下的考试列表
  List<ExamCalendarEvent> _getDisplayList() {
    final service = context.read<CalendarService>();
    if (_selectedDay != null) {
      final key = DateTime.utc(
          _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      return service.monthEvents[key] ?? [];
    }
    return service.events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试日历'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<CalendarService>(
        builder: (context, service, _) {
          return Column(
            children: [
              // 月视图日历
              _buildCalendar(service),
              // 筛选栏
              _buildFilterBar(),
              // 列表
              Expanded(child: _buildEventList()),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEdit(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendar(CalendarService service) {
    return TableCalendar<ExamCalendarEvent>(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      locale: 'zh_CN',
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF667eea)),
          borderRadius: BorderRadius.circular(16),
        ),
        formatButtonTextStyle: const TextStyle(
          color: Color(0xFF667eea),
          fontSize: 12,
        ),
      ),
      calendarStyle: CalendarStyle(
        markerDecoration: const BoxDecoration(
          color: Color(0xFF667eea),
          shape: BoxShape.circle,
        ),
        markerSize: 6,
        markersMaxCount: 3,
        todayDecoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Color(0xFF667eea),
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        context
            .read<CalendarService>()
            .loadMonthEvents(focusedDay.year, focusedDay.month);
      },
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 考试类型
          Expanded(
            child: _FilterDropdown(
              hint: '考试类型',
              value: _filterExamType,
              items: _examTypes,
              onChanged: (val) {
                setState(() => _filterExamType = val);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          // 省份
          Expanded(
            child: _FilterDropdown(
              hint: '省份',
              value: _filterProvince,
              items: _provinces,
              onChanged: (val) {
                setState(() => _filterProvince = val);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          // 仅关注
          FilterChip(
            label: const Text('关注', style: TextStyle(fontSize: 12)),
            selected: _subscribedOnly,
            selectedColor: const Color(0xFF667eea).withValues(alpha: 0.2),
            onSelected: (val) {
              setState(() => _subscribedOnly = val);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final list = _getDisplayList();
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedDay != null ? '当天无考试安排' : '暂无考试数据',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_selectedDay != null)
              TextButton(
                onPressed: () => setState(() => _selectedDay = null),
                child: const Text('查看全部'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final event = list[index];
        return _ExamEventCard(
          event: event,
          onTap: () => _navigateToDetail(event),
          onSubscribe: () =>
              context.read<CalendarService>().toggleSubscription(event.id!),
        );
      },
    );
  }

  void _navigateToDetail(ExamCalendarEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamCalendarDetailScreen(eventId: event.id!),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToEdit(ExamCalendarEvent? event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamCalendarEditScreen(event: event),
      ),
    ).then((_) => _loadData());
  }
}

/// 筛选下拉框
class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          items: [
            DropdownMenuItem<String>(value: null, child: Text('全部$hint')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 考试事件卡片
class _ExamEventCard extends StatelessWidget {
  final ExamCalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;

  const _ExamEventCard({
    required this.event,
    required this.onTap,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final milestone = event.nextMilestone;
    final typeColor = _getTypeColor(event.examType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 考试类型标签
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: typeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.examType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 考试信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (event.province.isNotEmpty) ...[
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey[500]),
                            Text(
                              event.province,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (event.examDate != null) ...[
                            Icon(Icons.event,
                                size: 12, color: Colors.grey[500]),
                            Text(
                              event.examDate!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ],
                      ),
                      if (milestone != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '距${milestone.label}还有 ${milestone.daysLeft} 天',
                            style: TextStyle(
                              fontSize: 11,
                              color: milestone.daysLeft <= 3
                                  ? Colors.red
                                  : const Color(0xFF667eea),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 关注按钮
                IconButton(
                  icon: Icon(
                    event.subscribed ? Icons.star : Icons.star_border,
                    color: event.subscribed
                        ? Colors.amber
                        : Colors.grey[400],
                    size: 22,
                  ),
                  onPressed: onSubscribe,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getTypeColor(String type) {
    switch (type) {
      case '国考':
        return AppTheme.primaryGradient;
      case '省考':
        return AppTheme.infoGradient;
      case '事业编':
        return AppTheme.successGradient;
      case '选调':
        return AppTheme.warningGradient;
      default:
        return AppTheme.warmGradient;
    }
  }
}
