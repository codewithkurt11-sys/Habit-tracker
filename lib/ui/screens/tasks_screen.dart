import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/task.dart';
import '../../data/models/recurrence_rule.dart';
import '../../data/models/reminder_rule.dart';
import '../widgets/reminder_editor_dialog.dart';
import '../widgets/recurrence_editor_dialog.dart';
import '../widgets/task_category_dialogs.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.tasksRepo.getActive();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Tasks',
              subtitle: '${tasks.length} active',
              onMenuTap: null,
              trailing: IconButton(
                tooltip: 'Add task',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  context.read<AppState>().hideQuickCapture();
                  showAddTaskDialog(context);
                },
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No active tasks',
                      subtitle: 'Add a task to stay organized.',
                      actionLabel: 'Add Task',
                      onAction: () => showDialog(
                        context: context,
                        builder: (_) => const _TaskEditorDialog(),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) => _TaskTile(task: tasks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    // Re-read the task from state so checkbox toggles reflect immediately.
    final freshTask = state.tasksRepo.getAll(includeArchived: true)
        .where((t) => t.id == task.id).firstOrNull ?? task;
    final done = freshTask.status == TaskStatus.done;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDeleteConfirmation(
        context,
        itemName: 'task',
        message: 'Delete "${task.title}"? This action cannot be undone.',
      ),
      onDismissed: (_) => state.deleteTask(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () => showEditTaskDialog(context, freshTask),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: done,
                    activeColor: freshTask.priority.color,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => state.toggleTaskDone(freshTask.id),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(freshTask.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                                color: done
                                    ? theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4)
                                    : null)),
                        if (freshTask.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(freshTask.description,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            PillChip(
                              label: freshTask.priority.label,
                              icon: freshTask.priority.icon,
                              color: freshTask.priority.color,
                            ),
                            PillChip(
                              label: state.taskCategoryLabel(freshTask),
                              icon: state.taskCategoryIcon(freshTask),
                              color: freshTask.customCategoryId == null ? null : state.taskCategoriesRepo.getById(freshTask.customCategoryId)?.color,
                            ),
                            if (freshTask.goalId != null)
                              const PillChip(
                                  label: 'Linked goal', icon: Icons.link),
                            if (freshTask.habitId != null)
                              const PillChip(
                                  label: 'Linked habit', icon: Icons.repeat),
                            if (freshTask.isRecurring)
                              const PillChip(
                                  label: 'Recurring', icon: Icons.repeat),
                          ],
                        ),
                      ],
                    ),
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

class _TaskEditorDialog extends StatefulWidget {
  final Task? task;
  const _TaskEditorDialog({this.task});

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late final TextEditingController _subtasks;
  late int _priority;
  late int _category;
  String? _customCategoryId;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String? _goalId;
  String? _habitId;
  bool _recurring = false;
  String _pattern = 'daily';
  RecurrenceRule? _recurrenceRule;
  List<ReminderRule> _reminders = [];

  bool get editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _tags = TextEditingController(text: t?.tags.join(', ') ?? '');
    _subtasks = TextEditingController(text: t?.subtaskTitles.join('\n') ?? '');
    _priority = t?.priority.index ?? 1;
    _category = t?.category.index ?? 1;
    _customCategoryId = t?.customCategoryId;
    _dueDate = t?.dueDate;
    _dueTime = t?.dueTime == null ? null : TimeOfDay.fromDateTime(t!.dueTime!);
    _goalId = t?.goalId;
    _habitId = t?.habitId;
    _recurring = t?.isRecurring ?? false;
    _pattern = t?.recurringPattern.isNotEmpty == true ? t!.recurringPattern : 'daily';
    _recurrenceRule = t?.recurrenceRule ?? (t?.isRecurring == true ? RecurrenceRule.fromLegacy(t!.recurringPattern, startDate: t.dueDate ?? t.createdAt) : null);
    _reminders = List<ReminderRule>.from(t?.reminders ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _subtasks.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final state = context.read<AppState>();
    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final subtaskTitles = _subtasks.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final dueTime = _dueDate == null || _dueTime == null
        ? null
        : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day,
            _dueTime!.hour, _dueTime!.minute);
    if (editing) {
      final t = widget.task!;
      t.title = title;
      t.description = _description.text.trim();
      t.priority = TaskPriority.values[_priority];
      t.category = TaskCategory.values[_category];
      t.customCategoryId = _customCategoryId;
      t.dueDate = _dueDate == null
          ? null
          : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      t.dueTime = dueTime;
      t.tags = tags;
      final oldDone = List<bool>.from(t.subtaskDone);
      t.subtaskTitles = subtaskTitles;
      t.subtaskDone = List<bool>.generate(
          subtaskTitles.length, (i) => i < oldDone.length ? oldDone[i] : false);
      t.goalId = _goalId;
      t.habitId = _habitId;
      t.isRecurring = _recurring;
      t.recurringPattern = _recurring ? _pattern : '';
      t.recurrenceRule = _recurring ? _recurrenceRule : null;
      t.reminders = List<ReminderRule>.from(_reminders);
      // Turning recurrence off ends the previous series. Re-enabling later
      // will start a fresh series instead of inheriting old completion history.
      if (!_recurring || widget.task!.isRecurring != true) {
        t.recurrenceSeriesId = null;
      }
      await state.updateTask(t);
    } else {
      await state.addTask(
        title: title,
        description: _description.text.trim(),
        priorityIndex: _priority,
        categoryIndex: _category,
        dueDate: _dueDate,
        dueTime: dueTime,
        tags: tags,
        subtaskTitles: subtaskTitles,
        isRecurring: _recurring,
        recurringPattern: _recurring ? _pattern : '',
        recurrenceRule: _recurring ? _recurrenceRule : null,
        reminders: _reminders,
        customCategoryId: _customCategoryId,
        goalId: _goalId,
        habitId: _habitId,
      );
      // Tags are only available on edit in the legacy data path; create a
      // second pass is intentionally avoided so the dialog remains instant.
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final state = context.watch<AppState>();
    return AlertDialog(
      title: Text(editing ? 'Edit Task' : 'New Task'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Task title'),
                autofocus: !editing),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: _tags,
                decoration: const InputDecoration(
                    labelText: 'Tags', hintText: 'school, work, urgent')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: _subtasks,
                decoration: const InputDecoration(
                    labelText: 'Subtasks', hintText: 'One subtask per line'),
                minLines: 2,
                maxLines: 5),
            const SizedBox(height: AppSpacing.md),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Priority', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 6),
            Wrap(
                spacing: 6,
                children: List.generate(TaskPriority.values.length, (i) {
                  final p = TaskPriority.values[i];
                  return ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == i,
                      onSelected: (_) => setState(() => _priority = i));
                })),
            const SizedBox(height: AppSpacing.md),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Category', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...List.generate(TaskCategory.values.length, (i) {
                  final c = TaskCategory.values[i];
                  return ChoiceChip(
                    label: Text(c.label),
                    selected: _customCategoryId == null && _category == i,
                    avatar: Icon(c.icon, size: 15),
                    onSelected: (_) => setState(() { _category = i; _customCategoryId = null; }),
                  );
                }),
                ...state.taskCategoriesRepo.getAll().map((c) => ChoiceChip(
                  label: Text(c.name),
                  selected: _customCategoryId == c.id,
                  avatar: Icon(c.icon, size: 15, color: c.color),
                  onSelected: (_) => setState(() => _customCategoryId = c.id),
                )),
                ActionChip(
                  avatar: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Manage'),
                  onPressed: () async {
                    await showTaskCategoryManager(context);
                    if (mounted) setState(() {
                      if (_customCategoryId != null && state.taskCategoriesRepo.getById(_customCategoryId) == null) {
                        _customCategoryId = null;
                        _category = TaskCategory.other.index;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Due date'),
                      subtitle: Text(_dueDate == null
                          ? 'None'
                          : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}'),
                      onTap: _pickDate)),
              Expanded(
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Time'),
                      subtitle: Text(_dueTime == null
                          ? 'None'
                          : _dueTime!.format(context)),
                      onTap: _pickTime))
            ]),
            const SizedBox(height: AppSpacing.md),
            ReminderListEditor(
              reminders: _reminders,
              forHabit: false,
              onChanged: (value) => setState(() => _reminders = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
                initialValue: _goalId,
                decoration: const InputDecoration(
                    labelText: 'Connected goal',
                    prefixIcon: Icon(Icons.track_changes_outlined)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No goal')),
                  ...state.goalsRepo.getActive().map((g) =>
                      DropdownMenuItem<String?>(
                          value: g.id, child: Text(g.title)))
                ],
                onChanged: (v) => setState(() => _goalId = v)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
                initialValue: _habitId,
                decoration: const InputDecoration(
                    labelText: 'Connected habit',
                    prefixIcon: Icon(Icons.repeat)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No habit')),
                  ...state.habitsRepo.getAll().map((h) =>
                      DropdownMenuItem<String?>(
                          value: h.id, child: Text(h.name)))
                ],
                onChanged: (v) => setState(() => _habitId = v)),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring'),
                subtitle: const Text(
                    'Automatically create the next occurrence when completed'),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v)),
            if (_recurring) ...[
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat),
                title: const Text('Repeat schedule'),
                subtitle: Text((_recurrenceRule ?? RecurrenceRule.fromLegacy(_pattern, startDate: _dueDate ?? DateTime.now())).summary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final rule = await showDialog<RecurrenceRule>(
                    context: context,
                    builder: (_) => RecurrenceEditorDialog(initial: _recurrenceRule ?? RecurrenceRule.fromLegacy(_pattern, startDate: _dueDate ?? DateTime.now())),
                  );
                  if (rule != null) setState(() {
                    _recurrenceRule = rule;
                    _pattern = 'advanced';
                  });
                },
              ),
            ],
            if (_recurring && _dueDate == null && (_recurrenceRule?.startDate == null))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No start date set — recurrence uses the completion/due date as the anchor.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 4),
            Text('Completing this task updates connected goals immediately.',
                style: theme.textTheme.bodySmall?.copyWith(color: ext.success)),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _save,
            child: Text(editing ? 'Save changes' : 'Add task'))
      ],
    );
  }
}

void showAddTaskDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _TaskEditorDialog());
void showEditTaskDialog(BuildContext context, Task task) =>
    showDialog(context: context, builder: (_) => _TaskEditorDialog(task: task));
