import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/schedule_item.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.scheduleRepo.getAll()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final today = state.scheduleRepo.getForToday();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('${today.length} items today',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No scheduled items',
                  subtitle: 'Add a one-off event or reminder',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ScheduleTile(item: items[i]),
                ),
        ),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final ScheduleItem item;
  const _ScheduleTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = item.dateTime.day == now.day &&
        item.dateTime.month == now.month &&
        item.dateTime.year == now.year;
    final isPast = item.dateTime.isBefore(now) && !isToday;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteSchedule(item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () => state.toggleSchedule(item.id),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Time column
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPast
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                          : theme.colorScheme.primary.withValues(alpha: 0.12)),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${item.dateTime.hour.toString().padLeft(2, '0')}:'
                          '${item.dateTime.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPast
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday
                              ? 'Today'
                              : '${item.dateTime.month}/${item.dateTime.day}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: isPast
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                        color: item.done
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                  ),
                  Icon(
                    item.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: item.done
                        ? theme.extension<AppThemeExtension>()!.success
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddScheduleDialog extends StatefulWidget {
  const _AddScheduleDialog();

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  final _titleController = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New Schedule Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Doctor appointment',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Date: ', style: theme.textTheme.labelLarge),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateTime,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (d != null) {
                      setState(() {
                        _dateTime = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          _dateTime.hour,
                          _dateTime.minute,
                        );
                      });
                    }
                  },
                  child: Text(
                      '${_dateTime.month}/${_dateTime.day}/${_dateTime.year}'),
                ),
              ],
            ),
            Row(
              children: [
                Text('Time: ', style: theme.textTheme.labelLarge),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_dateTime),
                    );
                    if (t != null) {
                      setState(() {
                        _dateTime = DateTime(
                          _dateTime.year,
                          _dateTime.month,
                          _dateTime.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    }
                  },
                  child: Text(
                    '${_dateTime.hour.toString().padLeft(2, '0')}:'
                    '${_dateTime.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            context.read<AppState>().addSchedule(
                  title: title,
                  dateTime: _dateTime,
                );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Global FAB action — call from the parent Scaffold.
void showAddScheduleDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _AddScheduleDialog(),
  );
}
