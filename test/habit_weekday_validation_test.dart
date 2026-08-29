import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/habit.dart';

void main() {
  group('Habit weekday validation', () {
    test('valid weekdays 1-7 are accepted', () {
      expect(
        () => Habit(
          id: 'valid-weekday',
          name: 'Valid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        returnsNormally,
      );
    });

    test('weekday 0 is rejected', () {
      expect(
        () => Habit(
          id: 'invalid-weekday-0',
          name: 'Invalid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [0],
        ),
        throwsArgumentError,
      );
    });

    test('weekday 8 is rejected', () {
      expect(
        () => Habit(
          id: 'invalid-weekday-8',
          name: 'Invalid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [8],
        ),
        throwsArgumentError,
      );
    });

    test('negative weekday is rejected', () {
      expect(
        () => Habit(
          id: 'invalid-weekday-neg',
          name: 'Invalid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [-1],
        ),
        throwsArgumentError,
      );
    });

    test('duplicate weekdays are rejected', () {
      expect(
        () => Habit(
          id: 'duplicate-weekday',
          name: 'Invalid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [1, 1],
        ),
        throwsArgumentError,
      );
    });

    test('empty custom selection is rejected', () {
      expect(
        () => Habit(
          id: 'empty-weekday',
          name: 'Invalid',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [],
        ),
        throwsArgumentError,
      );
    });
  });
}
