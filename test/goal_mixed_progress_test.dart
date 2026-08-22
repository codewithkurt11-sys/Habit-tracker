import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/finance_entry.dart';
import 'package:flutter_app/data/models/goal.dart';
import 'package:flutter_app/data/models/habit.dart';
import 'package:flutter_app/data/models/savings_goal.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/logic/goal_progress_engine.dart';

/// Fixed reference window so the tests never depend on "now".
final start = DateTime(2026, 1, 1);
final today = DateTime(2026, 1, 2);

Goal _goal(GoalProgressMode mode, {double target = 100}) => Goal(
      id: 'g',
      title: 'Goal',
      targetValue: target,
      startDate: start,
      progressMode: mode,
    );

/// A daily habit completed on both days of the window => 2 completed days.
Habit _habit() => Habit(
      id: 'h',
      name: 'Habit',
      category: HabitCategory.workout,
      frequency: HabitFrequency.daily,
      createdAt: start,
      goalId: 'g',
      completionLog: [start, today],
    );

/// One task completed inside the window.
Task _task() => Task(
      id: 't',
      title: 'Task',
      status: TaskStatus.done,
      completedAt: start,
      createdAt: start,
      goalId: 'g',
    );

/// Income entry of [amount] inside the window.
FinanceEntry _finance(double amount) => FinanceEntry(
      id: 'f',
      title: 'Income',
      amount: amount,
      typeIndex: 0, // income
      categoryIndex: 0,
      date: start,
      createdAt: start,
      goalId: 'g',
    );

GoalProgressSnapshot _compute({
  required Goal goal,
  List<Habit> habits = const [],
  List<Task> tasks = const [],
  List<FinanceEntry> finance = const [],
  List<SavingsGoal> savings = const [],
}) =>
    GoalProgressEngine.compute(
      goal: goal,
      habits: habits,
      tasks: tasks,
      finance: finance,
      savings: savings,
      today: today,
    );

void main() {
  group('single-source goal progress', () {
    test('habit-only counts completed scheduled days', () {
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.habitDays, target: 10),
        habits: [_habit()],
      );
      expect(snapshot.currentUnits, 2);
      expect(snapshot.fraction, closeTo(0.2, 1e-9));
    });

    test('task-only counts completed tasks', () {
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.taskCount, target: 4),
        tasks: [_task()],
      );
      expect(snapshot.completedTasks, 1);
      expect(snapshot.fraction, closeTo(0.25, 1e-9));
    });

    test('finance-only sums income entries', () {
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.financeAmount, target: 200),
        finance: [_finance(100)],
      );
      expect(snapshot.financialAmount, 100);
      expect(snapshot.fraction, closeTo(0.5, 1e-9));
    });

    test('finance-only includes savings contributions', () {
      final savings = SavingsGoal(
        id: 's',
        title: 'Savings',
        targetAmount: 100,
        targetDays: 10,
        startDate: start,
        contributionDates: [start],
        contributionAmounts: [50],
        goalId: 'g',
      );
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.financeAmount, target: 100),
        savings: [savings],
      );
      expect(snapshot.financialAmount, 50);
      expect(snapshot.fraction, closeTo(0.5, 1e-9));
    });
  });

  group('mixed goal progress', () {
    test('mixed habit + task averages both sources', () {
      // habit = 2/4 = 50%, task = 1/4 = 25% -> avg 37.5%
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        habits: [_habit()],
        tasks: [_task()],
      );
      expect(snapshot.fraction, closeTo(0.375, 1e-9));
    });

    test('mixed habit + finance includes the finance contribution', () {
      // habit = 2/4 = 50%, finance = 4/4 = 100% -> avg 75%
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        habits: [_habit()],
        finance: [_finance(4)],
      );
      expect(snapshot.financialAmount, 4);
      expect(snapshot.fraction, closeTo(0.75, 1e-9));
    });

    test('mixed task + finance includes the finance contribution', () {
      // task = 1/4 = 25%, finance = 4/4 = 100% -> avg 62.5%
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        tasks: [_task()],
        finance: [_finance(4)],
      );
      expect(snapshot.financialAmount, 4);
      expect(snapshot.fraction, closeTo(0.625, 1e-9));
    });

    test('mixed habit + task + finance uses all three sources', () {
      // habit 50% + task 50% + finance 100% -> avg 66.6%
      final task2 = Task(
        id: 't2',
        title: 'Task 2',
        status: TaskStatus.done,
        completedAt: today,
        createdAt: start,
        goalId: 'g',
      );
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        habits: [_habit()],
        tasks: [_task(), task2],
        finance: [_finance(4)],
      );
      expect(snapshot.financialAmount, 4);
      // (0.5 + 0.5 + 1.0) / 3
      expect(snapshot.fraction, closeTo(2 / 3, 1e-9));
    });

    test('mixed with finance linked is never silently treated as 0%', () {
      final withFinance = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        habits: [_habit()],
        finance: [_finance(4)],
      );
      final withoutFinance = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 4),
        habits: [_habit()],
      );
      expect(withFinance.fraction, greaterThan(withoutFinance.fraction));
    });

    test('mixed progress stays clamped to 0..1', () {
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.mixed, target: 1),
        habits: [_habit()],
        finance: [_finance(1000)],
      );
      expect(snapshot.fraction, lessThanOrEqualTo(1.0));
      expect(snapshot.fraction, greaterThanOrEqualTo(0.0));
    });

    test('malformed savings contribution arrays do not throw', () {
      // Two dates but only one amount (legacy/corrupt record).
      final savings = SavingsGoal(
        id: 's',
        title: 'Savings',
        targetAmount: 100,
        targetDays: 10,
        startDate: start,
        contributionDates: [start, today],
        contributionAmounts: [25],
        goalId: 'g',
      );
      final snapshot = _compute(
        goal: _goal(GoalProgressMode.financeAmount, target: 100),
        savings: [savings],
      );
      expect(snapshot.financialAmount, 25);
    });
  });
}
