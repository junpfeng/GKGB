import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// 通知服务（单例）
/// Android 使用 flutter_local_notifications，Windows 降级为应用内提示
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服务
  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      tz_data.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } else {
      // Windows / 其他平台：标记已初始化，使用应用内提示
      _initialized = true;
    }
  }

  /// 调度通知
  /// [id] 通知 ID：calendarId * 10 + reminderType（0-9）
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    if (Platform.isAndroid) {
      const androidDetails = AndroidNotificationDetails(
        'exam_calendar_reminders',
        '考试提醒',
        channelDescription: '考试日历报名提醒',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    // Windows：不调度系统通知
  }

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    if (Platform.isAndroid) {
      await _plugin.cancel(id: id);
    }
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    if (!_initialized) return;
    if (Platform.isAndroid) {
      await _plugin.cancelAll();
    }
  }

  /// Windows 端应用内提示（在有 context 的地方调用）
  void showInAppNotification(BuildContext context, String title, String body) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 是否支持系统通知
  bool get supportsSystemNotification => Platform.isAndroid;
}
