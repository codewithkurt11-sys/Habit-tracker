import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/goal.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = state.goalsRepo.getActive();

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
                    Text('Goals',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('${goals.length} active goals',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: goals.isEmpty
              ? const EmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'No goals yet',
                  subtitle: 'Set a goal and track your progress',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: goals.length,
                  itemBuilder: (_, i) => _GoalTile(goal: goals[i]),
                ),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final progress = goal.progressFraction;
    final milestones = goal.milestones;

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteGoal(goal.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(goal.category.icon, color: goal.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          Text(goal.title, style: theme.textTheme.titleSmall),
                    ),
                    if (goal.daysLeft >= 0)
                      PillChip(
                        label: goal.daysLeft == 0
                            ? 'Today'
                            : '${goal.daysLeft}d left',
                        color: goal.daysLeft <= 3
                            ? theme.colorScheme.error
                            : goal.color,
                        icon: Icons.event_outlined,
                      ),
                  ],
                ),
                if (goal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(goal.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${goal.currentValue.toStringAsFixed(0)} / ${goal.targetValue.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: goal.color, fontWeight: FontWeight.bold)),
                  ],
                ),
                // Milestones
                if (milestones.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...milestones.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => state.toggleGoalMilestone(
                              goal.id, milestones.indexOf(m)),
                          child: Row(
                            children: [
                              Icon(
                                m.completed
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: m.completed
                                    ? goal.color
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  m.title,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    decoration: m.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: m.completed
                                        ? theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddGoalDialog extends StatefulWidget {
  const _AddGoalDialog();

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetController = TextEditingController(text: '100');
  int _categoryIndex = 6;
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return AlertDialog(
      title: const Text('New Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Goal title',
                hintText: 'e.g. Read 24 books this year',
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
            // Category
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Category', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(GoalCategory.values.length, (i) {
                final sel = i == _categoryIndex;
                final c = GoalCategory.values[i];
                return GestureDetector(
                  onTap: () => setState(() => _categoryIndex = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? c.color : ext.surfaceMuted,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon,
                            size: 14,
                            color: sel
                                ? Colors.white
                                : theme.colorScheme.onSurface),
                        const SizedBox(width: 4),
                        Text(c.label,
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Target value',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Deadline: ', style: theme.textTheme.labelLarge),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setState(() => _deadline = d);
                  },
                  child: Text(_deadline == null
                      ? 'Select date'
                      : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year}'),
                ),
                if (_deadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _deadline = null),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
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
            final target = double.tryParse(_targetController.text.trim());
            if (title.isEmpty || target == null || target <= 0) return;
            context.read<AppState>().addGoal(
                  title: title,
                  description: _descController.text.trim(),
                  categoryIndex: _categoryIndex,
                  deadline: _deadline,
                  targetValue: target,
                  colorValue:
                      GoalCategory.values[_categoryIndex].color.toARGB32(),
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
void showAddGoalDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _AddGoalDialog(),
  );
}
