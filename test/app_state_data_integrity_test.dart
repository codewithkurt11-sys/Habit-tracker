import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_app/data/hive_boxes.dart';
import 'package:flutter_app/data/models/finance_entry.dart';
import 'package:flutter_app/data/models/focus_session.dart';
import 'package:flutter_app/data/models/goal.dart';
import 'package:flutter_app/data/models/habit.dart';
import 'package:flutter_app/data/models/journal_entry.dart';
import 'package:flutter_app/data/models/note.dart';
import 'package:flutter_app/data/models/quote.dart';
import 'package:flutter_app/data/models/savings_goal.dart';
import 'package:flutter_app/data/models/schedule_item.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/data/models/task_category.dart';
import 'package:flutter_app/data/models/recurrence_rule.dart';
import 'package:flutter_app/data/models/reminder_rule.dart';
import 'package:flutter_app/data/models/user_settings.dart';
import 'package:flutter_app/logic/app_state.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late AppState state;
  late _RecordingNotifications notifications;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yourself_app_state_');
    Hive.init(directory.path);
    _registerAdapters();
    await Future.wait([
      Hive.openBox<Note>(HiveBoxes.notes),
      Hive.openBox<Habit>(HiveBoxes.habits),
      Hive.openBox<ScheduleItem>(HiveBoxes.schedule),
      Hive.openBox<Quote>(HiveBoxes.quotes),
      Hive.openBox<UserSettings>(HiveBoxes.settings),
      Hive.openBox<Task>(HiveBoxes.tasks),
      Hive.openBox<JournalEntry>(HiveBoxes.journal),
      Hive.openBox<FinanceEntry>(HiveBoxes.finance),
      Hive.openBox<FinanceBudget>(HiveBoxes.financeBudget),
      Hive.openBox<Goal>(HiveBoxes.goals),
      Hive.openBox<FocusSession>(HiveBoxes.focus),
      Hive.openBox<SavingsGoal>(HiveBoxes.savingsGoals),
      Hive.openBox<TaskCategoryModel>(HiveBoxes.taskCategories),
    ]);
    notifications = _RecordingNotifications();
    state = AppState(notificationService: notifications);
  });

  tearDown(() async {
    state.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('import rebuilds stale goal reverse links from canonical children',
      () async {
    final timestamp = DateTime(2025, 1, 1).toIso8601String();
    await state.importAllData({
      'format': 'yourself-backup',
      'version': 3,
      'goals': [
        {
          'id': 'goal-1',
          'title': 'Imported goal',
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'linkedHabitIds': ['stale-habit'],
          'linkedTaskIds': ['stale-task'],
          'linkedFinanceId': 'stale-finance',
          'isAutoProgress': false,
        },
      ],
      'habits': [
        {
          'id': 'habit-1',
          'name': 'Imported habit',
          'category': 'other',
          'frequency': 'daily',
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'goalId': 'goal-1',
        },
      ],
      'tasks': [
        {
          'id': 'task-1',
          'title': 'Imported task',
          'priority': 'medium',
          'status': 'todo',
          'category': 'other',
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'linkedGoalId': 'goal-1',
        },
      ],
      'notes': <Map<String, dynamic>>[],
      'finance': [
        {
          'id': 'finance-1',
          'title': 'Imported contribution',
          'amount': 25,
          'type': 'income',
          'categoryIndex': 0,
          'date': timestamp,
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'linkedGoalId': 'goal-1',
        },
      ],
    });

    final goal = Hive.box<Goal>(HiveBoxes.goals).get('goal-1')!;
    expect(goal.linkedHabitIds, ['habit-1']);
    expect(goal.linkedTaskIds, ['task-1']);
    expect(goal.linkedFinanceId, 'finance-1');
    expect(Hive.box<Task>(HiveBoxes.tasks).get('task-1')!.goalId, 'goal-1');
    expect(
      Hive.box<FinanceEntry>(HiveBoxes.finance).get('finance-1')!.goalId,
      'goal-1',
    );
  });

  test(
      'startup refresh sees saved occurrences and habits after catch-up scheduling fails',
      () async {
    final task = Task(
      id: 'completed',
      title: 'Daily task',
      isRecurring: true,
      status: TaskStatus.done,
      dueDate: DateTime(2024, 1, 1),
      recurrenceSeriesId: 'series',
      customCategoryId: 'category',
      recurrenceRule: const RecurrenceRule(type: RecurrenceType.daily),
      reminders: [ReminderRule(id: 'task-reminder', minutesBeforeDue: 15)],
    );
    final habit = Habit(
      id: 'habit',
      name: 'Read',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      reminders: [ReminderRule(id: 'habit-reminder', hour: 20)],
    );
    await Hive.box<Task>(HiveBoxes.tasks).put(task.id, task);
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);
    notifications.failTaskScheduling = true;

    await initializeStartup(state);

    expect(notifications.events, ['task scheduling failed', 'refresh']);
    final created = notifications.tasks.where((t) => t.id != task.id).single;
    expect(created.dueDate, DateTime(2024, 1, 2));
    expect(created.recurrenceSeriesId, 'series');
    expect(created.customCategoryId, 'category');
    expect(created.reminders.single.id, 'task-reminder');
    expect(notifications.habits.single.reminders.single.id, 'habit-reminder');
    await initializeStartup(state);
    expect(state.tasksRepo.getAll(), hasLength(2));
    expect(notifications.events.last, 'refresh');
  });

  test(
      'v7 JSON backup and Hive reopen preserve recurrence, categories and reminders',
      () async {
    final category = await state.taskCategoriesRepo.create(
      name: 'Reports',
      color: Colors.blue,
      icon: Icons.work_outline,
    );
    final task = await state.tasksRepo.create(
      title: 'Report',
      dueDate: DateTime(2024, 1, 31),
      dueTime: DateTime(2024, 1, 31, 17, 30),
      isRecurring: true,
      customCategoryId: category.id,
      recurrenceRule: RecurrenceRule(
        type: RecurrenceType.monthlyDates,
        monthDays: [31],
        startDate: DateTime(2024, 1, 31),
        endDate: DateTime(2028, 12, 31),
      ),
      reminders: [
        ReminderRule(id: 'task-r', minutesBeforeDue: 60, enabled: false)
      ],
    );
    final habit = Habit(
      id: 'habit',
      name: 'Read',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      reminders: [
        ReminderRule(id: 'habit-r', hour: 20, minute: 15, weekdays: [1, 3])
      ],
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);
    // Normalize through one disk round-trip before comparing: Hive persists
    // timestamps with millisecond precision while the in-memory cache keeps
    // microseconds, and every real post-restart read comes from disk.
    await state.tasksRepo.update(task);
    await Hive.box<Task>(HiveBoxes.tasks).close();
    await Hive.box<Habit>(HiveBoxes.habits).close();
    await Hive.box<TaskCategoryModel>(HiveBoxes.taskCategories).close();
    await Hive.openBox<Task>(HiveBoxes.tasks);
    await Hive.openBox<Habit>(HiveBoxes.habits);
    await Hive.openBox<TaskCategoryModel>(HiveBoxes.taskCategories);
    final backup =
        jsonDecode(jsonEncode(state.exportAllData())) as Map<String, dynamic>;
    expect(backup['version'], 7);
    await state.importAllData(backup);
    expect(notifications.events, ['refresh']);
    expect(notifications.habits.single.id, habit.id);
    await Hive.box<Task>(HiveBoxes.tasks).close();
    await Hive.box<Habit>(HiveBoxes.habits).close();
    await Hive.box<TaskCategoryModel>(HiveBoxes.taskCategories).close();
    await Hive.openBox<Task>(HiveBoxes.tasks);
    await Hive.openBox<Habit>(HiveBoxes.habits);
    await Hive.openBox<TaskCategoryModel>(HiveBoxes.taskCategories);
    final restored = state.exportAllData();
    expect(restored['tasks'], backup['tasks']);
    expect(restored['habits'], backup['habits']);
    expect(restored['taskCategories'], backup['taskCategories']);
    final stored = state.tasksRepo.getById(task.id)!;
    expect(stored.recurrenceRule!.nextOccurrenceAfter(stored.dueDate!),
        DateTime(2024, 3, 31));
    expect(stored.recurrenceSeriesId, task.recurrenceSeriesId);
  });

  test(
      'category deletion persists fallback for completed and archived series tasks',
      () async {
    final category = await state.taskCategoriesRepo.create(
      name: 'Reports',
      color: Colors.blue,
      icon: Icons.work_outline,
    );
    for (final archived in [false, true]) {
      final task = Task(
        id: 'task-$archived',
        title: 'Report',
        archived: archived,
        status: TaskStatus.done,
        isRecurring: true,
        customCategoryId: category.id,
      );
      await Hive.box<Task>(HiveBoxes.tasks).put(task.id, task);
    }
    await state.deleteTaskCategory(category.id);
    await Hive.box<Task>(HiveBoxes.tasks).close();
    await Hive.openBox<Task>(HiveBoxes.tasks);
    expect(state.taskCategoriesRepo.getById(category.id), isNull);
    for (final task in state.tasksRepo.getAll(includeArchived: true)) {
      expect(task.customCategoryId, isNull);
      expect(task.category, TaskCategory.other);
    }
  });

  test('legacy adapter records default missing integrated fields safely', () {
    final task = TaskAdapter().read(_FieldsReader({0: 'task', 1: 'Legacy'}));
    expect(task.recurrenceSeriesId, isNull);
    expect(task.customCategoryId, isNull);
    expect(task.recurrenceRule, isNull);
    expect(task.reminders, isEmpty);
    final habit = HabitAdapter().read(_FieldsReader({
      0: 'habit',
      1: 'Legacy',
      2: 0,
      3: 0,
      4: <int>[],
      5: <DateTime>[],
      6: DateTime(2024),
    }));
    expect(habit.reminders, isEmpty);
    expect(habit.skipLog, isEmpty);
    expect(habit.updatedAt, habit.createdAt);
    final rule = RecurrenceRuleAdapter().read(_FieldsReader({}));
    expect(rule.type, RecurrenceType.daily);
    expect(rule.interval, 1);
    expect(rule.monthDays, isEmpty);
    expect(rule.startDate, isNull);
    expect(rule.endDate, isNull);
    final category = TaskCategoryAdapter().read(_FieldsReader({
      0: 'category',
      1: 'Legacy',
      2: 0xFF123456,
      3: Icons.work.codePoint,
    }));
    expect(category.iconFontFamily, 'MaterialIcons');
    expect(category.iconFontPackage, isNull);
    final reminder = ReminderRuleAdapter().read(_FieldsReader({0: 'reminder'}));
    expect(reminder.enabled, isTrue);
    expect(reminder.hour, 9);
    expect(reminder.minute, 0);
    expect(reminder.minutesBeforeDue, 0);
    expect(reminder.weekdays, isEmpty);
  });

  test('syncGoal preserves completion achieved through milestones', () async {
    final goal = Goal(
      id: 'goal-1',
      title: 'Milestone goal',
      milestoneTitles: ['First', 'Second'],
      milestoneDone: [true, true],
      completed: true,
      isAutoProgress: true,
    );
    await Hive.box<Goal>(HiveBoxes.goals).put(goal.id, goal);

    await state.syncGoal(goal.id);

    final stored = Hive.box<Goal>(HiveBoxes.goals).get(goal.id)!;
    expect(stored.currentValue, 0);
    expect(stored.completed, isTrue);
  });

  test('goal deletion touches finance entries whose relationship is cleared',
      () async {
    final oldTimestamp = DateTime(2020, 1, 1);
    final goal = Goal(id: 'goal-1', title: 'Finance goal');
    final finance = FinanceEntry(
      id: 'finance-1',
      title: 'Contribution',
      amount: 10,
      typeIndex: 0,
      categoryIndex: 0,
      date: DateTime(2025, 1, 1),
      goalId: goal.id,
      updatedAt: oldTimestamp,
    );
    await Hive.box<Goal>(HiveBoxes.goals).put(goal.id, goal);
    await Hive.box<FinanceEntry>(HiveBoxes.finance).put(finance.id, finance);

    await state.deleteGoal(goal.id);

    final stored = Hive.box<FinanceEntry>(HiveBoxes.finance).get(finance.id)!;
    expect(stored.goalId, isNull);
    expect(stored.updatedAt.isAfter(oldTimestamp), isTrue);
  });
}

class _RecordingNotifications extends NotificationService {
  final events = <String>[];
  List<Task> tasks = [];
  List<Habit> habits = [];
  bool failTaskScheduling = false;

  @override
  Future<Set<int>> scheduleTask(Task task) async {
    if (failTaskScheduling) {
      events.add('task scheduling failed');
      throw StateError('forced catch-up scheduling failure');
    }
    return {};
  }

  @override
  Future<void> refreshAll({
    required List<Task> tasks,
    required List<ScheduleItem> schedule,
    List<Habit> habits = const [],
  }) async {
    events.add('refresh');
    this.tasks = List.of(tasks);
    this.habits = List.of(habits);
  }
}

/// Supplies older records' field maps directly to the production adapters.
class _FieldsReader implements BinaryReader {
  final Map<int, dynamic> fields;
  int index = -1;
  _FieldsReader(this.fields);

  @override
  int readByte() =>
      index++ == -1 ? fields.length : fields.keys.elementAt(index - 1);

  @override
  dynamic read([int? typeId]) => fields.values.elementAt(index - 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _registerAdapters() {
  _register<Note>(NoteAdapter());
  _register<Habit>(HabitAdapter());
  _register<ScheduleItem>(ScheduleItemAdapter());
  _register<Quote>(QuoteAdapter());
  _register<UserSettings>(UserSettingsAdapter());
  _register<Task>(TaskAdapter());
  _register<JournalEntry>(JournalEntryAdapter());
  _register<FinanceEntry>(FinanceEntryAdapter());
  _register<FinanceBudget>(FinanceBudgetAdapter());
  _register<Goal>(GoalAdapter());
  _register<FocusSession>(FocusSessionAdapter());
  _register<SavingsGoal>(SavingsGoalAdapter());
  _register<RecurrenceRule>(RecurrenceRuleAdapter());
  _register<TaskCategoryModel>(TaskCategoryAdapter());
  _register<ReminderRule>(ReminderRuleAdapter());
}

void _register<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}
