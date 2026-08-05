import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/task.dart';

/// Schedules local reminders for tasks.
/// v2.0.0: Removed schedule item support (not part of v2.0.0 spec).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Task reminders',
    channelDescription: 'Reminders for upcoming tasks',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    _initialized = await _plugin.initialize(settings) ?? false;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  Future<void> refreshAll({required List<Task> tasks}) async {
    await initialize();
    for (final task in tasks) {
      await scheduleTask(task);
    }
  }

  Future<void> scheduleTask(Task task) async {
    await initialize();
    final notificationId = _id('task:${task.id}');
    if (task.dueDate == null ||
        task.archived ||
        task.status == TaskStatus.done ||
        task.status == TaskStatus.archived) {
      await _plugin.cancel(notificationId);
      return;
    }

    final dueDate = task.dueDate!;
    final dueTime = task.dueTime;
    final reminder = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTime?.hour ?? 9,
      dueTime?.minute ?? 0,
    );
    await _schedule(
      id: notificationId,
      title: 'Task due',
      body: task.title,
      dateTime: reminder,
      payload: 'task:${task.id}',
    );
  }

  Future<void> cancelTask(String id) => _plugin.cancel(_id('task:$id'));

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    required String payload,
  }) async {
    if (!dateTime.isAfter(DateTime.now())) {
      await _plugin.cancel(id);
      return;
    }
    try {
      final when = tz.TZDateTime.from(dateTime.toUtc(), tz.UTC);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to schedule notification: $error');
      }
    }
  }

  int _id(String value) => value.hashCode & 0x7fffffff;
}
