import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/task.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  final TaskCategory _category = TaskCategory.personal;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final allTasks = state.tasksRepo.getAll(includeArchived: true);

    final todoTasks = allTasks.where((t) => t.status == TaskStatus.todo).toList();
    final inProgressTasks = allTasks.where((t) => t.status == TaskStatus.inProgress).toList();
    final doneTasks = allTasks.where((t) => t.status == TaskStatus.done).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Kanban Board',
              subtitle: '${allTasks.length} tasks',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: allTasks.isEmpty
                  ? const EmptyState(
                      icon: Icons.view_kanban_outlined,
                      title: 'No tasks yet',
                      subtitle: 'Add tasks and organize them in columns',
                      actionLabel: 'Add Task',
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KanbanColumn(
                            title: 'To Do',
                            tasks: todoTasks,
                            color: theme.colorScheme.primary,
                            icon: Icons.radio_button_unchecked,
                            state: state,
                            onAdd: () => _showAddDialog(context),
                          ),
                          _KanbanColumn(
                            title: 'In Progress',
                            tasks: inProgressTasks,
                            color: const Color(0xFFE8C56F),
                            icon: Icons.play_circle_outline,
                            state: state,
                            onAdd: null,
                          ),
                          _KanbanColumn(
                            title: 'Done',
                            tasks: doneTasks,
                            color: AppColors.lightSuccess,
                            icon: Icons.check_circle_outline,
                            state: state,
                            onAdd: null,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    _titleController.clear();
    _descController.clear();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Task title'), autofocus: true),
                const SizedBox(height: 8),
                TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
                const SizedBox(height: AppSpacing.md),
                Align(alignment: Alignment.centerLeft, child: Text('Priority', style: Theme.of(ctx).textTheme.labelLarge)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: TaskPriority.values.map((p) {
                    final sel = p == _priority;
                    return GestureDetector(
                      onTap: () => setSt(() => _priority = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: sel ? p.color : Theme.of(ctx).extension<AppThemeExtension>()!.surfaceMuted, borderRadius: BorderRadius.circular(999)),
                        child: Text(p.label, style: TextStyle(color: sel ? Colors.white : Theme.of(ctx).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                context.read<AppState>().addTask(title: title, description: _descController.text.trim(), priorityIndex: _priority.index, categoryIndex: _category.index);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final Color color;
  final IconData icon;
  final AppState state;
  final VoidCallback? onAdd;
  const _KanbanColumn({required this.title, required this.tasks, required this.color, required this.icon, required this.state, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.radiusMedium)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                  child: Text('${tasks.length}', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Task cards
          ...tasks.map((task) => _KanbanCard(task: task, state: state)),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Task task;
  final AppState state;
  const _KanbanCard({required this.task, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            onTap: () => _showCardOptions(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4, height: 32,
                        decoration: BoxDecoration(color: task.priority.color, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                            color: task.status == TaskStatus.done ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(task.description, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      PillChip(label: task.priority.label, color: task.priority.color, icon: task.priority.icon),
                      PillChip(label: task.category.label, icon: task.category.icon),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCardOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Move to In Progress'),
              onTap: () {
                task.status = TaskStatus.inProgress;
                state.tasksRepo.update(task);
                state.refresh();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark Done'),
              onTap: () {
                state.toggleTaskDone(task.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Move to To Do'),
              onTap: () {
                task.status = TaskStatus.todo;
                task.completedAt = null;
                state.tasksRepo.update(task);
                state.refresh();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                state.deleteTask(task.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
