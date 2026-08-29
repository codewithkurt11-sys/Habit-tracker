import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/goal.dart';
import 'package:flutter_app/data/models/habit.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/logic/goal_progress_engine.dart';

void main() {
  test('100-day habit goal advances one unit per completed scheduled day', () {
    final start = DateTime(2026, 8, 1);
    final habit = Habit(
      id: 'pushups',
      name: 'Push ups',
      category: HabitCategory.workout,
      frequency: HabitFrequency.daily,
      createdAt: start,
      goalId: 'goal',
      completionLog: [start],
    );
    final goal = Goal(
      id: 'goal',
      title: 'Push ups for 100 days',
      targetValue: 100,
      startDate: start,
      progressMode: GoalProgressMode.habitDays,
    );

    final snapshot = GoalProgressEngine.compute(
      goal: goal,
      habits: [habit],
      tasks: const [],
      finance: const [],
      savings: const [],
      today: start,
    );

    expect(snapshot.currentUnits, 1);
    expect(snapshot.fraction, closeTo(0.01, 0.0001));
    expect(snapshot.remainingUnits, 99);
    expect(snapshot.completedDates.length, 1);
    expect(snapshot.missedDates.length, 0);
  });

  test('skipped and missed scheduled habit days are distinct', () {
    final start = DateTime(2026, 8, 1);
    final habit = Habit(
      id: 'h',
      name: 'Daily',
      category: HabitCategory.lifestyle,
      frequency: HabitFrequency.daily,
      createdAt: start,
      completionLog: [start],
      skipLog: [start.add(const Duration(days: 1))],
    );
    final goal = Goal(
      id: 'g',
      title: '10 days',
      targetValue: 10,
      startDate: start,
      progressMode: GoalProgressMode.habitDays,
    );

    final snapshot = GoalProgressEngine.compute(
      goal: goal,
      habits: [habit],
      tasks: const [],
      finance: const [],
      savings: const [],
      today: start.add(const Duration(days: 2)),
    );

    expect(snapshot.completedDates.length, 1);
    expect(snapshot.skippedDates.length, 1);
    expect(snapshot.missedDates.length, 1);
  });

  test('task goals count completed occurrences, not the average of active tasks', () {
    final goal = Goal(
      id: 'g',
      title: '100 task completions',
      targetValue: 100,
      progressMode: GoalProgressMode.taskCount,
      startDate: DateTime(2026, 8, 1),
    );
    final done = Task(id: '1', title: 'Push up task', status: TaskStatus.done, completedAt: DateTime(2026, 8, 1));
    final next = Task(id: '2', title: 'Push up task', status: TaskStatus.todo);

    final snapshot = GoalProgressEngine.compute(
      goal: goal,
      habits: const [],
      tasks: [done, next],
      finance: const [],
      savings: const [],
      today: DateTime(2026, 8, 1),
    );

    expect(snapshot.currentUnits, 1);
    expect(snapshot.fraction, closeTo(0.01, 0.0001));
    expect(snapshot.completedTasks, 1);
  });
}
