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
              ? EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No scheduled items',
                  subtitle: 'Add a one-off event or reminder',
                  actionLabel: 'Add schedule',
                  onAction: () => showAddScheduleDialog(context),
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
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    // Re-read the item from state so checkbox toggles reflect immediately.
    final freshItem = state.scheduleRepo.getAll()
        .where((s) => s.id == item.id).firstOrNull ?? item;
    final now = DateTime.now();
    final isToday = freshItem.dateTime.day == now.day &&
        freshItem.dateTime.month == now.month &&
        freshItem.dateTime.year == now.year;
    final isPast = freshItem.dateTime.isBefore(now) && !isToday;

    return Dismissible(
      key: ValueKey(freshItem.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDeleteConfirmation(context, itemName: 'schedule item', message: 'Delete \"${freshItem.title}\"?'),
      onDismissed: (_) => state.deleteSchedule(freshItem.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () => showEditScheduleDialog(context, freshItem),
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
                          '${freshItem.dateTime.hour.toString().padLeft(2, '0')}:'
                          '${freshItem.dateTime.minute.toString().padLeft(2, '0')}',
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
                              : '${freshItem.dateTime.month}/${freshItem.dateTime.day}',
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
                      freshItem.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration:
                            freshItem.done ? TextDecoration.lineThrough : null,
                        color: freshItem.done
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: freshItem.done,
                    activeColor: theme.extension<AppThemeExtension>()!.success,
                    onChanged: (_) => state.toggleSchedule(freshItem.id),
                  ),
                  IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => showEditScheduleDialog(context, freshItem)),
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
  final ScheduleItem? item;
  const _AddScheduleDialog({this.item});

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  final _titleController = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _dateTime = widget.item!.dateTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.item == null ? 'New Schedule Item' : 'Edit Schedule Item'),
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
          onPressed: () async {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            final state = context.read<AppState>();
            if (widget.item == null) {
              await state.addSchedule(title: title, dateTime: _dateTime);
            } else {
              final item = widget.item!;
              item.title = title;
              item.dateTime = _dateTime;
              await state.updateSchedule(item);
            }
            Navigator.pop(context);
          },
          child: Text(widget.item == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

/// Global FAB action — call from the parent Scaffold.
void showAddScheduleDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _AddScheduleDialog());
}

void showEditScheduleDialog(BuildContext context, ScheduleItem item) {
  showDialog(context: context, builder: (_) => _AddScheduleDialog(item: item));
}
