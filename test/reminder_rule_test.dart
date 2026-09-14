import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/data/models/habit.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/services/notification_service.dart';
import 'package:flutter_app/ui/widgets/reminder_editor_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/reminder_rule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_reminder_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(ReminderRuleAdapter().typeId)) {
      Hive.registerAdapter(ReminderRuleAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('notification semantics', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late NotificationService service;
    late Map<int, Map<String, dynamic>> pending;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      service = NotificationService();
      pending = {};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'pendingNotificationRequests':
            return pending.values
                .map((item) => {
                      'id': item['id'],
                      'title': item['title'],
                      'body': item['body'],
                      'payload': item['payload'],
                    })
                .toList();
          case 'cancel':
            pending.remove((call.arguments as Map)['id']);
            return null;
          case 'zonedSchedule':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            pending[args['id'] as int] = args;
            return null;
          default:
            throw StateError('Unexpected notification method: ${call.method}');
        }
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'empty or all-disabled task reminders keep exactly one due notification',
        () async {
      final date = DateTime.now().add(const Duration(days: 5));
      final task = Task(id: 'task', title: 'Report', dueDate: date);
      await service.scheduleTask(task);
      expect(pending, hasLength(1));
      expect(pending.values.single['payload'], 'task:task');
      final due = DateTime(date.year, date.month, date.day, 9).toUtc();
      expect(
          DateTime.parse(pending.values.single['scheduledDateTime'] as String),
          DateTime(due.year, due.month, due.day, due.hour, due.minute));
      task.reminders = [ReminderRule(id: 'disabled', enabled: false)];
      await service.scheduleTask(task);
      expect(pending, hasLength(1));
      expect(pending.values.single['payload'], 'task:task');
    });

    test(
        'task reminder edits replace old IDs and completion cancels notifications',
        () async {
      final date = DateTime.now().add(const Duration(days: 5));
      final task = Task(
          id: 'task',
          title: 'Report',
          dueDate: date,
          dueTime: DateTime(2024, 1, 1, 17, 30));
      await service.scheduleTask(task);
      task.reminders = [ReminderRule(id: 'before', minutesBeforeDue: 30)];
      await service.scheduleTask(task);
      expect(pending, hasLength(1));
      expect(pending.values.single['payload'], 'task:task:r:before');
      final due = DateTime(date.year, date.month, date.day, 17).toUtc();
      expect(
          DateTime.parse(pending.values.single['scheduledDateTime'] as String),
          DateTime(due.year, due.month, due.day, due.hour, due.minute));
      task.status = TaskStatus.done;
      await service.scheduleTask(task);
      expect(pending, isEmpty);
    });

    test('undated, archived and past tasks do not retain notifications',
        () async {
      final task = Task(id: 'task', title: 'Report');
      await service.scheduleTask(task);
      expect(pending, isEmpty);
      task.dueDate = DateTime(2020);
      await service.scheduleTask(task);
      expect(pending, isEmpty);
      task.dueDate = DateTime.now().add(const Duration(days: 5));
      await service.scheduleTask(task);
      expect(pending, hasLength(1));
      task.archived = true;
      await service.scheduleTask(task);
      expect(pending, isEmpty);
    });

    test(
        'refresh restores habit reminders and removes deleted entity notifications',
        () async {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final habit = Habit(
        id: 'habit',
        name: 'Read',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: tomorrow,
        reminders: [ReminderRule(id: 'habit-r', hour: 12)],
      );
      final task = Task(id: 'task', title: 'Report', dueDate: tomorrow);
      await service.refreshAll(tasks: [task], habits: [habit], schedule: []);
      expect(pending.values.any((p) => p['payload'] == 'task:task'), isTrue);
      expect(
          pending.values.where((p) => p['payload'] == 'habit:habit:r:habit-r'),
          hasLength(13));
      final firstIds = pending.keys.toSet();
      await service.refreshAll(tasks: [task], habits: [habit], schedule: []);
      expect(pending.keys.toSet(), firstIds);
      habit.reminders = [];
      await service.refreshAll(tasks: [], habits: [habit], schedule: []);
      expect(pending, isEmpty);
      habit.reminders = [ReminderRule(id: 'disabled', enabled: false)];
      await service.scheduleHabit(habit);
      expect(pending, isEmpty);
    });
  });

  for (final forHabit in [false, true]) {
    for (final disabled in [false, true]) {
      testWidgets(
          '${forHabit ? 'habit' : 'task'} ${disabled ? 'disabled' : 'empty'} reminders explain scheduling',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: ReminderListEditor(
          forHabit: forHabit,
          reminders:
              disabled ? [ReminderRule(id: 'disabled', enabled: false)] : [],
          onChanged: (_) {},
        ))));
        expect(
            find.textContaining(forHabit
                ? 'No habit notifications will be scheduled.'
                : 'Default due-time notification:'),
            findsOneWidget);
        if (disabled) expect(find.byType(Switch), findsOneWidget);
      });
    }
  }

  test('normalizes invalid weekday values and removes duplicates', () {
    final rule = ReminderRule(
      id: 'r1',
      weekdays: [7, 2, 2, 0, 8],
    );
    expect(rule.weekdays, [2, 7]);
  });

  test('round-trips through Hive adapter', () async {
    final box = await Hive.openBox<ReminderRule>('reminders');
    final original = ReminderRule(
      id: 'r1',
      enabled: false,
      hour: 22,
      minute: 30,
      minutesBeforeDue: 15,
      weekdays: [1, 3, 5],
    );
    await box.put(original.id, original);
    await box.close();
    final reopened = await Hive.openBox<ReminderRule>('reminders');
    final restored = reopened.get(original.id)!;
    expect(restored.id, original.id);
    expect(restored.enabled, false);
    expect(restored.hour, 22);
    expect(restored.minute, 30);
    expect(restored.minutesBeforeDue, 15);
    expect(restored.weekdays, [1, 3, 5]);
  });
}
