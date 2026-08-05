import 'package:flutter/material.dart';
import '../../data/models/habit.dart';

/// Streak heatmap for a single habit — shows last ~12 weeks.
/// Color intensity = completed (full) vs skipped (half) vs missed (empty).
class HabitHeatmap extends StatelessWidget {
  final Habit habit;
  final Color baseColor;

  const HabitHeatmap({
    super.key,
    required this.habit,
    this.baseColor = const Color(0xFF6B9080),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    const numWeeks = 12;

    // Find Sunday of current week
    final weekday = today.weekday;
    final daysSinceSunday = weekday == 7 ? 0 : weekday;
    final thisWeekSunday = DateTime(
        today.year, today.month, today.day - daysSinceSunday);
    final firstWeekSunday = DateTime(
        thisWeekSunday.year, thisWeekSunday.month,
        thisWeekSunday.day - 7 * (numWeeks - 1));

    final grid = List<List<int>>.generate(
        numWeeks, (_) => List<int>.filled(7, 0)); // 0=none, 1=done, 2=skip

    for (var col = 0; col < numWeeks; col++) {
      final weekSunday = DateTime(
          firstWeekSunday.year, firstWeekSunday.month,
          firstWeekSunday.day + 7 * col);
      for (var row = 0; row < 7; row++) {
        final day = DateTime(
            weekSunday.year, weekSunday.month, weekSunday.day + row);
        final key = DateTime(day.year, day.month, day.day);
        if (key.isAfter(todayKey)) continue;
        if (habit.isCompletedOn(day)) {
          grid[col][row] = 1;
        } else if (habit.isSkippedOn(day)) {
          grid[col][row] = 2;
        }
      }
    }

    Color cellColor(int value) {
      if (value == 0) {
        if (!habit.isDueOn(DateTime(
          firstWeekSunday.year + (0), firstWeekSunday.month, firstWeekSunday.day))) {
          // not due — very faint
        }
        return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      }
      if (value == 1) return baseColor; // completed
      if (value == 2) return baseColor.withValues(alpha: 0.4); // skipped
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }

    const cellSize = 14.0;
    const cellGap = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: SizedBox(
        height: 7 * (cellSize + cellGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < numWeeks; col++)
              Column(
                children: [
                  for (var row = 0; row < 7; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: cellGap, right: cellGap),
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: cellColor(grid[col][row]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact calendar heatmap for finance contributions.
class FinanceHeatmap extends StatelessWidget {
  final List<DateTime> confirmedDays;
  final DateTime startDate;
  final int totalDays;
  final Color baseColor;

  const FinanceHeatmap({
    super.key,
    required this.confirmedDays,
    required this.startDate,
    required this.totalDays,
    this.baseColor = const Color(0xFF6B9080),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    // Build a set of confirmed day keys
    final confirmedSet = <DateTime>{};
    for (final d in confirmedDays) {
      confirmedSet.add(DateTime(d.year, d.month, d.day));
    }

    final weeks = (totalDays / 7).ceil() + 1;
    final todayWeekday = today.weekday;
    final daysSinceSunday = todayWeekday == 7 ? 0 : todayWeekday;
    final thisWeekSunday = DateTime(
        today.year, today.month, today.day - daysSinceSunday);
    final firstWeekSunday = DateTime(
        thisWeekSunday.year, thisWeekSunday.month,
        thisWeekSunday.day - 7 * (weeks - 1));

    const cellSize = 14.0;
    const cellGap = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: SizedBox(
        height: 7 * (cellSize + cellGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < weeks; col++)
              Column(
                children: [
                  for (var row = 0; row < 7; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: cellGap, right: cellGap),
                      child: Builder(builder: (context) {
                        final day = DateTime(
                            firstWeekSunday.year, firstWeekSunday.month,
                            firstWeekSunday.day + 7 * col + row);
                        final key = DateTime(day.year, day.month, day.day);
                        final elapsed = key.difference(start).inDays;
                        final isInRange = !key.isBefore(start) &&
                            elapsed < totalDays &&
                            !key.isAfter(todayKey);
                        Color color;
                        if (!isInRange) {
                          color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
                        } else if (confirmedSet.contains(key)) {
                          color = baseColor;
                        } else {
                          color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
                        }
                        return Container(
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
