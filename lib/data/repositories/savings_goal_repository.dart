import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/savings_goal.dart';

class SavingsGoalRepository {
  Box<SavingsGoal> get _box =>
      Hive.box<SavingsGoal>(HiveBoxes.savingsGoals);
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

  Future<void> confirmContribution(SavingsGoal goal, {DateTime? date, double? amount}) async {
    final target = date ?? DateTime.now();
    final d = DateTime(target.year, target.month, target.day);
    if (!goal.canConfirm(d)) return;
    final amt = amount ?? goal.dailyAmount;
    goal.contributionDates.add(d);
    goal.contributionAmounts.add(amt);
    goal.touch();
    await _box.put(goal.id, goal);
  }

  /// Recalculate targetDays: shrink the window to remaining days and
  /// let [dailyAmount] be recomputed from the new remaining amount / days.
  /// Persists the updated [targetDays] via the Hive box.
  Future<void> recalculate(SavingsGoal goal) async {
    // remainingDays is already computed from daysElapsed vs targetDays.
    // We set targetDays = daysElapsed so remainingDays becomes 1 (today
    // still counts).  But the spec says: miss day 1, recalculate →
    // remaining 4 days.  So we set targetDays so that remainingDays
    // equals the actual days left *excluding today if already missed*.
    //
    // Simpler interpretation: after recalculating, the remaining window
    // is (original targetDays - daysElapsed).  We store the new
    // targetDays = daysElapsed + remainingWindow so that
    // remainingDays == remainingWindow.
    final remainingWindow = goal.targetDays - goal.daysElapsed;
    if (remainingWindow <= 0) return;
    // Keep startDate the same; set targetDays so that
    // remainingDays = remainingWindow.
    // remainingDays = targetDays - daysElapsed → targetDays = daysElapsed + remainingWindow
    goal.targetDays = goal.daysElapsed + remainingWindow;
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> update(SavingsGoal goal) async {
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> delete(String id) async => _box.delete(id);
}
