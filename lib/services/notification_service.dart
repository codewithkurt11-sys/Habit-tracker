import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/schedule_item.dart';
import '../data/models/task.dart';
import '../data/models/habit.dart';

/// Central local-notification scheduler.
///
/// Tasks can have multiple "before due" reminders. Habits can have multiple
/// time-of-day reminders on their scheduled weekdays. Empty reminder lists
/// retain the legacy behavior of one task-due notification so old data keeps
/// working without migration surprises.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Task and habit reminders',
    channelDescription: 'Reminders for tasks, habits and schedule items',
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
    if (Platform.isAndroid) {
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> refreshAll({
    required List<Task> tasks,
    required List<ScheduleItem> schedule,
    List<Habit> habits = const [],
  }) async {
    await initialize();
    final activeIds = <int>{};
    for (final task in tasks) {
      activeIds.addAll(await scheduleTask(task));
    }
    for (final habit in habits) {
      activeIds.addAll(await scheduleHabit(habit));
    }
    for (final item in schedule) {
      final id = _id('schedule:${item.id}');
      activeIds.add(id);
      await scheduleItem(item);
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (_isManagedPayload(p.payload) && !activeIds.contains(p.id)) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (_) {
      // Best-effort cleanup; notification failure must never break the app.
    }
  }

  Future<Set<int>> scheduleTask(Task task) async {
    await initialize();
    await _cancelByPayloadPrefix('task:${task.id}:');
    // Legacy ID is intentionally cancelled so upgrading to multi-reminder mode
    // cannot leave an orphaned old notification behind.
    final legacyId = _id('task:${task.id}');
    await _plugin.cancel(legacyId);

    if (task.dueDate == null ||
        task.archived ||
        task.status == TaskStatus.done ||
        task.status == TaskStatus.archived) {
      for (final r in task.reminders) {
        await _plugin.cancel(_id('task:${task.id}:r:${r.id}'));
      }
      return {};
    }

    final reminders = task.reminders.where((r) => r.enabled).toList();
    if (reminders.isEmpty) {
      final due = _taskDueDateTime(task);
      final id = legacyId;
      await _schedule(
        id: id,
        title: 'Task due',
        body: task.title,
        dateTime: due,
        payload: 'task:${task.id}',
      );
      return {id};
    }

    final active = <int>{};
    final due = _taskDueDateTime(task);
    for (final reminder in reminders) {
      final id = _id('task:${task.id}:r:${reminder.id}');
      active.add(id);
      final when = due.subtract(Duration(minutes: reminder.minutesBeforeDue));
      await _schedule(
        id: id,
        title: reminder.minutesBeforeDue == 0 ? 'Task due' : 'Task reminder',
        body: reminder.minutesBeforeDue == 0
            ? task.title
            : '${task.title} is due soon',
        dateTime: when,
        payload: 'task:${task.id}:r:${reminder.id}',
      );
    }
    return active;
  }

  Future<Set<int>> scheduleHabit(Habit habit) async {
    await initialize();
    await _cancelByPayloadPrefix('habit:${habit.id}:');
    final active = <int>{};
    final enabled = habit.reminders.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return active;

    // Keep a rolling 14-day horizon so a habit remains scheduled while the app
    // is not opened every day. refreshAll can safely be called on each launch.
    final today = _dateOnly(DateTime.now());
    for (var offset = 0; offset < 14; offset++) {
      final date = today.add(Duration(days: offset));
      if (!habit.isDueOn(date) || habit.isCompletedOn(date) || habit.isSkippedOn(date)) {
        continue;
      }
      for (final reminder in enabled) {
        if (reminder.weekdays.isNotEmpty &&
            !reminder.weekdays.contains(date.weekday)) {
          continue;
        }
        final when = DateTime(
          date.year,
          date.month,
          date.day,
          reminder.hour,
          reminder.minute,
        );
        final id = _id('habit:${habit.id}:${_dateKey(date)}:r:${reminder.id}');
        active.add(id);
        await _schedule(
          id: id,
          title: 'Habit reminder',
          body: habit.name,
          dateTime: when,
          payload: 'habit:${habit.id}:r:${reminder.id}',
        );
      }
    }
    return active;
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

  Future<void> cancelTask(String id) async {
    await initialize();
    await _plugin.cancel(_id('task:$id'));
    await _cancelByPayloadPrefix('task:$id:');
  }

  Future<void> cancelHabit(String id) async {
    await initialize();
    await _cancelByPayloadPrefix('habit:$id:');
  }

  Future<void> cancelSchedule(String id) async {
    await initialize();
    await _plugin.cancel(_id('schedule:$id'));
  }

  DateTime _taskDueDateTime(Task task) {
    final d = task.dueDate!;
    final t = task.dueTime;
    return DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
  }

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
      if (kDebugMode) debugPrint('Unable to schedule notification: $error');
    }
  }

  Future<void> _cancelByPayloadPrefix(String prefix) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload?.startsWith(prefix) == true) {
          await _plugin.cancel(request.id);
        }
      }
    } catch (_) {}
  }

  bool _isManagedPayload(String? payload) {
    if (payload == null) return false;
    return payload.startsWith('task:') ||
        payload.startsWith('habit:') ||
        payload.startsWith('schedule:');
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Keep this stable across app updates so existing device notifications can
  /// still be replaced/cancelled safely.
  int _id(String value) => value.hashCode & 0x7fffffff;
}
