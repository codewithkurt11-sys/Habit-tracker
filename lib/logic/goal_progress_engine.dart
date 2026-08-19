import '../data/models/finance_entry.dart';
import '../data/models/goal.dart';
import '../data/models/habit.dart';
import '../data/models/savings_goal.dart';
import '../data/models/task.dart';

/// A consistent, deterministic snapshot of a goal's progress.
///
/// Habit-day goals count unique scheduled calendar days, not a rolling 30-day
/// completion percentage. This prevents a single completion from incorrectly
/// turning a 100-day goal into 100%.
class GoalProgressSnapshot {
  final GoalProgressMode mode;
  final double fraction;
  final double currentUnits;
  final double targetUnits;
  final Set<DateTime> scheduledDates;
  final Set<DateTime> completedDates;
  final Set<DateTime> skippedDates;
  final Set<DateTime> missedDates;
  final int completedTasks;
  final double financialAmount;

  const GoalProgressSnapshot({
    required this.mode,
    required this.fraction,
    required this.currentUnits,
    required this.targetUnits,
    required this.scheduledDates,
    required this.completedDates,
    required this.skippedDates,
    required this.missedDates,
    required this.completedTasks,
    required this.financialAmount,
  });

  double get remainingUnits => (targetUnits - currentUnits).clamp(0, targetUnits).toDouble();
}

class GoalProgressEngine {
  static GoalProgressMode resolveMode({
    required Goal goal,
    required List<Habit> habits,
    required List<Task> tasks,
    required List<FinanceEntry> finance,
    required List<SavingsGoal> savings,
  }) {
    if (goal.progressMode != GoalProgressMode.auto) return goal.progressMode;
    if (habits.isNotEmpty) return GoalProgressMode.habitDays;
    if (tasks.isNotEmpty) return GoalProgressMode.taskCount;
    if (finance.isNotEmpty || savings.isNotEmpty || goal.category == GoalCategory.finance) {
      return GoalProgressMode.financeAmount;
    }
    return GoalProgressMode.manual;
  }

  static GoalProgressSnapshot compute({
    required Goal goal,
    required List<Habit> habits,
    required List<Task> tasks,
    required List<FinanceEntry> finance,
    required List<SavingsGoal> savings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final start = _day(goal.startDate);
    final end = goal.deadline == null
        ? _day(now)
        : _day(goal.deadline!.isBefore(now) ? goal.deadline! : now);
    final mode = resolveMode(
      goal: goal,
      habits: habits,
      tasks: tasks,
      finance: finance,
      savings: savings,
    );

    final scheduled = <DateTime>{};
    final completed = <DateTime>{};
    final skipped = <DateTime>{};

    if (!end.isBefore(start)) {
      for (final habit in habits) {
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (habit.isDueOn(cursor)) {
            scheduled.add(cursor);
            if (habit.isCompletedOn(cursor)) {
              completed.add(cursor);
            } else if (habit.isSkippedOn(cursor)) {
              skipped.add(cursor);
            }
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }
    }

    // A completed day wins over skipped/missed status when multiple habits
    // are connected to the same goal.
    skipped.removeAll(completed);
    final missed = {...scheduled}..removeAll(completed)..removeAll(skipped);

    final target = goal.targetValue <= 0 ? 1.0 : goal.targetValue;
    double current;
    double financialAmount = 0;
    int completedTasks = 0;
    final habitFraction = completed.length / target;
    final taskCompleted = tasks.where((task) {
      final completedAt = task.completedAt;
      if (task.status != TaskStatus.done || completedAt == null) return false;
      final day = _day(completedAt);
      return !day.isBefore(start) && !day.isAfter(end);
    }).length;
    completedTasks = taskCompleted;
    final taskFraction = taskCompleted / target;

    switch (mode) {
      case GoalProgressMode.habitDays:
        current = completed.length.toDouble();
        break;
      case GoalProgressMode.taskCount:
        current = completedTasks.toDouble();
        break;
      case GoalProgressMode.financeAmount:
        financialAmount = finance
            .where((entry) {
              final day = _day(entry.date);
              return entry.isIncome && !day.isBefore(start) && !day.isAfter(end);
            })
            .fold(0.0, (sum, entry) => sum + entry.amount);
        for (final item in savings) {
          for (var i = 0; i < item.contributionAmounts.length; i++) {
            final date = i < item.contributionDates.length ? _day(item.contributionDates[i]) : null;
            if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
              financialAmount += item.contributionAmounts[i];
            }
          }
        }
        current = financialAmount;
        break;
      case GoalProgressMode.manual:
        current = goal.currentValue;
        break;
      case GoalProgressMode.auto:
        current = goal.currentValue;
        break;
      case GoalProgressMode.mixed:
        final sources = <double>[];
        if (habits.isNotEmpty) sources.add(habitFraction);
        if (tasks.isNotEmpty) sources.add(taskFraction);
        if (finance.isNotEmpty || savings.isNotEmpty) sources.add(financialAmount / target);
        current = sources.isEmpty ? goal.currentValue : sources.reduce((a, b) => a + b) / sources.length * target;
        break;
    }

    current = current.clamp(0.0, target).toDouble();
    return GoalProgressSnapshot(
      mode: mode,
      fraction: (current / target).clamp(0.0, 1.0),
      currentUnits: current,
      targetUnits: target,
      scheduledDates: scheduled,
      completedDates: completed,
      skippedDates: skipped,
      missedDates: missed,
      completedTasks: completedTasks,
      financialAmount: financialAmount,
    );
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
