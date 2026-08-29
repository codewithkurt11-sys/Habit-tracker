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
import 'package:flutter_app/data/models/user_settings.dart';
import 'package:flutter_app/logic/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late AppState state;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yourself_goal_link_');
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
    ]);
    state = AppState();
  });

  tearDown(() async {
    state.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Goal goalBox(String id) => Hive.box<Goal>(HiveBoxes.goals).get(id)!;

  Future<Goal> makeGoal(String id, String title) async {
    final goal = Goal(
      id: id,
      title: title,
      targetValue: 10,
      startDate: DateTime(2026, 1, 1),
      progressMode: GoalProgressMode.manual,
    );
    await Hive.box<Goal>(HiveBoxes.goals).put(goal.id, goal);
    return goal;
  }

  test('moving a habit from Goal A to Goal B leaves no stale link', () async {
    final goalA = await makeGoal('goal-a', 'Goal A');
    final goalB = await makeGoal('goal-b', 'Goal B');
    final habit = Habit(
      id: 'habit-x',
      name: 'Habit X',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);

    // Assign to Goal A, then reassign to Goal B.
    await state.updateGoal(goalA, habitIds: ['habit-x']);
    expect(goalBox('goal-a').linkedHabitIds, ['habit-x']);

    await state.updateGoal(goalB, habitIds: ['habit-x']);

    // Goal A must NOT contain Habit X; Goal B must.
    expect(goalBox('goal-a').linkedHabitIds, isEmpty);
    expect(goalBox('goal-b').linkedHabitIds, ['habit-x']);
    // The canonical relationship points at Goal B.
    expect(
      Hive.box<Habit>(HiveBoxes.habits).get('habit-x')!.goalId,
      'goal-b',
    );
  });

  test('moving a task from Goal A to Goal B leaves no stale link', () async {
    final goalA = await makeGoal('goal-a', 'Goal A');
    final goalB = await makeGoal('goal-b', 'Goal B');
    final task = Task(
      id: 'task-x',
      title: 'Task X',
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<Task>(HiveBoxes.tasks).put(task.id, task);

    await state.updateGoal(goalA, taskIds: ['task-x']);
    expect(goalBox('goal-a').linkedTaskIds, ['task-x']);

    await state.updateGoal(goalB, taskIds: ['task-x']);

    expect(goalBox('goal-a').linkedTaskIds, isEmpty);
    expect(goalBox('goal-b').linkedTaskIds, ['task-x']);
    expect(Hive.box<Task>(HiveBoxes.tasks).get('task-x')!.goalId, 'goal-b');
  });

  test('a reassigned habit is only resolved for its canonical goal', () async {
    final goalA = await makeGoal('goal-a', 'Goal A');
    final goalB = await makeGoal('goal-b', 'Goal B');
    final habit = Habit(
      id: 'habit-x',
      name: 'Habit X',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);

    await state.updateGoal(goalA, habitIds: ['habit-x']);
    await state.updateGoal(goalB, habitIds: ['habit-x']);

    expect(state.habitsForGoal(goalBox('goal-a')), isEmpty);
    expect(state.habitsForGoal(goalBox('goal-b')).single.id, 'habit-x');
  });

  test('a manually injected stale reverse link is not double counted',
      () async {
    // Simulate legacy data: Goal A still names the habit, but the habit's
    // canonical goalId points at Goal B.
    final goalA = await makeGoal('goal-a', 'Goal A');
    await makeGoal('goal-b', 'Goal B');
    final habit = Habit(
      id: 'habit-x',
      name: 'Habit X',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
      goalId: 'goal-b',
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);
    goalA.linkedHabitIds = ['habit-x'];
    await Hive.box<Goal>(HiveBoxes.goals).put(goalA.id, goalA);

    // Canonical resolution ignores the stale array.
    expect(state.habitsForGoal(goalBox('goal-a')), isEmpty);
    expect(state.habitsForGoal(goalBox('goal-b')).single.id, 'habit-x');

    // And the repair pass removes the stale entry from storage.
    await state.rebuildGoalReverseLinks();
    expect(goalBox('goal-a').linkedHabitIds, isEmpty);
    expect(goalBox('goal-b').linkedHabitIds, ['habit-x']);
  });

  test('unlinking clears both the reverse link and the canonical goalId',
      () async {
    final goal = await makeGoal('goal-a', 'Goal A');
    final habit = Habit(
      id: 'habit-x',
      name: 'Habit X',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);

    await state.updateGoal(goal, habitIds: ['habit-x']);
    await state.updateGoal(goalBox('goal-a'), habitIds: const []);

    expect(goalBox('goal-a').linkedHabitIds, isEmpty);
    expect(Hive.box<Habit>(HiveBoxes.habits).get('habit-x')!.goalId, isNull);
  });

  test('legacy entities with no canonical owner keep their reverse link',
      () async {
    // Pre-goalId Hive data: habit has no goalId/linkedGoalId at all.
    final goal = await makeGoal('goal-a', 'Goal A');
    final habit = Habit(
      id: 'legacy-habit',
      name: 'Legacy',
      category: HabitCategory.other,
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<Habit>(HiveBoxes.habits).put(habit.id, habit);
    goal.linkedHabitIds = ['legacy-habit'];
    await Hive.box<Goal>(HiveBoxes.goals).put(goal.id, goal);

    await state.rebuildGoalReverseLinks();
    expect(goalBox('goal-a').linkedHabitIds, ['legacy-habit']);
    expect(state.habitsForGoal(goalBox('goal-a')).single.id, 'legacy-habit');
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
}

void _register<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}
