import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/task.dart';
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
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No active tasks',
                      subtitle: 'Add a task to stay organized',
                      actionLabel: 'Add Task',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          bottom: AppSpacing.xxl),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) => _TaskTile(task: tasks[i]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _AddTaskDialog(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.done;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteTask(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => state.toggleTaskDone(task.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: done
                          ? task.priority.color
                          : Colors.transparent,
                      border: Border.all(
                          color: task.priority.color, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: done
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: done
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)
                                  : null)),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(task.description,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          PillChip(
                            label: task.priority.label,
                            icon: task.priority.icon,
                            color: task.priority.color,
                          ),
                          PillChip(
                            label: task.category.label,
                            icon: task.category.icon,
                          ),
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
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _priorityIndex = 1;
  int _categoryIndex = 1;
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return AlertDialog(
      title: const Text('New Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'e.g. Finish project report',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            // Priority
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Priority', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: List.generate(TaskPriority.values.length, (i) {
                final sel = i == _priorityIndex;
                final p = TaskPriority.values[i];
                return GestureDetector(
                  onTap: () => setState(() => _priorityIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? p.color : ext.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(p.label,
                        style: TextStyle(
                          color: sel ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600, fontSize: 13,
                        )),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            // Category
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Category', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(TaskCategory.values.length, (i) {
                final sel = i == _categoryIndex;
                final c = TaskCategory.values[i];
                return GestureDetector(
                  onTap: () => setState(() => _categoryIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.colorScheme.primary
                          : ext.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon, size: 14,
                            color: sel ? Colors.white : theme.colorScheme.onSurface),
                        const SizedBox(width: 4),
                        Text(c.label,
                            style: TextStyle(
                              color: sel ? Colors.white : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600, fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            // Due date
            Row(
              children: [
                Text('Due: ', style: theme.textTheme.labelLarge),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (d != null) setState(() => _dueDate = d);
                  },
                  child: Text(_dueDate == null
                      ? 'Select date'
                      : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}'),
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
            context.read<AppState>().addTask(
                  title: title,
                  description: _descController.text.trim(),
                  priorityIndex: _priorityIndex,
                  categoryIndex: _categoryIndex,
                  dueDate: _dueDate,
                );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
