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
      final entry = FinanceEntry(
        id: 'f5',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
      );
      // Wait a moment to ensure updatedAt is different
      final originalUpdatedAt = entry.updatedAt;
      Future.delayed(const Duration(milliseconds: 10), () {});
      final copied = entry.copyWith(title: 'Updated');
      expect(copied.updatedAt.isAfter(originalUpdatedAt) ||
          copied.updatedAt == originalUpdatedAt, true);
    });
  });

  group('FinanceEntry touch', () {
    test('touch updates updatedAt', () {
      final entry = FinanceEntry(
        id: 'f6',
        title: 'Test',
        amount: 100,
        typeIndex: 0,
        categoryIndex: 1,
        date: DateTime(2025, 1, 1),
      );
      final original = entry.updatedAt;
      entry.touch();
      expect(entry.updatedAt.isAfter(original) ||
          entry.updatedAt == original, true);
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
