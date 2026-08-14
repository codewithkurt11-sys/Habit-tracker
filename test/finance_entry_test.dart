import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/finance_entry.dart';

void main() {
  group('FinanceEntry copyWith', () {
    test('copies title correctly', () {
      final entry = FinanceEntry(
        id: 'f1',
        title: 'Original',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
      );
      final copied = entry.copyWith(title: 'Updated');
      expect(copied.title, 'Updated');
      expect(copied.amount, 100); // preserved
      expect(copied.id, 'f1'); // preserved
    });

    test('copies amount correctly', () {
      final entry = FinanceEntry(
        id: 'f2',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
      );
      final copied = entry.copyWith(amount: 200);
      expect(copied.amount, 200);
      expect(copied.title, 'Test'); // preserved
    });

    test('clearGoalId sets goalId to null', () {
      final entry = FinanceEntry(
        id: 'f3',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
        goalId: 'goal123',
      );
      final copied = entry.copyWith(clearGoalId: true);
      expect(copied.goalId, isNull);
    });

    test('copyWith preserves contribution logs', () {
      final entry = FinanceEntry(
        id: 'f4',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
        contributionLogDates: [DateTime(2025, 1, 1)],
        contributionLogAmounts: [50],
        contributionLogConfirmed: [true],
      );
      final copied = entry.copyWith(title: 'Updated');
      expect(copied.contributionLogDates.length, 1);
      expect(copied.contributionLogAmounts.length, 1);
      expect(copied.contributionLogConfirmed.length, 1);
    });

    test('copyWith updates updatedAt', () {
      // Use a deterministic old timestamp so the assertion cannot
      // pass by coincidence when both run in the same millisecond.
      final oldTimestamp = DateTime(2020, 1, 1);
      final entry = FinanceEntry(
        id: 'f5',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
        updatedAt: oldTimestamp,
      );
      final copied = entry.copyWith(title: 'Updated');
      expect(copied.updatedAt, isNot(oldTimestamp));
    });
  });

  group('FinanceEntry touch', () {
    test('touch updates updatedAt', () {
      final oldTimestamp = DateTime(2020, 1, 1);
      final entry = FinanceEntry(
        id: 'f6',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
        updatedAt: oldTimestamp,
      );
      entry.touch();
      expect(entry.updatedAt, isNot(oldTimestamp));
    });
  });

  group('FinanceEntry properties', () {
    test('isIncome returns true for income type', () {
      final entry = FinanceEntry(
        id: 'f7',
        title: 'Salary',
        amount: 5000,
        typeIndex: 0, // income
        categoryIndex: 0,
        date: DateTime(2025, 1, 1),
      );
      expect(entry.isIncome, true);
    });

    test('isIncome returns false for expense type', () {
      final entry = FinanceEntry(
        id: 'f8',
        title: 'Rent',
        amount: 1000,
        typeIndex: 1, // expense
        categoryIndex: 0,
        date: DateTime(2025, 1, 1),
      );
      expect(entry.isIncome, false);
    });
  });
}
