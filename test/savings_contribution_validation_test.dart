import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/savings_goal.dart';

SavingsGoal _goal({
  required DateTime startDate,
  int targetDays = 10,
  List<DateTime>? dates,
  List<double>? amounts,
}) =>
    SavingsGoal(
      id: 's',
      title: 'Savings',
      targetAmount: 100,
      targetDays: targetDays,
      startDate: startDate,
      contributionDates: dates,
      contributionAmounts: amounts,
    );

void main() {
  final today = DateTime(2026, 3, 10);
  final start = DateTime(2026, 3, 5); // window 2026-03-05 .. 2026-03-14

  group('SavingsGoal.canConfirm', () {
    test('accepts a valid past date inside the window', () {
      final sg = _goal(startDate: start);
      expect(sg.canConfirm(DateTime(2026, 3, 7), today: today), isTrue);
    });

    test('accepts today', () {
      final sg = _goal(startDate: start);
      expect(sg.canConfirm(today, today: today), isTrue);
    });

    test('rejects a future date', () {
      final sg = _goal(startDate: start);
      expect(sg.canConfirm(DateTime(2026, 3, 11), today: today), isFalse);
    });

    test('rejects a date before startDate', () {
      final sg = _goal(startDate: start);
      expect(sg.canConfirm(DateTime(2026, 3, 4), today: today), isFalse);
    });

    test('rejects a date after the savings window ends', () {
      // 3-day window starting 2026-03-05 ends 2026-03-07.
      final sg = _goal(startDate: start, targetDays: 3);
      expect(sg.canConfirm(DateTime(2026, 3, 8), today: today), isFalse);
      expect(sg.canConfirm(DateTime(2026, 3, 7), today: today), isTrue);
    });

    test('rejects a duplicate contribution date', () {
      final sg = _goal(
        startDate: start,
        dates: [DateTime(2026, 3, 6)],
        amounts: [10],
      );
      expect(sg.canConfirm(DateTime(2026, 3, 6), today: today), isFalse);
    });

    test('ignores time-of-day when comparing dates', () {
      final sg = _goal(
        startDate: DateTime(2026, 3, 5, 23, 59),
        dates: [DateTime(2026, 3, 6, 8, 30)],
        amounts: [10],
      );
      // Same calendar day, different time -> still a duplicate.
      expect(
        sg.canConfirm(DateTime(2026, 3, 6, 21, 15), today: today),
        isFalse,
      );
      // Start date with a late time must not exclude the start day itself.
      expect(sg.canConfirm(DateTime(2026, 3, 5, 1), today: today), isTrue);
    });

    test('future contributions cannot inflate count/total/variance', () {
      final sg = _goal(startDate: start);
      expect(sg.canConfirm(DateTime(2026, 3, 30), today: today), isFalse);
      expect(sg.confirmedCount, 0);
      expect(sg.totalContributed, 0);
    });
  });

  group('contribution list integrity', () {
    test('confirmedCount and totalContributed agree on corrupt data', () {
      // 3 dates but only 2 amounts.
      final sg = _goal(
        startDate: start,
        dates: [
          DateTime(2026, 3, 5),
          DateTime(2026, 3, 6),
          DateTime(2026, 3, 7),
        ],
        amounts: [10, 20],
      );
      expect(sg.confirmedCount, 2);
      expect(sg.totalContributed, 30);
    });

    test('normalizeContributions truncates mismatched lists', () {
      final sg = _goal(
        startDate: start,
        dates: [DateTime(2026, 3, 5), DateTime(2026, 3, 6)],
        amounts: [10],
      );
      expect(sg.normalizeContributions(), isTrue);
      expect(sg.contributionDates.length, sg.contributionAmounts.length);
      expect(sg.contributionDates.length, 1);
      expect(sg.totalContributed, 10);
    });

    test('normalizeContributions drops duplicate days and bad amounts', () {
      final sg = _goal(
        startDate: start,
        dates: [
          DateTime(2026, 3, 5, 9),
          DateTime(2026, 3, 5, 18), // duplicate day
          DateTime(2026, 3, 6),
        ],
        amounts: [10, 99, -5], // negative amount is dropped
      );
      sg.normalizeContributions();
      expect(sg.contributionDates.length, 1);
      expect(sg.contributionAmounts, [10]);
      expect(sg.confirmedCount, 1);
      expect(sg.totalContributed, 10);
    });

    test('normalizeContributions stores date-only values', () {
      final sg = _goal(
        startDate: start,
        dates: [DateTime(2026, 3, 5, 14, 22, 11)],
        amounts: [10],
      );
      sg.normalizeContributions();
      expect(sg.contributionDates.single, DateTime(2026, 3, 5));
    });

    test('variance status cannot be gamed by corrupt list lengths', () {
      final sg = _goal(
        startDate: start,
        dates: [
          DateTime(2026, 3, 5),
          DateTime(2026, 3, 6),
          DateTime(2026, 3, 7),
          DateTime(2026, 3, 8),
        ],
        amounts: const [], // no amounts at all
      );
      expect(sg.confirmedCount, 0);
      expect(sg.totalContributed, 0);
      expect(sg.progressFraction, 0);
    });
  });
}
