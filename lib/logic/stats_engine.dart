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
    final dueHabits = habits.where((habit) => habit.isDueOn(date)).toList();
    if (dueHabits.isEmpty) return 0;
    final completed =
        dueHabits.where((habit) => habit.isCompletedOn(date)).length;
    return completed / dueHabits.length;
  }

  /// Last [days] days of completion counts (oldest first).
  static List<int> dailyCompletionCounts(List<Habit> habits, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
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
      final weekStart = DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1 + w * 7),
      );
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
    final stats = habitWindowStats(habits, days: 30);
    if (stats.due == 0) return 0;
    return stats.completed / stats.due;
  }

  /// Consistency score (0–100): a composite measure combining 30-day
  /// completion rate, streak longevity, and miss-streak penalty.
  /// Designed to give users a single number summarizing how consistent
  /// they are with their habits — minimal, no gamification.
  static int consistencyScore(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    // 30-day completion rate component (0-60 points)
    final completionRate = overallCompletionRate(habits);
    final completionScore = (completionRate * 60).round();

    // Current streak component (0-30 points, capped at 30 days)
    final averageCurrentStreak = habits.isEmpty
        ? 0.0
        : habits.map((h) => h.currentStreak()).reduce((a, b) => a + b) / habits.length;
    final streakScore = (averageCurrentStreak.clamp(0, 30) / 30 * 30).round().clamp(0, 30);

    // Miss-streak penalty (0-10 points, reduces with more misses)
    final averageMissStreak = habits.isEmpty
        ? 0.0
        : habits.map((h) => h.currentMissStreak()).reduce((a, b) => a + b) / habits.length;
    final missPenalty = (averageMissStreak * 2).round().clamp(0, 10);

    final score = (completionScore + streakScore - missPenalty).clamp(0, 100);
    return score;
  }

  /// Longest recorded run of consecutive completions across all habits.
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

  /// Builds a list of (date, level) pairs covering roughly the last [days]
  /// days, **week-aligned to Monday**.
  ///
  /// The UI renders these cells as columns of 7 with Mon/Wed/Fri row labels, so
  /// the first cell must be a Monday and the last a Sunday. Simply emitting
  /// `today - days + 1 .. today` put an arbitrary weekday in row 0, which made
  /// every row label wrong. Instead we start on the Monday of the week that is
  /// `ceil(days / 7) - 1` weeks before the current week and always emit whole
  /// Mon–Sun weeks. Future days in the current week are included so the grid
  /// stays rectangular; they simply have level 0.
  static List<HeatCell> heatMap(List<Habit> habits, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeks = (days / 7).ceil().clamp(1, 520).toInt();
    // Monday of the current week (DateTime.weekday: Mon=1 .. Sun=7).
    final thisMonday =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final firstMonday = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7 * (weeks - 1),
    );
    final total = weeks * 7;
    final result = <HeatCell>[];
    for (int i = 0; i < total; i++) {
      final date =
          DateTime(firstMonday.year, firstMonday.month, firstMonday.day + i);
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

  /// Completion rate for tasks with a meaningful lifecycle (done / all non-archived).
  static double taskCompletionRate(List<Task> tasks) {
    final visible = tasks.where((t) => !t.archived).toList();
    if (visible.isEmpty) return 0;
    return visible.where((t) => t.status == TaskStatus.done).length / visible.length;
  }

  /// Returns a due/completed/skipped snapshot for a habit window.
  static ({int due, int completed, int skipped, int missed}) habitWindowStats(
      List<Habit> habits, {int days = 30, DateTime? asOf}) {
    final value = asOf ?? DateTime.now();
    final end = DateTime(value.year, value.month, value.day);
    final start = end.subtract(Duration(days: days - 1));
    var due = 0, completed = 0, skipped = 0;
    for (final habit in habits) {
      var cursor = start.isAfter(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))
          ? start
          : DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      while (!cursor.isAfter(end)) {
        if (habit.isDueOn(cursor)) {
          due++;
          if (habit.isCompletedOn(cursor)) {
            completed++;
          } else if (habit.isSkippedOn(cursor)) {
            skipped++;
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return (due: due, completed: completed, skipped: skipped, missed: due - completed - skipped);
  }

  /// Goals completed divided by goals created/active, useful as a simple
  /// outcome metric rather than averaging progress percentages.
  static double goalCompletionRate(List<Goal> goals) {
    final visible = goals.where((g) => !g.archived).toList();
    if (visible.isEmpty) return 0;
    return visible.where((g) => g.completed).length / visible.length;
  }

  // ─── Focus Statistics ───────────────────────────────────────────

  static int totalFocusMinutes(List<FocusSession> sessions) {
    final seconds =
        sessions.fold<int>(0, (sum, session) => sum + session.completedSeconds);
    return seconds ~/ 60;
  }

  static int focusMinutesOnDay(List<FocusSession> sessions, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final seconds = sessions
        .where((s) =>
            s.startedAt.year == d.year &&
            s.startedAt.month == d.month &&
            s.startedAt.day == d.day)
        .fold<int>(0, (sum, session) => sum + session.completedSeconds);
    return seconds ~/ 60;
  }

  /// Daily focus minutes for the last [days] days (oldest first).
  static List<int> dailyFocusMinutes(List<FocusSession> sessions, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
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

    // Longest run insight (neutral, factual — no streak pressure copy).
    final best = bestStreakAcross(habits);
    if (best > 0) {
      insights.add(HabitInsight(
        icon: '',
        title: 'Longest Run: $best days',
        description:
            'Your longest recorded run of consecutive completions is $best days.',
        type: InsightType.achievement,
      ));
    }

    // Current streak insight
    final current = currentStreakAcross(habits);
    if (current > 0) {
      insights.add(HabitInsight(
        icon: '',
        title: 'Current Run: $current days',
        description:
            'You have completed habits on $current consecutive days so far.',
        type: InsightType.streak,
      ));
    }

    // Completion rate insight
    final rate = overallCompletionRate(habits);
    if (rate > 0) {
      final pct = (rate * 100).round();
      insights.add(HabitInsight(
        icon: '',
        title: '30-Day Completion: $pct%',
        description:
            'You completed $pct% of your scheduled habit days in the last 30 days.',
        type: InsightType.progress,
      ));
    }

    // Focus insight
    final focusMin = totalFocusMinutes(focusSessions);
    if (focusMin > 0) {
      final hours = (focusMin / 60).toStringAsFixed(1);
      insights.add(HabitInsight(
        icon: '',
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
        icon: '',
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
