import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/reminder_rule.dart';
import '../../core/theme/app_spacing.dart';

class ReminderEditorDialog extends StatefulWidget {
  final ReminderRule? initial;
  final bool forHabit;

  const ReminderEditorDialog({super.key, this.initial, required this.forHabit});

  @override
  State<ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<ReminderEditorDialog> {
  late TimeOfDay _time;
  late int _before;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _time = r == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: r.hour, minute: r.minute);
    _before = r?.minutesBeforeDue ?? 0;
    _weekdays = {...?r?.weekdays};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return AlertDialog(
      title: Text(widget.forHabit ? 'Habit reminder' : 'Task reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.forHabit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Time of day'),
                subtitle: Text(_time.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
            if (!widget.forHabit) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _before,
                decoration: const InputDecoration(labelText: 'When'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('At due time')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                  DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                  DropdownMenuItem(value: 60, child: Text('1 hour before')),
                  DropdownMenuItem(value: 1440, child: Text('1 day before')),
                ],
                onChanged: (value) => setState(() => _before = value ?? 0),
              ),
            ],
            if (widget.forHabit) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Limit to specific weekdays (optional)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) => FilterChip(
                  label: Text(dayNames[i]),
                  selected: _weekdays.contains(i + 1),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _weekdays.add(i + 1);
                    } else {
                      _weekdays.remove(i + 1);
                    }
                  }),
                )),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final existing = widget.initial;
            final rule = ReminderRule(
              id: existing?.id ?? const Uuid().v4(),
              enabled: existing?.enabled ?? true,
              hour: _time.hour,
              minute: _time.minute,
              minutesBeforeDue: widget.forHabit ? 0 : _before,
              weekdays: widget.forHabit ? _weekdays.toList() : const [],
            );
            Navigator.pop(context, rule);
          },
          child: Text(existingActionLabel),
        ),
      ],
    );
  }

  String get existingActionLabel => widget.initial == null ? 'Add reminder' : 'Save reminder';
}

class ReminderListEditor extends StatelessWidget {
  final List<ReminderRule> reminders;
  final bool forHabit;
  final ValueChanged<List<ReminderRule>> onChanged;

  const ReminderListEditor({
    super.key,
    required this.reminders,
    required this.forHabit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_none_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Reminders', style: theme.textTheme.titleSmall)),
            TextButton.icon(
              onPressed: reminders.length >= 5
                  ? null
                  : () async {
                      final rule = await showDialog<ReminderRule>(
                        context: context,
                        builder: (_) => ReminderEditorDialog(forHabit: forHabit),
                      );
                      if (rule != null) onChanged([...reminders, rule]);
                    },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (reminders.isEmpty)
          Text(
            forHabit ? 'No habit reminders set.' : 'No reminders set. Tasks keep the default due-time notification.',
            style: theme.textTheme.bodySmall,
          )
        else
          ...reminders.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(r.enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: Text(forHabit || r.minutesBeforeDue > 0 ? r.summary : 'At due time'),
                subtitle: forHabit && r.weekdays.isNotEmpty
                    ? Text(r.weekdays.map((d) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1]).join(', '))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: r.enabled,
                      onChanged: (v) => onChanged(reminders.map((x) => x.id == r.id ? x.copyWith(enabled: v) : x).toList()),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final updated = await showDialog<ReminderRule>(
                            context: context,
                            builder: (_) => ReminderEditorDialog(initial: r, forHabit: forHabit),
                          );
                          if (updated != null) {
                            onChanged(reminders.map((x) => x.id == r.id ? updated : x).toList());
                          }
                        } else if (value == 'delete') {
                          onChanged(reminders.where((x) => x.id != r.id).toList());
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
