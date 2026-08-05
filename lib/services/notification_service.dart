import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/schedule_item.dart';
import '../data/models/task.dart';

/// Schedules local reminders for incomplete tasks and schedule items.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Task and schedule reminders',
    channelDescription: 'Reminders for upcoming tasks and schedule items',
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

  Future<void> refreshAll({
    required List<Task> tasks,
    required List<ScheduleItem> schedule,
  }) async {
    await initialize();
    for (final task in tasks) {
      await scheduleTask(task);
    }
    for (final item in schedule) {
      await scheduleItem(item);
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

  Future<void> scheduleItem(ScheduleItem item) async {
    await initialize();
    final notificationId = _id('schedule:${item.id}');
    if (item.done) {
      await _plugin.cancel(notificationId);
      return;
    }
    await _schedule(
      id: notificationId,
      title: 'Upcoming reminder',
      body: item.title,
      dateTime: item.dateTime,
      payload: 'schedule:${item.id}',
    );
  }

  Future<void> cancelTask(String id) => _plugin.cancel(_id('task:$id'));

  Future<void> cancelSchedule(String id) => _plugin.cancel(_id('schedule:$id'));

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
      // Convert the device-local instant to UTC. Android still fires at the
      // correct instant, without requiring a separate timezone plugin.
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
