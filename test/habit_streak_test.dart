import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/habit.dart';

void main() {
  group('Habit currentStreak with skipped days', () {
    test('skipped day does not break streak', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final dayBefore = DateTime(today.year, today.month, today.day - 2);
      final threeDaysAgo = DateTime(today.year, today.month, today.day - 3);

      final habit = Habit(
        id: 'test1',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: threeDaysAgo,
        completionLog: [dayBefore, today],
        skipLog: [yesterday], // skipped yesterday, not completed
      );

      // Streak: today (completed) -> yesterday (skipped, continue) -> dayBefore (completed) = 2
      expect(habit.currentStreak(asOf: today), 2);
    });

    test('skipped day in bestStreak does not break streak', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final dayBefore = DateTime(today.year, today.month, today.day - 2);
      final threeDaysAgo = DateTime(today.year, today.month, today.day - 3);

      final habit = Habit(
        id: 'test2',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: threeDaysAgo,
        completionLog: [dayBefore, today],
        skipLog: [yesterday], // skipped yesterday, not completed
      );

      // Best streak: completed day before, skipped yesterday, completed today = 2
      expect(habit.bestStreak(), 2);
    });

    test('currentStreak with no skips works as before', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test3',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [dayBefore, yesterday, today],
      );

      expect(habit.currentStreak(asOf: today), 3);
    });

    test('missed day (not completed, not skipped) breaks streak', () {
      final today = DateTime.now();
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test4',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [dayBefore, today], // missed yesterday
      );

      // Today completed, yesterday missed -> streak = 1
      expect(habit.currentStreak(asOf: today), 1);
    });
  });

  group('Habit completionRate with skipped days', () {
    test('skipped days excluded from denominator', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test5',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [dayBefore, today],
        skipLog: [yesterday], // skipped yesterday
      );

      // 3 due days, 1 skipped -> denominator = 2, completed = 2 -> 1.0
      final rate = habit.completionRate(days: 3, asOf: today);
      expect(rate, 1.0);
    });

    test('no skipped days works as before', () {
      final today = DateTime.now();
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test6',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [dayBefore, today],
      );

      // 3 due days, 0 skipped -> denominator = 3, completed = 2 -> 0.667
      final rate = habit.completionRate(days: 3, asOf: today);
      expect(rate, closeTo(2 / 3, 0.01));
    });
  });

  group('Habit currentMissStreak', () {
    test('skipped day breaks miss streak', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test7',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [],
        skipLog: [yesterday], // skipped yesterday
      );

      // Yesterday was skipped -> miss streak = 0 (skipped breaks miss streak)
      expect(habit.currentMissStreak(asOf: today), 0);
    });

    test('missed day increments miss streak', () {
      final today = DateTime.now();
      final dayBefore = DateTime(today.year, today.month, today.day - 2);

      final habit = Habit(
        id: 'test8',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.daily,
        createdAt: dayBefore,
        completionLog: [],
        skipLog: [],
      );

      // Yesterday and dayBefore both missed -> miss streak = 2
      expect(habit.currentMissStreak(asOf: today), 2);
    });
  });

  group('Habit custom frequency validation', () {
    test('customDays with empty list on custom frequency should be validated at repo level', () {
      // This test verifies the model accepts empty customDays (validation is at repo level)
      final habit = Habit(
        id: 'test9',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.custom,
        customDays: [],
      );
      expect(habit.customDays, isEmpty);
      // isDueOn should return false for all days when customDays is empty
      expect(habit.isDueOn(DateTime.now()), false);
    });

    test('customDays with valid weekday numbers', () {
      final habit = Habit(
        id: 'test10',
        name: 'Test',
        category: HabitCategory.other,
        frequency: HabitFrequency.custom,
        customDays: [1, 3, 5], // Mon, Wed, Fri
        createdAt: DateTime(2025, 1, 1), // before test dates
      );
      final monday = DateTime(2025, 1, 6); // Monday
      final tuesday = DateTime(2025, 1, 7); // Tuesday
      expect(habit.isDueOn(monday), true);
      expect(habit.isDueOn(tuesday), false);
    });
  });
}
