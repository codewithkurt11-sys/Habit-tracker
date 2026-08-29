import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/habit.dart';
import 'package:flutter_app/data/repositories/habits_repository.dart';

void main() {
  late Directory dir;
  late HabitsRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_habits_repo_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(HabitAdapter().typeId)) {
      Hive.registerAdapter(HabitAdapter());
    }
    await Hive.openBox<Habit>('habits_box');
    repo = HabitsRepository();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('HabitsRepository weekday validation', () {
    test('create rejects custom day 0', () {
      expect(
        () => repo.create(
          name: 'Bad Habit',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [0],
        ),
        throwsArgumentError,
      );
    });

    test('create rejects custom day 8', () {
      expect(
        () => repo.create(
          name: 'Bad Habit',
          category: HabitCategory.other,
          frequency: HabitFrequency.custom,
          customDays: [8],
        ),
        throwsArgumentError,
      );
    });

    test('update rejects custom day 0', () async {
      final habit = await repo.create(
        name: 'Good Habit',
        category: HabitCategory.other,
        frequency: HabitFrequency.custom,
        customDays: [1, 2],
      );
      // Bypass model validation by directly mutating the stored habit's
      // customDays list, then verify the repository boundary catches it.
      habit.customDays = [0];
      expect(
        () => repo.update(habit),
        throwsArgumentError,
      );
    });

    test('update rejects custom day 8', () async {
      final habit = await repo.create(
        name: 'Good Habit',
        category: HabitCategory.other,
        frequency: HabitFrequency.custom,
        customDays: [1, 2],
      );
      habit.customDays = [8];
      expect(
        () => repo.update(habit),
        throwsArgumentError,
      );
    });
  });
}
