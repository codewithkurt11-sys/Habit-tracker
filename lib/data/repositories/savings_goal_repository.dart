import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/savings_goal.dart';

class SavingsGoalRepository {
  Box<SavingsGoal> get _box => Hive.box<SavingsGoal>(HiveBoxes.savingsGoals);
  final _uuid = const Uuid();

  List<SavingsGoal> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  SavingsGoal? getById(String id) {
    try {
      return _box.values.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<SavingsGoal> getForGoal(String goalId) =>
      getAll().where((s) => s.goalId == goalId).toList();

  Future<SavingsGoal> create({
    required String title,
    required double targetAmount,
    required int targetDays,
    DateTime? startDate,
    String? goalId,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      title: title,
      targetAmount: targetAmount,
      targetDays: targetDays,
      startDate: startDate ?? DateTime.now(),
      goalId: goalId,
    );
    await _box.put(goal.id, goal);
    return goal;
  }

  /// Logs a contribution for [date] (defaults to today).
  ///
  /// Returns true when a contribution was recorded. Invalid dates (before the
  /// start date, in the future, outside the savings window, or already
  /// confirmed) are rejected so progress/variance can't be inflated.
  Future<bool> confirmContribution(SavingsGoal goal,
      {DateTime? date, double? amount}) async {
    final d = SavingsGoal.dayOf(date ?? DateTime.now());
    // Repair any malformed legacy lists before appending to them.
    goal.normalizeContributions();
    if (!goal.canConfirm(d)) {
      await _box.put(goal.id, goal);
      return false;
    }
    final amt = amount ?? goal.dailyAmount;
    if (amt.isNaN || amt.isInfinite || amt < 0) return false;
    // Append to both lists together so their lengths always match.
    goal.contributionDates.add(d);
    goal.contributionAmounts.add(amt);
    goal.touch();
    await _box.put(goal.id, goal);
    return true;
  }

  /// Recalculates the savings window: resets [startDate] to today and
  /// sets [targetDays] to the remaining days from the original window.
  /// This causes [dailyAmount] to recompute as remainingAmount / remainingDays,
  /// effectively increasing the per-day requirement for missed days.
  ///
  /// Example: ₱500 / 5 days = ₱100/day.  After 1 elapsed day with ₱0
  /// contributed: remainingWindow = 4, new dailyAmount = ₱500/4 = ₱125.
  /// If ₱100 was contributed: dailyAmount = ₱400/4 = ₱100.
  Future<void> recalculate(SavingsGoal goal) async {
    final remainingWindow = goal.targetDays - goal.daysElapsed;
    if (remainingWindow <= 0) return;
    final now = DateTime.now();
    goal.startDate = DateTime(now.year, now.month, now.day);
    goal.targetDays = remainingWindow;
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> update(SavingsGoal goal) async {
    goal.normalizeContributions();
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> delete(String id) async => _box.delete(id);
}
