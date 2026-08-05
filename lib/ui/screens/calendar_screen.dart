import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';
import 'habit_detail_screen.dart';
import 'tasks_screen.dart';
import 'goals_screen.dart';
import 'finance_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _weekView = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          ScreenTitleBar(
            title: 'Calendar',
            subtitle: _weekView ? 'Week view' : 'Month view',
            trailing: IconButton(
              icon: Icon(_weekView ? Icons.calendar_view_month : Icons.calendar_view_week),
              onPressed: () => setState(() => _weekView = !_weekView),
            ),
          ),
          // View toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(_monthYearString(_focusedMonth), style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    if (_weekView) {
                      _focusedMonth = _focusedMonth.subtract(const Duration(days: 7));
                    } else {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    }
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    if (_weekView) {
                      _focusedMonth = _focusedMonth.add(const Duration(days: 7));
                    } else {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                    }
                  }),
                ),
              ],
            ),
          ),
          // Calendar grid
          _weekView ? _buildWeekView(state) : _buildMonthView(state),
          const Divider(),
          // Events for selected date
          Expanded(
            child: _buildEventsForDate(state),
          ),
        ],
      ),
    );
  }

  String _monthYearString(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildMonthView(AppState state) {
    final theme = Theme.of(context);
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstOfMonth.weekday % 7; // 0=Sunday
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // Get events for this month
    final startRange = firstOfMonth.subtract(Duration(days: firstWeekday));
    final endRange = DateTime(_focusedMonth.year, _focusedMonth.month, daysInMonth + 7);
    final events = state.getCalendarEvents(startRange, endRange);
    final eventsByDate = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      eventsByDate.putIfAbsent(key, () => []).add(e);
    }

    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Day labels
        Row(
          children: dayLabels.map((d) => Expanded(
            child: Center(child: Text(d, style: theme.textTheme.bodySmall)),
          )).toList(),
        ),
        const SizedBox(height: 4),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: ((firstWeekday + daysInMonth) / 7).ceil() * 7,
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox.shrink();
            final dayIndex = index - firstWeekday;
            if (dayIndex >= daysInMonth) return const SizedBox.shrink();
            final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayIndex + 1);
            final key = DateTime(day.year, day.month, day.day);
            final dayEvents = eventsByDate[key] ?? [];
            final isSelected = key.isAtSameMomentAs(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
            final isToday = key.isAtSameMomentAs(todayKey);

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = day),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? theme.colorScheme.primary : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    if (dayEvents.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dayEvents.take(3).map((e) {
                          return Container(
                            width: 5, height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: e.color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekView(AppState state) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final weekday = _focusedMonth.weekday;
    final startOfWeek = _focusedMonth.subtract(Duration(days: weekday - 1));

    final events = state.getCalendarEvents(startOfWeek, startOfWeek.add(const Duration(days: 7)));
    final eventsByDate = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      eventsByDate.putIfAbsent(key, () => []).add(e);
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + index);
          final key = DateTime(day.year, day.month, day.day);
          final dayEvents = eventsByDate[key] ?? [];
          final isToday = key.isAtSameMomentAs(todayKey);
          final isSelected = key.isAtSameMomentAs(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = day),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][index],
                      style: theme.textTheme.bodySmall),
                  Text('${day.day}', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  ...dayEvents.take(4).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventsForDate(AppState state) {
    final theme = Theme.of(context);
    final events = state.getCalendarEvents(_selectedDate, _selectedDate);
    final dayKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (events.isEmpty) {
      return Center(
        child: Text('No events on ${dayKey.month}/${dayKey.day}',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];
        return ListTile(
          leading: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
          ),
          title: Text(e.title),
          subtitle: Text(e.type, style: TextStyle(color: e.color, fontSize: 12)),
          trailing: e.completed ? const Icon(Icons.check, color: Colors.green) : null,
          onTap: () => _navigateToEntity(context, e.type, e.entityId),
        );
      },
    );
  }

  void _navigateToEntity(BuildContext context, String type, String id) {
    switch (type) {
      case 'habit':
        Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: id)));
      case 'task':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)));
      case 'goal':
        Navigator.push(context, MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: id)));
      case 'finance':
        Navigator.push(context, MaterialPageRoute(builder: (_) => FinanceDetailScreen(financeId: id)));
    }
  }
}
