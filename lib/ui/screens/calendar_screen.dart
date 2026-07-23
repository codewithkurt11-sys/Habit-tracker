import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../logic/stats_engine.dart';
import '../../data/models/habit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime.now();
  bool _showHeatmap = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final habits = state.habitsRepo.getAll();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Toggle between Calendar and Heatmap
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showHeatmap = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_showHeatmap ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Center(child: Text('Calendar', style: TextStyle(color: !_showHeatmap ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showHeatmap = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _showHeatmap ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Center(child: Text('Heatmap', style: TextStyle(color: _showHeatmap ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (_showHeatmap)
          _HeatmapView(habits: habits)
        else
          _MonthCalendarView(
            viewMonth: _viewMonth,
            selectedDate: _selectedDate,
            habits: habits,
            state: state,
            onDateSelected: (d) => setState(() => _selectedDate = d),
            onMonthChanged: (d) => setState(() => _viewMonth = d),
          ),
      ],
    );
  }
}

class _HeatmapView extends StatelessWidget {
  final List<Habit> habits;
  const _HeatmapView({required this.habits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = StatsEngine.heatMap(habits, 84); // 12 weeks

    // Group cells into weeks (columns of 7)
    final weeks = <List<HeatCell>>[];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7 > cells.length ? cells.length : i + 7));
    }

    final monthLabels = _monthLabels(cells);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Heatmap', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Last 12 weeks of habit completions', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month labels row
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      ...monthLabels.map((label) => SizedBox(width: 14 * 7, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Day labels + grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day labels
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ['Mon', 'Wed', 'Fri'].map((d) => SizedBox(height: 14, width: 24, child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontSize: 9)))).toList(),
                      ),
                      // Weeks
                      Row(
                        children: weeks.map((week) {
                          return Column(
                            children: List.generate(7, (dayIdx) {
                              if (dayIdx < week.length) {
                                final cell = week[dayIdx];
                                return Padding(
                                  padding: const EdgeInsets.all(1),
                                  child: Tooltip(
                                    message: '${cell.date.month}/${cell.date.day}: ${cell.completed}/${cell.due} done',
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(
                                        color: _heatColor(cell.level, theme),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox(width: 14, height: 14);
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Legend
                  Row(
                    children: [
                      Text('Less', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                      const SizedBox(width: 4),
                      ...List.generate(5, (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: _heatColor(i, theme), borderRadius: BorderRadius.circular(3))),
                      )),
                      const SizedBox(width: 4),
                      Text('More', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Stats summary
        _HeatmapStats(cells: cells),
      ],
    );
  }

  List<String> _monthLabels(List<HeatCell> cells) {
    final labels = <String>[];
    String? lastMonth;
    for (final cell in cells) {
      final monthName = _monthAbbr(cell.date.month);
      if (monthName != lastMonth && cell.date.day <= 7) {
        labels.add(monthName);
        lastMonth = monthName;
      } else if (lastMonth == null) {
        labels.add(monthName);
        lastMonth = monthName;
      } else {
        labels.add('');
      }
    }
    // Collapse into week-start labels
    final weekLabels = <String>[];
    for (int i = 0; i < labels.length; i += 7) {
      final slice = labels.sublist(i, i + 7 > labels.length ? labels.length : i + 7);
      final found = slice.where((l) => l.isNotEmpty);
      weekLabels.add(found.isNotEmpty ? found.first : '');
    }
    return weekLabels;
  }

  String _monthAbbr(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  Color _heatColor(int level, ThemeData theme) {
    if (level == 0) return theme.colorScheme.onSurface.withValues(alpha: 0.08);
    if (level == 1) return AppColors.categoryLifestyle.withValues(alpha: 0.4);
    if (level == 2) return AppColors.categoryLifestyle.withValues(alpha: 0.6);
    if (level == 3) return AppColors.categoryLifestyle.withValues(alpha: 0.8);
    return AppColors.categoryLifestyle;
  }
}

class _HeatmapStats extends StatelessWidget {
  final List<HeatCell> cells;
  const _HeatmapStats({required this.cells});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCompleted = cells.fold(0, (s, c) => s + c.completed);
    final activeDays = cells.where((c) => c.completed > 0).length;
    final bestDay = cells.fold<HeatCell?>(null, (best, c) => best == null || c.completed > best.completed ? c : best);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: _StatItem(label: 'Total Done', value: '$totalCompleted')),
            Container(width: 1, height: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            Expanded(child: _StatItem(label: 'Active Days', value: '$activeDays')),
            Container(width: 1, height: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            Expanded(child: _StatItem(label: 'Best Day', value: bestDay != null && bestDay.completed > 0 ? '${bestDay.completed}' : '-')),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MonthCalendarView extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime selectedDate;
  final List<Habit> habits;
  final AppState state;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  const _MonthCalendarView({required this.viewMonth, required this.selectedDate, required this.habits, required this.state, required this.onDateSelected, required this.onMonthChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final lastOfMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0);
    final firstWeekday = firstOfMonth.weekday; // 1=Mon..7=Sun
    final daysInMonth = lastOfMonth.day;
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final cells = <_DayCell>[];
    // Leading blanks
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(_DayCell.empty());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(viewMonth.year, viewMonth.month, d);
      final completed = StatsEngine.habitsCompletedOnDay(habits, date);
      final due = StatsEngine.habitsDueOnDay(habits, date);
      final tasksForDay = state.tasksRepo.getForDate(date);
      final journals = state.journalRepo.getAll().where((j) => j.date.year == date.year && j.date.month == date.month && j.date.day == date.day).toList();
      final notes = state.notesRepo.getForDate(date);
      final schedules = state.scheduleRepo.getAll().where((s) => s.dateTime.year == date.year && s.dateTime.month == date.month && s.dateTime.day == date.day).toList();
      cells.add(_DayCell(
        date: date,
        completed: completed,
        due: due,
        taskCount: tasksForDay.length,
        hasJournal: journals.isNotEmpty,
        hasNote: notes.isNotEmpty,
        scheduleCount: schedules.length,
        isToday: date.isAtSameMomentAs(todayNorm),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(DateTime(viewMonth.year, viewMonth.month - 1, 1)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_monthName(viewMonth.month)} ${viewMonth.year}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonthChanged(DateTime(viewMonth.year, viewMonth.month + 1, 1)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Weekday headers
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(
            child: Center(child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 11))),
          )).toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Calendar grid
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Wrap(
              children: cells.map((cell) => SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpacing.md * 2 - AppSpacing.xs * 2 - 8) / 7,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: cell.isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => onDateSelected(cell.date!),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: cell.isToday
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : cell.date!.isAtSameMomentAs(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                      : null,
                              border: cell.isToday
                                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                                  : null,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${cell.date!.day}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: cell.isToday ? FontWeight.bold : FontWeight.normal,
                                    color: cell.isToday ? theme.colorScheme.primary : null,
                                  ),
                                ),
                                if (cell.due > 0 || cell.taskCount > 0 || cell.hasJournal || cell.scheduleCount > 0) ...[
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 2,
                                    runSpacing: 2,
                                    children: [
                                      if (cell.due > 0)
                                        _Dot(color: cell.completed == cell.due ? AppColors.lightSuccess : AppColors.categoryLifestyle),
                                      if (cell.taskCount > 0)
                                        _Dot(color: AppColors.categoryOther),
                                      if (cell.hasJournal)
                                        _Dot(color: const Color(0xFF7B93B5)),
                                      if (cell.scheduleCount > 0)
                                        _Dot(color: const Color(0xFFB58BB5)),
                                      if (cell.hasNote)
                                        _Dot(color: const Color(0xFFE8C56F)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Selected date details
        _DateDetail(date: selectedDate, state: state, habits: habits),
      ],
    );
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _DayCell {
  final DateTime? date;
  final int completed;
  final int due;
  final int taskCount;
  final bool hasJournal;
  final bool hasNote;
  final int scheduleCount;
  final bool isToday;
  final bool isEmpty;

  _DayCell({required this.date, required this.completed, required this.due, required this.taskCount, required this.hasJournal, required this.hasNote, required this.scheduleCount, required this.isToday}) : isEmpty = false;
  _DayCell.empty() : date = null, completed = 0, due = 0, taskCount = 0, hasJournal = false, hasNote = false, scheduleCount = 0, isToday = false, isEmpty = true;
}

class _DateDetail extends StatelessWidget {
  final DateTime date;
  final AppState state;
  final List<Habit> habits;
  const _DateDetail({required this.date, required this.state, required this.habits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = DateTime(date.year, date.month, date.day);
    final dueHabits = habits.where((h) => h.isDueOn(d)).toList();
    final completedHabits = dueHabits.where((h) => h.isCompletedOn(d)).toList();
    final tasks = state.tasksRepo.getForDate(d);
    final journals = state.journalRepo.getAll().where((j) => j.date.year == d.year && j.date.month == d.month && j.date.day == d.day).toList();
    final notes = state.notesRepo.getForDate(d);
    final schedules = state.scheduleRepo.getAll().where((s) => s.dateTime.year == d.year && s.dateTime.month == d.month && s.dateTime.day == d.day).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${d.month}/${d.day}/${d.year}', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (dueHabits.isNotEmpty) ...[
              _DetailRow(icon: Icons.repeat_rounded, label: 'Habits', value: '${completedHabits.length}/${dueHabits.length} done', color: AppColors.categoryLifestyle),
            ],
            if (tasks.isNotEmpty) ...[
              _DetailRow(icon: Icons.check_circle_outline, label: 'Tasks', value: '${tasks.length} due', color: AppColors.categoryOther),
            ],
            if (schedules.isNotEmpty) ...[
              _DetailRow(icon: Icons.calendar_today, label: 'Schedule', value: '${schedules.length} items', color: const Color(0xFFB58BB5)),
            ],
            if (journals.isNotEmpty) ...[
              _DetailRow(icon: Icons.book, label: 'Journal', value: '${journals.length} entr${journals.length > 1 ? "ies" : "y"}', color: const Color(0xFF7B93B5)),
            ],
            if (notes.isNotEmpty) ...[
              _DetailRow(icon: Icons.sticky_note_2, label: 'Notes', value: '${notes.length}', color: const Color(0xFFE8C56F)),
            ],
            if (dueHabits.isEmpty && tasks.isEmpty && schedules.isEmpty && journals.isEmpty && notes.isEmpty)
              Text('No activity on this day', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
