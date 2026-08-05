import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/goal.dart';
import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/models/finance_entry.dart';
import '../widgets/shared_widgets.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = state.goals;

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddGoalDialog(context),
          child: const Icon(Icons.add),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitleBar(
                title: 'Goals',
                subtitle: '${state.activeGoals.length} active • ${state.goalsAchieved} achieved',
              ),
            ),
            if (goals.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'No goals yet',
                  subtitle: 'Set a goal and link habits, tasks, and savings',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _GoalCard(goal: goals[index]),
                  childCount: goals.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddGoalSheet(),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final progress = state.computeGoalProgress(goal);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircularFillIcon(progress: progress / 100, icon: goal.category.icon, color: goal.color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.title, style: theme.textTheme.titleMedium),
                      Text(goal.category.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (goal.completed)
                  Icon(Icons.check_circle, color: goal.color)
                else if (goal.targetDate != null)
                  Text('${goal.daysLeft}d', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: goal.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(goal.color),
              minHeight: 6,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text('${progress.round()}%', style: TextStyle(color: goal.color, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (goal.linkedHabitIds.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(right: 4),
                    child: PillChip(label: '${goal.linkedHabitIds.length} habits', color: goal.color)),
                if (goal.linkedTaskIds.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(right: 4),
                    child: PillChip(label: '${goal.linkedTaskIds.length} tasks', color: goal.color)),
                if (goal.linkedFinanceId != null)
                  PillChip(label: 'finance', color: goal.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GoalDetailScreen extends StatelessWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goalsRepo.getById(goalId);

    if (goal == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Goal not found')));
    }

    final theme = Theme.of(context);
    final progress = state.computeGoalProgress(goal);
    final linkedHabits = goal.linkedHabitIds
        .map((id) => state.habitsRepo.getById(id))
        .whereType<Habit>()
        .toList();
    final linkedTasks = goal.linkedTaskIds
        .map((id) => state.tasksRepo.getById(id))
        .whereType<Task>()
        .toList();
    final linkedFinance = goal.linkedFinanceId != null
        ? state.financeRepo.getById(goal.linkedFinanceId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await showDeleteConfirmation(context, itemName: 'goal')) {
                await state.deleteGoal(goal.id);
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
            // Aggregate progress
            Row(
              children: [
                CircularFillIcon(progress: progress / 100, icon: goal.category.icon, color: goal.color, size: 64),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${progress.round()}%', style: theme.textTheme.displayMedium?.copyWith(color: goal.color)),
                    Text('Overall progress', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (goal.description.isNotEmpty) ...[
              Text('Description', style: theme.textTheme.titleSmall),
              Text(goal.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (goal.targetDate != null) ...[
              Text('Target date: ${goal.targetDate!.year}-${goal.targetDate!.month}-${goal.targetDate!.day}',
                  style: theme.textTheme.bodyMedium),
              Text('${goal.daysLeft} days remaining', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Linked habits
            if (linkedHabits.isNotEmpty) ...[
              Text('Linked Habits', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...linkedHabits.map((h) => _LinkedItem(
                title: h.title,
                progress: h.completionRate(days: 30),
                color: h.customColor ?? goal.color,
                icon: h.icon,
                progressText: '${h.currentStreak()} day streak',
              )),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Linked tasks
            if (linkedTasks.isNotEmpty) ...[
              Text('Linked Tasks', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...linkedTasks.map((t) => _LinkedItem(
                title: t.title,
                progress: t.progress,
                color: t.priority.color,
                icon: Icons.check_circle_outline,
                progressText: t.isDone ? 'Done' : 'Pending',
              )),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Linked finance
            if (linkedFinance != null) ...[
              Text('Linked Savings', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _LinkedItem(
                title: linkedFinance.title,
                progress: linkedFinance.progressFraction,
                color: const Color(0xFF6B9080),
                icon: Icons.savings,
                progressText:
                    '${state.settings.currencySymbol}${linkedFinance.totalContributed.toStringAsFixed(0)} / '
                    '${state.settings.currencySymbol}${linkedFinance.targetAmount.toStringAsFixed(0)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkedItem extends StatelessWidget {
  final String title;
  final double progress; // 0.0 to 1.0
  final Color color;
  final IconData icon;
  final String progressText;

  const _LinkedItem({
    required this.title,
    required this.progress,
    required this.color,
    required this.icon,
    required this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SoftCard(
        child: Row(
          children: [
            CircularFillIcon(progress: progress, icon: icon, color: color, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(progressText, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _categoryIndex = 6;
  DateTime? _targetDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Goal', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal title'),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Category', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: List.generate(GoalCategory.values.length, (i) {
              return ChoiceChip(
                label: Text(GoalCategory.values[i].label),
                selected: _categoryIndex == i,
                onSelected: (s) => setState(() => _categoryIndex = i),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Target date', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) setState(() => _targetDate = date);
                },
                child: Text(_targetDate != null
                    ? '${_targetDate!.year}-${_targetDate!.month}-${_targetDate!.day}'
                    : 'None'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_titleController.text.trim().isEmpty) return;
                context.read<AppState>().addGoal(
                  title: _titleController.text.trim(),
                  description: _descController.text.trim(),
                  categoryIndex: _categoryIndex,
                  targetDate: _targetDate,
                  colorValue: GoalCategory.values[_categoryIndex].color.value,
                );
                Navigator.pop(context);
              },
              child: const Text('Create Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
