import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/models/focus_session.dart';
import '../data/models/finance_entry.dart';
import '../data/models/goal.dart';
import '../data/models/journal_entry.dart';

/// Centralized statistics engine that computes habit trends, streaks,
/// completion rates, focus analytics, and finance summaries.
///
/// All methods are pure functions operating on data already loaded by
/// repositories — no Hive or async calls here.
class StatsEngine {
  StatsEngine._();

  // ─── Habit Statistics ───────────────────────────────────────────

  /// Returns the number of habits completed on [date].
  static int habitsCompletedOnDay(List<Habit> habits, DateTime date) {
    return habits.where((h) => h.isCompletedOn(date)).length;
  }

  /// Returns the number of habits due on [date].
  static int habitsDueOnDay(List<Habit> habits, DateTime date) {
    return habits.where((h) => h.isDueOn(date)).length;
  }

  /// Completion rate for a single day (0.0–1.0). Returns 0 if no habits due.
  static double dayCompletionRate(List<Habit> habits, DateTime date) {
    final due = habitsDueOnDay(habits, date);
    if (due == 0) return 0;
    return habitsCompletedOnDay(habits, date) / due;
  }

  /// Last [days] days of completion counts (oldest first).
  static List<int> dailyCompletionCounts(List<Habit> habits, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(habitsCompletedOnDay(habits, date));
    }
    return result;
  }

  /// Weekly completion counts for the last [weeks] weeks (oldest first).
  /// Each value is the total completions across all habits for that week.
  static List<int> weeklyCompletionCounts(List<Habit> habits, int weeks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>[];
    for (int w = weeks - 1; w >= 0; w--) {
      final weekStart =
          today.subtract(Duration(days: today.weekday - 1 + w * 7));
      var count = 0;
      for (int d = 0; d < 7; d++) {
        final date = weekStart.add(Duration(days: d));
        if (!date.isAfter(today)) {
          count += habitsCompletedOnDay(habits, date);
        }
      }
      result.add(count);
    }
    return result;
  }

  /// Monthly completion counts for the last [months] months (oldest first).
  static List<int> monthlyCompletionCounts(List<Habit> habits, int months) {
    final now = DateTime.now();
    final result = <int>[];
    for (int m = months - 1; m >= 0; m--) {
      final monthDate = DateTime(now.year, now.month - m, 1);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
      var count = 0;
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(monthDate.year, monthDate.month, d);
        if (!date.isAfter(now)) {
          count += habitsCompletedOnDay(habits, date);
        }
      }
      result.add(count);
    }
    return result;
  }

  /// Overall completion rate across all habits (last 30 days).
  static double overallCompletionRate(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    var total = 0.0;
    for (final h in habits) {
      total += h.completionRate(days: 30);
    }
    return total / habits.length;
  }

  /// Best streak across all habits.
  static int bestStreakAcross(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    return habits.fold(
        0, (max, h) => h.bestStreak() > max ? h.bestStreak() : max);
  }

  /// Current streak across all habits (max of current streaks).
  static int currentStreakAcross(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    return habits.fold(0, (max, h) {
      final s = h.currentStreak();
      return s > max ? s : max;
    });
  }

  /// Returns the heatmap intensity for a given date (0–4 scale).
  /// 0 = no activity, 1-4 = increasing levels of habit completions.
  static int heatLevel(List<Habit> habits, DateTime date) {
    final count = habitsCompletedOnDay(habits, date);
    final due = habitsDueOnDay(habits, date);
    if (due == 0 && count == 0) return 0;
    if (count == 0) return 0;
    if (count == 1) return 1;
    if (count <= 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  /// Builds a list of (date, level) pairs for the last [days] days.
  static List<HeatCell> heatMap(List<Habit> habits, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <HeatCell>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(HeatCell(
        date: date,
        level: heatLevel(habits, date),
        completed: habitsCompletedOnDay(habits, date),
        due: habitsDueOnDay(habits, date),
      ));
    }
    return result;
  }

  // ─── Task Statistics ────────────────────────────────────────────

  static int tasksCompletedOnDay(List<Task> tasks, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return tasks.where((t) {
      if (t.completedAt == null) return false;
      final cd = DateTime(
          t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      return cd.isAtSameMomentAs(d);
    }).length;
  }

  static int tasksDueOnDay(List<Task> tasks, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return tasks.where((t) {
      if (t.dueDate == null) return false;
      final td = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return td.isAtSameMomentAs(d);
    }).length;
  }

  static int overdueTasks(List<Task> tasks) {
    return tasks.where((t) => t.isOverdue).length;
  }

  static Map<TaskPriority, int> tasksByPriority(List<Task> tasks) {
    final map = <TaskPriority, int>{};
    for (final t in tasks) {
      if (t.status != TaskStatus.done && !t.archived) {
        map[t.priority] = (map[t.priority] ?? 0) + 1;
      }
    }
    return map;
  }

  // ─── Focus Statistics ───────────────────────────────────────────

  static int totalFocusMinutes(List<FocusSession> sessions) {
    return sessions.fold(0, (sum, s) => sum + s.completedSeconds ~/ 60);
  }

  static int focusMinutesOnDay(List<FocusSession> sessions, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return sessions
        .where((s) =>
            s.startedAt.year == d.year &&
            s.startedAt.month == d.month &&
            s.startedAt.day == d.day)
        .fold(0, (sum, s) => sum + s.completedSeconds ~/ 60);
  }

  /// Daily focus minutes for the last [days] days (oldest first).
  static List<int> dailyFocusMinutes(List<FocusSession> sessions, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(focusMinutesOnDay(sessions, date));
    }
    return result;
  }

  static int completedPomodoros(List<FocusSession> sessions) {
    return sessions
        .where((s) => s.type == FocusType.pomodoro && s.completed)
        .length;
  }

  // ─── Finance Statistics ─────────────────────────────────────────

  static double monthlyBalance(
      List<FinanceEntry> entries, int year, int month) {
    final income = entries
        .where(
            (e) => e.isIncome && e.date.year == year && e.date.month == month)
        .fold(0.0, (s, e) => s + e.amount);
    final expenses = entries
        .where(
            (e) => !e.isIncome && e.date.year == year && e.date.month == month)
        .fold(0.0, (s, e) => s + e.amount);
    return income - expenses;
  }

  static double monthlyIncome(List<FinanceEntry> entries, int year, int month) {
    return entries
        .where(
            (e) => e.isIncome && e.date.year == year && e.date.month == month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  static double monthlyExpenses(
      List<FinanceEntry> entries, int year, int month) {
    return entries
        .where(
            (e) => !e.isIncome && e.date.year == year && e.date.month == month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  /// Expense breakdown by category for a given month.
  static Map<String, double> expenseByCategory(
      List<FinanceEntry> entries, int year, int month) {
    final map = <String, double>{};
    for (final e in entries) {
      if (!e.isIncome && e.date.year == year && e.date.month == month) {
        map[e.categoryLabel] = (map[e.categoryLabel] ?? 0) + e.amount;
      }
    }
    // Sort by value descending
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  /// Last 6 months expense totals (oldest first).
  static List<double> monthlyExpenseTrend(List<FinanceEntry> entries) {
    final now = DateTime.now();
    final result = <double>[];
    for (int m = 5; m >= 0; m--) {
      final monthDate = DateTime(now.year, now.month - m, 1);
      result.add(monthlyExpenses(entries, monthDate.year, monthDate.month));
    }
    return result;
  }

  /// Last 6 months income totals (oldest first).
  static List<double> monthlyIncomeTrend(List<FinanceEntry> entries) {
    final now = DateTime.now();
    final result = <double>[];
    for (int m = 5; m >= 0; m--) {
      final monthDate = DateTime(now.year, now.month - m, 1);
      result.add(monthlyIncome(entries, monthDate.year, monthDate.month));
    }
    return result;
  }

  // ─── Goal Statistics ────────────────────────────────────────────

  static int activeGoals(List<Goal> goals) {
    return goals.where((g) => !g.completed && !g.archived).length;
  }

  static int completedGoals(List<Goal> goals) {
    return goals.where((g) => g.completed && !g.archived).length;
  }

  static double averageGoalProgress(List<Goal> goals) {
    final active = goals.where((g) => !g.completed && !g.archived).toList();
    if (active.isEmpty) return 0;
    return active.fold(0.0, (s, g) => s + g.progressFraction) / active.length;
  }

  // ─── Journal Statistics ─────────────────────────────────────────

  static Map<int, int> moodDistribution(List<JournalEntry> entries) {
    final map = <int, int>{};
    for (final e in entries) {
      if (e.moodIndex >= 0) {
        map[e.moodIndex] = (map[e.moodIndex] ?? 0) + 1;
      }
    }
    return map;
  }

  // ─── Insight Generation ─────────────────────────────────────────

  /// Generates human-readable insights from the data.
  static List<HabitInsight> generateInsights({
    required List<Habit> habits,
    required List<Task> tasks,
    required List<FocusSession> focusSessions,
  }) {
    final insights = <HabitInsight>[];

    // Best streak insight
    final best = bestStreakAcross(habits);
    if (best > 0) {
      insights.add(HabitInsight(
        icon: '🔥',
        title: 'Best Streak: $best days',
        description:
            'Your longest habit streak is $best consecutive days. Keep it going!',
        type: InsightType.achievement,
      ));
    }

    // Current streak insight
    final current = currentStreakAcross(habits);
    if (current > 0) {
      insights.add(HabitInsight(
        icon: '⚡',
        title: 'Current Streak: $current days',
        description:
            'You\'re on a $current-day streak. Don\'t break the chain!',
        type: InsightType.streak,
      ));
    }

    // Completion rate insight
    final rate = overallCompletionRate(habits);
    if (rate > 0) {
      final pct = (rate * 100).round();
      insights.add(HabitInsight(
        icon: '📊',
        title: '30-Day Completion: $pct%',
        description: pct >= 80
            ? 'Excellent consistency! You\'re completing $pct% of your habits.'
            : pct >= 50
                ? 'Good progress at $pct%. Push for 80% to level up!'
                : 'You\'re at $pct%. Every check-in counts — keep going!',
        type: InsightType.progress,
      ));
    }

    // Focus insight
    final focusMin = totalFocusMinutes(focusSessions);
    if (focusMin > 0) {
      final hours = (focusMin / 60).toStringAsFixed(1);
      insights.add(HabitInsight(
        icon: '🎯',
        title: 'Total Focus: ${hours}h',
        description:
            'You\'ve focused for $focusMin minutes ($hours hours) total.',
        type: InsightType.focus,
      ));
    }

    // Overdue tasks insight
    final overdue = overdueTasks(tasks);
    if (overdue > 0) {
      insights.add(HabitInsight(
        icon: '⚠️',
        title: '$overdue Overdue Task${overdue > 1 ? 's' : ''}',
        description:
            'You have $overdue overdue task${overdue > 1 ? 's' : ''}. Consider rescheduling or completing them.',
        type: InsightType.warning,
      ));
    }

    return insights;
  }
}

/// A single cell in the heatmap grid.
class HeatCell {
  final DateTime date;
  final int level; // 0-4
  final int completed;
  final int due;

  const HeatCell({
    required this.date,
    required this.level,
    required this.completed,
    required this.due,
  });
}

enum InsightType { achievement, streak, progress, focus, warning, tip }

class HabitInsight {
  final String icon;
  final String title;
  final String description;
  final InsightType type;

  const HabitInsight({
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
  });
}
