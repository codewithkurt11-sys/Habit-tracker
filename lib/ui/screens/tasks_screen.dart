import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/task.dart';
import '../widgets/shared_widgets.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final groups = state.tasksGrouped;
    final groupOrder = ['Overdue', 'Today', 'Tomorrow', 'This week', 'Later', 'No date'];

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTaskDialog(context),
          child: const Icon(Icons.add),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitleBar(
                title: 'Tasks',
                subtitle: '${state.activeTasks.length} active • ${state.tasksRepo.getDone().length} done',
              ),
            ),
            if (groups.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No tasks',
                  subtitle: 'Create a task to get started',
                ),
              )
            else
              for (final groupName in groupOrder)
                if (groups.containsKey(groupName)) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: groupName,
                      subtitle: '${groups[groupName]!.where((t) => t.isDone).length}/${groups[groupName]!.length} done',
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _TaskCard(task: groups[groupName]![index]),
                      childCount: groups[groupName]!.length,
                    ),
                  ),
                ],
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddTaskSheet(),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isDone = task.isDone;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        color: Colors.green.withValues(alpha: 0.2),
        child: const Icon(Icons.check, color: Colors.green),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: Colors.orange.withValues(alpha: 0.2),
        child: const Icon(Icons.schedule, color: Colors.orange),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await state.toggleTaskDone(task.id);
          showUndoToast(context, isDone ? 'Undone' : 'Task completed',
              () => state.toggleTaskDone(task.id));
        }
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: GestureDetector(
          onTap: () async {
            await state.toggleTaskDone(task.id);
            showUndoToast(context, isDone ? 'Undone' : 'Task completed',
                () => state.toggleTaskDone(task.id));
          },
          child: CompletionRing(completed: isDone, color: task.priority.color, size: 24),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (task.dueDate != null)
              Text('${task.dueDate!.month}/${task.dueDate!.day}', style: TextStyle(fontSize: 12, color: task.priority.color)),
            if (task.recurring) ...[
              if (task.dueDate != null) const SizedBox(width: 8),
              Icon(Icons.repeat, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 2),
              Text(task.recurrenceRule, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ],
        ),
        trailing: isDone
          ? QuickNoteButton(entityType: 'task', entityId: task.id)
          : Icon(task.category.icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id))),
      ),
    );
  }
}

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final task = state.tasksRepo.getById(taskId);

    if (task == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Task not found')));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await showDeleteConfirmation(context, itemName: 'task')) {
                await state.deleteTask(task.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => state.toggleTaskDone(task.id),
                  child: CompletionRing(completed: task.isDone, color: task.priority.color, size: 40),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: theme.textTheme.headlineSmall),
                      if (task.dueDate != null)
                        Text('Due: ${task.dueDate!.year}-${task.dueDate!.month}-${task.dueDate!.day}',
                            style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (task.description.isNotEmpty) ...[
              Text('Description', style: theme.textTheme.titleSmall),
              Text(task.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
            ],
            _DetailRow(label: 'Priority', value: task.priority.label),
            _DetailRow(label: 'Category', value: task.category.label),
            _DetailRow(label: 'Status', value: task.status.name),
            if (task.recurring) ...[
              _DetailRow(label: 'Recurring', value: task.recurrenceRule),
            ],
            if (task.linkedGoalId != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Linked Goal', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Builder(builder: (context) {
                final goal = state.goalsRepo.getById(task.linkedGoalId!);
                if (goal == null) return const Text('Goal not found');
                return SoftCard(child: Text(goal.title));
              }),
            ],
            if (task.subtaskTitles.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Subtasks', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ...List.generate(task.subtaskTitles.length, (i) {
                return ListTile(
                  leading: Checkbox(
                    value: i < task.subtaskDone.length ? task.subtaskDone[i] : false,
                    onChanged: (_) => state.tasksRepo.toggleSubtask(task, i).then((_) => state.refresh()),
                  ),
                  title: Text(task.subtaskTitles[i]),
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: theme.textTheme.titleSmall),
      ]),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet();

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _priorityIndex = 1;
  int _categoryIndex = 1;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _recurring = false;
  String _recurrenceRule = 'daily';
  String? _linkedGoalId;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final goals = state.activeGoals;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Task', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Priority', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: List.generate(4, (i) {
                return ChoiceChip(
                  label: Text(TaskPriority.values[i].label),
                  selected: _priorityIndex == i,
                  onSelected: (s) => setState(() => _priorityIndex = i),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Category', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: List.generate(8, (i) {
                return ChoiceChip(
                  label: Text(TaskCategory.values[i].label),
                  selected: _categoryIndex == i,
                  onSelected: (s) => setState(() => _categoryIndex = i),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Due date', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) setState(() => _dueDate = date);
                  },
                  child: Text(_dueDate != null
                      ? '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'
                      : 'None'),
                ),
              ],
            ),
            // Recurring
            SwitchListTile(
              title: Text('Recurring', style: theme.textTheme.bodyMedium),
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_recurring) ...[
              Wrap(
                spacing: 8,
                children: ['daily', 'weekly', 'monthly', 'weekdays'].map((rule) {
                  return ChoiceChip(
                    label: Text(rule),
                    selected: _recurrenceRule == rule,
                    onSelected: (s) => setState(() => _recurrenceRule = rule),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (goals.isNotEmpty) ...[
              Text('Link to Goal', style: theme.textTheme.titleSmall),
              DropdownButton<String?>(
                value: _linkedGoalId,
                hint: const Text('None'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
                ],
                onChanged: (v) => setState(() => _linkedGoalId = v),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_titleController.text.trim().isEmpty) return;
                  context.read<AppState>().addTask(
                    title: _titleController.text.trim(),
                    description: _descController.text.trim(),
                    priorityIndex: _priorityIndex,
                    categoryIndex: _categoryIndex,
                    dueDate: _dueDate,
                    recurring: _recurring,
                    recurrenceRule: _recurring ? _recurrenceRule : '',
                    linkedGoalId: _linkedGoalId,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Create Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
