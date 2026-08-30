import 'dart:io';

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
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late AppState state;

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
    state = AppState();
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
