import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/exam_calendar_event.dart';
import '../models/user_registration.dart';
import 'notification_service.dart';

/// 考试日历服务
class CalendarService extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<ExamCalendarEvent> _events = [];
  List<ExamCalendarEvent> get events => _events;

  Map<DateTime, List<ExamCalendarEvent>> _monthEvents = {};
  Map<DateTime, List<ExamCalendarEvent>> get monthEvents => _monthEvents;

  bool loading = false;

  // ===== 考试 CRUD =====

  /// 加载即将到来的考试
  Future<List<ExamCalendarEvent>> loadUpcoming({int limit = 20}) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT * FROM exam_calendar
      WHERE exam_date >= ? OR reg_end_date >= ? OR interview_date >= ?
      ORDER BY exam_date ASC
      LIMIT ?
    ''', [now, now, now, limit]);
    _events = rows.map((r) => ExamCalendarEvent.fromDb(r)).toList();
    notifyListeners();
    return _events;
  }

  /// 加载所有考试
  Future<List<ExamCalendarEvent>> loadAll() async {
    final db = await _db.database;
    final rows = await db.query('exam_calendar', orderBy: 'exam_date DESC');
    _events = rows.map((r) => ExamCalendarEvent.fromDb(r)).toList();
    notifyListeners();
    return _events;
  }

  /// 加载关注的考试
  Future<List<ExamCalendarEvent>> loadSubscribed() async {
    final db = await _db.database;
    final rows = await db.query(
      'exam_calendar',
      where: 'is_subscribed = 1',
      orderBy: 'exam_date ASC',
    );
    return rows.map((r) => ExamCalendarEvent.fromDb(r)).toList();
  }

  /// 按 ID 获取考试
  Future<ExamCalendarEvent?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'exam_calendar',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return ExamCalendarEvent.fromDb(rows.first);
  }

  /// 加载月事件（查询所有 8 个日期字段）
  Future<Map<DateTime, List<ExamCalendarEvent>>> loadMonthEvents(
      int year, int month) async {
    final db = await _db.database;
    final monthStart = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? '${ year + 1}-01-01' : '$year-${(month + 1).toString().padLeft(2, '0')}-01';

    // 查询所有 8 个日期字段中任一落在月份范围内的记录
    final rows = await db.rawQuery('''
      SELECT * FROM exam_calendar WHERE
        (announcement_date >= ? AND announcement_date < ?) OR
        (reg_start_date >= ? AND reg_start_date < ?) OR
        (reg_end_date >= ? AND reg_end_date < ?) OR
        (payment_deadline >= ? AND payment_deadline < ?) OR
        (ticket_print_date >= ? AND ticket_print_date < ?) OR
        (exam_date >= ? AND exam_date < ?) OR
        (score_release_date >= ? AND score_release_date < ?) OR
        (interview_date >= ? AND interview_date < ?)
    ''', [
      monthStart, nextMonth, monthStart, nextMonth,
      monthStart, nextMonth, monthStart, nextMonth,
      monthStart, nextMonth, monthStart, nextMonth,
      monthStart, nextMonth, monthStart, nextMonth,
    ]);

    final eventsMap = <DateTime, List<ExamCalendarEvent>>{};
    for (final row in rows) {
      final event = ExamCalendarEvent.fromDb(row);
      // 将每个日期字段映射到对应的日期 key
      for (final dateStr in event.allDates) {
        final d = ExamCalendarEvent.tryParseDate(dateStr);
        if (d != null && d.year == year && d.month == month) {
          final key = DateTime.utc(d.year, d.month, d.day);
          eventsMap.putIfAbsent(key, () => []);
          // 避免重复添加同一个事件
          if (!eventsMap[key]!.any((e) => e.id == event.id)) {
            eventsMap[key]!.add(event);
          }
        }
      }
    }

    _monthEvents = eventsMap;
    notifyListeners();
    return eventsMap;
  }

  /// 添加考试
  Future<int> addExam(ExamCalendarEvent event) async {
    final db = await _db.database;
    final id = await db.insert('exam_calendar', event.toDb());
    if (event.isSubscribed == 1) {
      await scheduleReminders(event.copyWith(id: id));
    }
    await loadAll();
    return id;
  }

  /// 更新考试
  Future<void> updateExam(ExamCalendarEvent event) async {
    if (event.id == null) return;
    final db = await _db.database;
    await db.update(
      'exam_calendar',
      event.toDb(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    // 重新调度通知
    await cancelReminders(event.id!);
    if (event.isSubscribed == 1) {
      await scheduleReminders(event);
    }
    await loadAll();
  }

  /// 删除考试（同步删除报名信息 + 取消通知）
  Future<void> deleteExam(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('user_registrations',
          where: 'calendar_id = ?', whereArgs: [id]);
      await txn.delete('exam_calendar', where: 'id = ?', whereArgs: [id]);
    });
    await cancelReminders(id);
    await loadAll();
  }

  /// 切换关注状态
  Future<void> toggleSubscription(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'exam_calendar',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final event = ExamCalendarEvent.fromDb(rows.first);
    final newVal = event.isSubscribed == 1 ? 0 : 1;
    await db.update(
      'exam_calendar',
      {
        'is_subscribed': newVal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (newVal == 1) {
      await scheduleReminders(event.copyWith(isSubscribed: 1));
    } else {
      await cancelReminders(id);
    }
    await loadAll();
  }

  /// 按筛选条件加载考试
  Future<List<ExamCalendarEvent>> loadFiltered({
    String? examType,
    String? province,
    bool? subscribedOnly,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (examType != null && examType.isNotEmpty) {
      conditions.add('exam_type = ?');
      args.add(examType);
    }
    if (province != null && province.isNotEmpty) {
      conditions.add('province = ?');
      args.add(province);
    }
    if (subscribedOnly == true) {
      conditions.add('is_subscribed = 1');
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'exam_calendar',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'exam_date ASC',
    );
    _events = rows.map((r) => ExamCalendarEvent.fromDb(r)).toList();
    notifyListeners();
    return _events;
  }

  // ===== 报名信息 =====

  /// 获取报名信息
  Future<UserRegistration?> getRegistration(int calendarId) async {
    final db = await _db.database;
    final rows = await db.query(
      'user_registrations',
      where: 'calendar_id = ?',
      whereArgs: [calendarId],
    );
    if (rows.isEmpty) return null;
    return UserRegistration.fromDb(rows.first);
  }

  /// 保存报名信息（INSERT OR REPLACE）
  Future<void> saveRegistration(UserRegistration reg) async {
    final db = await _db.database;
    final existing = await db.query(
      'user_registrations',
      where: 'calendar_id = ?',
      whereArgs: [reg.calendarId],
    );
    if (existing.isEmpty) {
      await db.insert('user_registrations', reg.toDb());
    } else {
      await db.update(
        'user_registrations',
        reg.toDb(),
        where: 'calendar_id = ?',
        whereArgs: [reg.calendarId],
      );
    }
    notifyListeners();
  }

  // ===== 通知调度 =====

  /// 为考试设置提醒通知
  /// 通知 ID = calendarId * 10 + reminderType（0-9）
  /// reminderType: 0=报名截止前7天 1=报名截止前3天 2=报名截止前1天
  ///              3=缴费截止前3天 4=缴费截止前1天
  Future<void> scheduleReminders(ExamCalendarEvent event) async {
    if (event.id == null) return;
    final ns = NotificationService.instance;

    // 报名截止提醒
    final regEnd = ExamCalendarEvent.tryParseDate(event.regEndDate);
    if (regEnd != null) {
      await _scheduleIfFuture(ns, event.id! * 10 + 0,
          '${event.name} 报名提醒', '距报名截止还有 7 天', regEnd.subtract(const Duration(days: 7)));
      await _scheduleIfFuture(ns, event.id! * 10 + 1,
          '${event.name} 报名提醒', '距报名截止还有 3 天，请尽快报名', regEnd.subtract(const Duration(days: 3)));
      await _scheduleIfFuture(ns, event.id! * 10 + 2,
          '${event.name} 报名紧急提醒', '明天报名截止！', regEnd.subtract(const Duration(days: 1)));
    }

    // 缴费截止提醒
    final paymentEnd = ExamCalendarEvent.tryParseDate(event.paymentDeadline);
    if (paymentEnd != null) {
      await _scheduleIfFuture(ns, event.id! * 10 + 3,
          '${event.name} 缴费提醒', '距缴费截止还有 3 天', paymentEnd.subtract(const Duration(days: 3)));
      await _scheduleIfFuture(ns, event.id! * 10 + 4,
          '${event.name} 缴费紧急提醒', '明天缴费截止！', paymentEnd.subtract(const Duration(days: 1)));
    }
  }

  Future<void> _scheduleIfFuture(
      NotificationService ns, int id, String title, String body, DateTime date) async {
    if (date.isAfter(DateTime.now())) {
      await ns.scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
      );
    }
  }

  /// 取消考试的所有通知
  Future<void> cancelReminders(int calendarId) async {
    final ns = NotificationService.instance;
    for (int i = 0; i < 10; i++) {
      await ns.cancelNotification(calendarId * 10 + i);
    }
  }

  // ===== 预置数据导入 =====

  /// 幂等导入预置考试数据（表非空则跳过）
  Future<void> importPresetData() async {
    final db = await _db.database;
    final count = await db.rawQuery('SELECT COUNT(*) as cnt FROM exam_calendar');
    final existing = (count.first['cnt'] as int?) ?? 0;
    if (existing > 0) return; // 幂等：非空跳过

    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/exam_calendar_sample.json');
      final List<dynamic> items = json.decode(jsonStr);
      await db.transaction((txn) async {
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          txn.insert('exam_calendar', {
            'name': map['name'],
            'exam_type': map['exam_type'],
            'province': map['province'] ?? '',
            'announcement_date': map['announcement_date'],
            'reg_start_date': map['reg_start_date'],
            'reg_end_date': map['reg_end_date'],
            'payment_deadline': map['payment_deadline'],
            'ticket_print_date': map['ticket_print_date'],
            'exam_date': map['exam_date'],
            'score_release_date': map['score_release_date'],
            'interview_date': map['interview_date'],
            'source_url': map['source_url'] ?? '',
            'notes': map['notes'] ?? '',
            'is_subscribed': 0,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      debugPrint('导入预置考试数据失败: $e');
    }
  }
}
