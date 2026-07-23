import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/models/goal.dart';
import '../../data/models/schedule_item.dart';

/// Pure computed view over Habit/Task/Schedule data (local or a friend's
/// streamed data). Computes a `Map<DateTime, int>` activity count per day.
///
/// Activity rule (locked in during design):
/// - Habit: +1 per day present in `completionLog`
/// - Task: +1 on `completedAt`'s day, if set
/// - Schedule item: +1 on `dateTime`'s day, if `done == true`
/// - Goal: excluded (no reliable per-day completion timestamp).
class HeatmapEngine {
  HeatmapEngine._();

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Compute the activity map from local models.
  static Map<DateTime, int> compute({
    List<Habit> habits = const [],
    List<Task> tasks = const [],
    List<Goal> goals = const [],
    List<ScheduleItem> schedule = const [],
  }) {
    final map = <DateTime, int>{};
    void bump(DateTime day) {
      final key = _dayKey(day);
      map[key] = (map[key] ?? 0) + 1;
    }

    for (final h in habits) {
      for (final d in h.completionLog) {
        bump(d);
      }
    }
    for (final t in tasks) {
      if (t.completedAt != null) bump(t.completedAt!);
    }
    for (final s in schedule) {
      if (s.done) bump(s.dateTime);
    }
    // Goals excluded by design.
    return map;
  }

  /// Compute the activity map from raw cloud data (for friend's data).
  static Map<DateTime, int> computeFromCloud({
    List<Map<String, dynamic>> habits = const [],
    List<Map<String, dynamic>> tasks = const [],
    List<Map<String, dynamic>> goals = const [],
    List<Map<String, dynamic>> schedule = const [],
  }) {
    final map = <DateTime, int>{};
    void bump(DateTime day) {
      final key = _dayKey(day);
      map[key] = (map[key] ?? 0) + 1;
    }

    for (final h in habits) {
      final log = (h['completionLog'] as List?) ?? [];
      for (final s in log) {
        final d = s is Timestamp ? s.toDate() : DateTime.tryParse(s.toString());
        if (d != null) bump(d);
      }
    }
    for (final t in tasks) {
      final ca = t['completedAt'];
      if (ca != null) {
        final d =
            ca is Timestamp ? ca.toDate() : DateTime.tryParse(ca.toString());
        if (d != null) bump(d);
      }
    }
    for (final s in schedule) {
      final done = s['done'] as bool? ?? false;
      if (done) {
        final dt = s['dateTime'];
        final d =
            dt is Timestamp ? dt.toDate() : DateTime.tryParse(dt.toString());
        if (d != null) bump(d);
      }
    }
    return map;
  }
}

/// GitHub-style heatmap widget. One column per week, row per weekday
/// (Sun top, Sat bottom), ~53 weeks, horizontally scrollable, color
/// intensity bucketed into ~4 levels.
///
/// Accepts a plain `Map<DateTime, int>` and has zero knowledge of where the
/// data came from — serves both "my activity" and "friend's activity".
class HeatmapWidget extends StatelessWidget {
  final Map<DateTime, int> activity;
  final Color baseColor;

  const HeatmapWidget(
      {super.key,
      required this.activity,
      this.baseColor = const Color(0xFF6B9080)});

  // Note on week alignment: a naive `6 - weekday % 7` breaks on Sunday
  // (7 % 7 == 0 doesn't map the way that formula intends). We use an explicit
  // day-of-week -> row lookup in the build method below instead of modulo
  // arithmetic, and manually traced all 7 cases.

  /// Returns the date of the Sunday that begins the week containing [date].
  static DateTime _sundayOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final weekday = d.weekday; // 1=Mon..7=Sun
    // Days since Sunday: Mon=1,Tue=2,...,Sat=6,Sun=0
    final daysSinceSunday = weekday == 7 ? 0 : weekday;
    return d.subtract(Duration(days: daysSinceSunday));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // The end of the current week (the Sunday of this week).
    final thisWeekSunday = _sundayOfWeek(today);

    // Show ~53 weeks (about a year) ending at the current week.
    const numWeeks = 53;
    final firstWeekSunday =
        thisWeekSunday.subtract(const Duration(days: 7 * (numWeeks - 1)));

    // Build a 7-row x numWeeks-column grid of counts.
    // cell[col][row] = activity count for that day.
    final grid =
        List<List<int>>.generate(numWeeks, (_) => List<int>.filled(7, 0));
    final cellDates = List<List<DateTime?>>.generate(
        numWeeks, (_) => List<DateTime?>.filled(7, null));

    for (var col = 0; col < numWeeks; col++) {
      final weekSunday = firstWeekSunday.add(Duration(days: 7 * col));
      for (var row = 0; row < 7; row++) {
        final day = weekSunday.add(Duration(days: row));
        cellDates[col][row] = day;
        final key = DateTime(day.year, day.month, day.day);
        if (key.isAfter(todayKey)) continue; // don't show future days
        grid[col][row] = activity[key] ?? 0;
      }
    }

    // Determine max for bucketing (min 1 to avoid div-by-zero).
    var maxCount = 1;
    for (final col in grid) {
      for (final v in col) {
        if (v > maxCount) maxCount = v;
      }
    }

    Color cellColor(int count) {
      if (count == 0) {
        return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
      }
      // 4 intensity levels.
      final ratio = count / maxCount;
      int level;
      if (ratio <= 0.25) {
        level = 1;
      } else if (ratio <= 0.5) {
        level = 2;
      } else if (ratio <= 0.75) {
        level = 3;
      } else {
        level = 4;
      }
      final alpha = 0.25 + (level * 0.1875); // ~0.44, 0.625, 0.81, 1.0
      return baseColor.withValues(alpha: alpha.clamp(0.0, 1.0));
    }

    const cellSize = 13.0;
    const cellGap = 3.0;
    const rowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return SizedBox(
      height: 7 * (cellSize + cellGap) + 24,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // most recent on the right
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grid
            SizedBox(
              height: 7 * (cellSize + cellGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekday labels column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final label in rowLabels)
                        SizedBox(
                          height: cellSize + cellGap,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 8,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Week columns
                  for (var col = 0; col < numWeeks; col++)
                    Column(
                      children: [
                        for (var row = 0; row < 7; row++)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: cellGap, right: cellGap),
                            child: Tooltip(
                              message: _tooltipMessage(
                                  cellDates[col][row], grid[col][row]),
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: cellColor(grid[col][row]),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              children: [
                Text(
                  'Less',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                for (final lvl in [0, 1, 2, 3, 4])
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: lvl == 0
                            ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4)
                            : cellColor(lvl == 0
                                ? 0
                                : (lvl * maxCount ~/ 4).clamp(1, maxCount)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  'More',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _tooltipMessage(DateTime? day, int count) {
    if (day == null) return '';
    final d =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return '$d: $count activit${count == 1 ? 'y' : 'ies'}';
  }
}
