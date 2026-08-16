import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:flutter_app/data/models/savings_goal.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_test').path);
    Hive.registerAdapter(SavingsGoalAdapter());
  });

  group('SavingsGoal dailyAmount', () {
    test('basic: 500 / 5 days = 100/day', () {
      final sg = SavingsGoal(
        id: 'test1',
        title: 'Test',
        targetAmount: 500,
        targetDays: 5,
        startDate: DateTime.now(),
      );
      expect(sg.remainingDays, 5);
      expect(sg.dailyAmount, closeTo(100, 0.01));
    });

    test('after 1 missed day: 500 / 4 = 125/day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final sg = SavingsGoal(
        id: 'test2',
        title: 'Test',
        targetAmount: 500,
        targetDays: 5,
        startDate: yesterday,
      );
      expect(sg.daysElapsed, 1);
      expect(sg.remainingDays, 4);
      expect(sg.dailyAmount, closeTo(125, 0.01));
    });

    test('after 1 day with 100 contributed: 400 / 4 = 100/day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final sg = SavingsGoal(
        id: 'test3',
        title: 'Test',
        targetAmount: 500,
        targetDays: 5,
        startDate: yesterday,
        contributionDates: [
          DateTime(yesterday.year, yesterday.month, yesterday.day)
        ],
        contributionAmounts: [100],
      );
      expect(sg.totalContributed, 100);
      expect(sg.remainingAmount, 400);
      expect(sg.remainingDays, 4);
      expect(sg.dailyAmount, closeTo(100, 0.01));
    });

    test('divide-by-zero: 0 remaining days does not crash', () {
      final oldDate = DateTime.now().subtract(const Duration(days: 10));
      final sg = SavingsGoal(
        id: 'test4',
        title: 'Test',
        targetAmount: 500,
        targetDays: 5,
        startDate: oldDate,
      );
      expect(sg.remainingDays, 0);
      expect(sg.dailyAmount, 500); // returns remainingAmount
    });
  });
}
