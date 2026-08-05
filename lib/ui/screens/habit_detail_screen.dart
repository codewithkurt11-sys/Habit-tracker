import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/habit.dart';
import '../../data/models/goal.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/heatmap_widget.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final habit = state.habitsRepo.getById(habitId);

    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Habit not found')),
      );
    }

    final theme = Theme.of(context);
    final color = habit.customColor ?? theme.colorScheme.primary;
    final streak = habit.currentStreak();
    final best = habit.bestStreak();
    final rate = habit.completionRate(days: 30);
    final consistency = habit.consistencyScore;
    final milestone = habit.checkMilestone();
    final linkedGoal = habit.linkedGoalId != null
        ? state.goalsRepo.getById(habit.linkedGoalId!)
        : null;
    final linkedNotes = state.notesRepo.getForEntity('habit', habit.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, habit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await showDeleteConfirmation(context, itemName: 'habit')) {
                await state.deleteHabit(habit.id);
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
            // Streak summary
            Row(
              children: [
                CircularFillIcon(
                  progress: streak / (habit.targetStreak > 0 ? habit.targetStreak : 30),
                  icon: Icons.local_fire_department,
                  color: color,
                  size: 64,
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streak', style: theme.textTheme.displayMedium?.copyWith(color: color)),
                    Text('Current streak', style: theme.textTheme.bodyMedium),
                    if (milestone != null)
                      Text('🎉 $milestone day milestone!', style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Stats row
            Row(
              children: [
                _StatChip(label: 'Best', value: '$best', icon: Icons.emoji_events),
                const SizedBox(width: AppSpacing.sm),
                _StatChip(label: '30-day rate', value: '${(rate * 100).round()}%', icon: Icons.trending_up),
                const SizedBox(width: AppSpacing.sm),
                _StatChip(label: 'Consistency', value: '$consistency%', icon: Icons.insights),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Description
            if (habit.description.isNotEmpty) ...[
              Text('Description', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(habit.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Linked goal
            if (linkedGoal != null) ...[
              Text('Linked Goal', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              SoftCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _GoalLinkScreen(goalId: linkedGoal.id))),
                child: Row(
                  children: [
                    Icon(linkedGoal.category.icon, color: linkedGoal.color),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(linkedGoal.title)),
                    Text('${state.computeGoalProgress(linkedGoal).round()}%',
                        style: TextStyle(color: linkedGoal.color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Heatmap
            Text('Streak Heatmap', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            HabitHeatmap(habit: habit, baseColor: color),
            const SizedBox(height: AppSpacing.lg),
            // Notes
            if (linkedNotes.isNotEmpty) ...[
              Text('Notes (${linkedNotes.length})', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ...linkedNotes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: theme.textTheme.titleSmall),
                      Text(n.body, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Habit habit) {
    final titleCtrl = TextEditingController(text: habit.title);
    final descCtrl = TextEditingController(text: habit.description);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Habit', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  habit.title = titleCtrl.text.trim();
                  habit.description = descCtrl.text.trim();
                  context.read<AppState>().updateHabit(habit);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium),
            Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _GoalLinkScreen extends StatelessWidget {
  final String goalId;
  const _GoalLinkScreen({required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: const Center(child: Text('See Goals tab for details')),
    );
  }
}
