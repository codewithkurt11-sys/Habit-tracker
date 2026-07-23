import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/habit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final habit = state.habitsRepo.getById(habitId);

    if (habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit Details')),
        body: const Center(child: Text('Habit not found')),
      );
    }

    final color = habit.customColor ?? AppColors.categoryLifestyle;
    final currentStreak = habit.currentStreak();
    final bestStreak = habit.bestStreak();
    final completionRate30 = habit.completionRate(days: 30);
    final totalCompletions = habit.totalCompletions;
    final missStreak = habit.currentMissStreak();
    final notes = state.notesRepo.getForHabit(habitId);

    // Last 30 days history
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final history = <_HistoryDay>[];
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      history.add(_HistoryDay(
        date: date,
        isDue: habit.isDueOn(date),
        isDone: habit.isCompletedOn(date),
      ));
    }

    // Recent completions (last 10)
    final recentCompletions = habit.completionLog
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final recent = recentCompletions.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, state, habitId),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Hero card
          Card(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    theme.colorScheme.surface
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMedium)),
                      child: Icon(habit.icon.data, color: color, size: 32),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(habit.name,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        PillChip(label: habit.category.name, color: color),
                        PillChip(label: habit.frequency.name, color: color),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Stats grid
          Row(
            children: [
              Expanded(
                  child: _StatBox(
                      label: 'Current Streak',
                      value: '$currentStreak',
                      unit: 'days',
                      color: const Color(0xFFE8C56F))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatBox(
                      label: 'Best Streak',
                      value: '$bestStreak',
                      unit: 'days',
                      color: const Color(0xFFE8946F))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: _StatBox(
                      label: 'Completion (30d)',
                      value: '${(completionRate30 * 100).round()}',
                      unit: '%',
                      color: color)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatBox(
                      label: 'Total Done',
                      value: '$totalCompletions',
                      unit: '',
                      color: AppColors.lightSuccess)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (missStreak > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Missed $missStreak scheduled day${missStreak > 1 ? "s" : ""} in a row',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 30-day mini heatmap
          const _SectionLabel('Last 30 Days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: history
                    .map((h) => Tooltip(
                          message:
                              '${h.date.month}/${h.date.day}: ${h.isDone ? "Done" : h.isDue ? "Missed" : "Not due"}',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: h.isDone
                                  ? color
                                  : h.isDue
                                      ? color.withValues(alpha: 0.15)
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: h.isDone
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : h.isDue
                                    ? Icon(Icons.close,
                                        size: 14,
                                        color: color.withValues(alpha: 0.4))
                                    : null,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Recent completions
          if (recent.isNotEmpty) ...[
            const _SectionLabel('Recent Completions'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: recent
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 16, color: color),
                                const SizedBox(width: 8),
                                Text('${d.month}/${d.day}/${d.year}',
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Notes
          _SectionLabel('Notes (${notes.length})'),
          if (notes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                    child: Text('No notes for this habit yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)))),
              ),
            )
          else
            ...notes.map((n) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: theme.textTheme.titleSmall),
                        if (n.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(n.body, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 4),
                        Text(
                            '${n.timestamp.month}/${n.timestamp.day} ${n.timestamp.hour.toString().padLeft(2, "0")}:${n.timestamp.minute.toString().padLeft(2, "0")}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: AppSpacing.md),

          // Add note button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddNoteDialog(context, state, habitId),
              icon: const Icon(Icons.note_add),
              label: const Text('Add Note'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Habit'),
        content: const Text(
            'Are you sure you want to delete this habit? All completion history will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white),
            onPressed: () {
              state.deleteHabit(id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(
      BuildContext context, AppState state, String habitId) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true),
            const SizedBox(height: 8),
            TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              state.notesRepo.create(
                  title: title,
                  body: bodyController.text.trim(),
                  habitId: habitId);
              state.refresh();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Text(text,
          style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold)),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.headlineMedium,
                children: [
                  TextSpan(
                      text: value,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold)),
                  if (unit.isNotEmpty)
                    TextSpan(text: ' $unit', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HistoryDay {
  final DateTime date;
  final bool isDue;
  final bool isDone;
  _HistoryDay({required this.date, required this.isDue, required this.isDone});
}
