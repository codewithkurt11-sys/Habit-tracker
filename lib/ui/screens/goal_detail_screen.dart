import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../logic/app_state.dart';
import '../../logic/goal_progress_engine.dart';
import '../../data/models/goal.dart';
import '../../data/models/task.dart';
import '../widgets/shared_widgets.dart';
import 'goals_screen.dart';
import 'habit_detail_screen.dart';
import 'tasks_screen.dart';
import 'finance_screen.dart';
import 'notes_screen.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goalsRepo.getAll(includeArchived: true)
        .where((g) => g.id == goalId)
        .firstOrNull;
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal')), 
        body: const Center(child: Text('Goal not found.')),
      );
    }

    final habits = state.habitsRepo.getAll().where((h) =>
        goal.linkedHabitIds.contains(h.id) || h.goalId == goal.id || h.linkedGoalId == goal.id).toList();
    final tasks = state.tasksRepo.getAll(includeArchived: true).where((t) =>
        goal.linkedTaskIds.contains(t.id) || t.goalId == goal.id || t.linkedGoalId == goal.id).toList();
    final finance = state.financeRepo.getForGoal(goal.id);
    final savings = state.savingsGoalsRepo.getForGoal(goal.id);
    final notes = state.notesRepo.getForEntity('goal', goal.id);
    final snapshot = GoalProgressEngine.compute(
      goal: goal, habits: habits, tasks: tasks, finance: finance, savings: savings);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            tooltip: 'Edit goal',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showEditGoalDialog(context, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: goal.color.withValues(alpha: 0.14),
                        child: Icon(goal.category.icon, color: goal.color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goal.title, style: theme.textTheme.titleLarge),
                            if (goal.description.isNotEmpty)
                              Text(goal.description, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      PillChip(
                        label: goal.completed ? 'Complete' : 'Ongoing',
                        color: goal.completed ? theme.colorScheme.tertiary : goal.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: snapshot.fraction,
                      minHeight: 12,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(goal.color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${snapshot.currentUnits.toStringAsFixed(0)} / ${snapshot.targetUnits.toStringAsFixed(0)}'),
                      Text('${(snapshot.fraction * 100).round()}%', style: TextStyle(color: goal.color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatsGrid(snapshot: snapshot, goal: goal),
          const SizedBox(height: AppSpacing.md),
          _OverviewCard(goal: goal, snapshot: snapshot),
          const SizedBox(height: AppSpacing.md),
          _CalendarCard(snapshot: snapshot, goal: goal),
          const SizedBox(height: AppSpacing.md),
          _ConnectionsCard(goal: goal, habits: habits, tasks: tasks, finance: finance, savings: savings, notes: notes),
          const SizedBox(height: AppSpacing.md),
          if (snapshot.mode == GoalProgressMode.manual || goal.progressMode == GoalProgressMode.manual)
            _ManualProgressCard(goal: goal),
          const SizedBox(height: AppSpacing.md),
          _MilestonesCard(goal: goal),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final GoalProgressSnapshot snapshot;
  final Goal goal;
  const _StatsGrid({required this.snapshot, required this.goal});

  @override
  Widget build(BuildContext context) {
    final completedValue = switch (snapshot.mode) {
      GoalProgressMode.habitDays => '${snapshot.completedDates.length}',
      GoalProgressMode.taskCount => '${snapshot.completedTasks}',
      GoalProgressMode.financeAmount => '₱${snapshot.financialAmount.toStringAsFixed(0)}',
      GoalProgressMode.manual || GoalProgressMode.auto || GoalProgressMode.mixed => snapshot.currentUnits.toStringAsFixed(0),
    };
    final stats = <({String label, String value, IconData icon})>[
      (label: 'Completed', value: completedValue, icon: Icons.check_circle_outline),
      (label: 'Skipped', value: snapshot.mode == GoalProgressMode.habitDays ? '${snapshot.skippedDates.length}' : '—', icon: Icons.skip_next_outlined),
      (label: 'Missed', value: snapshot.mode == GoalProgressMode.habitDays ? '${snapshot.missedDates.length}' : '—', icon: Icons.warning_amber_outlined),
      (label: 'Remaining', value: snapshot.remainingUnits.toStringAsFixed(0), icon: Icons.hourglass_bottom_outlined),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.35,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: stats.map((s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Icon(s.icon, color: goal.color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(s.label, style: Theme.of(context).textTheme.bodySmall),
            ])),
          ]),
        ),
      )).toList(),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final Goal goal;
  final GoalProgressSnapshot snapshot;
  const _OverviewCard({required this.goal, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendarDaysLeft = goal.daysLeft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _row(context, 'Progress type', _modeLabel(snapshot.mode)),
          _row(context, 'Started', '${goal.startDate.month}/${goal.startDate.day}/${goal.startDate.year}'),
          if (goal.deadline != null)
            _row(context, 'Deadline', '${goal.deadline!.month}/${goal.deadline!.day}/${goal.deadline!.year}'),
          if (calendarDaysLeft >= 0)
            _row(context, 'Calendar days left', '$calendarDaysLeft'),
          _row(context, 'Goal units remaining', snapshot.remainingUnits.toStringAsFixed(0)),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))]),
  );

  String _modeLabel(GoalProgressMode mode) {
    switch (mode) {
      case GoalProgressMode.habitDays: return 'Habit days';
      case GoalProgressMode.taskCount: return 'Completed tasks';
      case GoalProgressMode.financeAmount: return 'Money / savings';
      case GoalProgressMode.manual: return 'Manual';
      case GoalProgressMode.auto: return 'Automatic';
      case GoalProgressMode.mixed: return 'Mixed connected sources';
    }
  }
}

class _CalendarCard extends StatelessWidget {
  final GoalProgressSnapshot snapshot;
  final Goal goal;
  const _CalendarCard({required this.snapshot, required this.goal});

  @override
  Widget build(BuildContext context) {
    if (snapshot.scheduledDates.isEmpty) {
      return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('No habit calendar data yet.', style: Theme.of(context).textTheme.bodySmall)));
    }
    final dates = snapshot.scheduledDates.toList()..sort();
    final visible = dates.length > 90 ? dates.sublist(dates.length - 90) : dates;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Goal Calendar', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Completed, skipped and missed scheduled days', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: 4, runSpacing: 4, children: visible.map((date) {
            final done = snapshot.completedDates.contains(date);
            final skipped = snapshot.skippedDates.contains(date);
            final missed = snapshot.missedDates.contains(date);
            final color = done ? goal.color : skipped ? theme.colorScheme.onSurface.withValues(alpha: 0.22) : missed ? theme.colorScheme.error.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHighest;
            return Tooltip(
              message: '${date.month}/${date.day}: ${done ? 'Completed' : skipped ? 'Skipped' : missed ? 'Missed' : 'Scheduled'}',
              child: Container(width: 20, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)), child: done ? const Icon(Icons.check, size: 13, color: Colors.white) : null),
            );
          }).toList()),
        ]),
      ),
    );
  }
}

class _ConnectionsCard extends StatelessWidget {
  final Goal goal;
  final List<dynamic> habits;
  final List<dynamic> tasks;
  final List<dynamic> finance;
  final List<dynamic> savings;
  final List<dynamic> notes;
  const _ConnectionsCard({required this.goal, required this.habits, required this.tasks, required this.finance, required this.savings, required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    // Re-read linked entities so checkbox toggles reflect immediately.
    final freshHabits = state.habitsRepo.getAll().where((h) =>
        goal.linkedHabitIds.contains(h.id) || h.goalId == goal.id || h.linkedGoalId == goal.id).toList();
    final freshTasks = state.tasksRepo.getAll(includeArchived: true).where((t) =>
        goal.linkedTaskIds.contains(t.id) || t.goalId == goal.id || t.linkedGoalId == goal.id).toList();
    final freshFinance = state.financeRepo.getForGoal(goal.id);
    final freshSavings = state.savingsGoalsRepo.getForGoal(goal.id);
    final freshNotes = state.notesRepo.getForEntity('goal', goal.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Connected', style: theme.textTheme.titleMedium)), IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit connections', onPressed: () => showEditGoalDialog(context, goal))]),
          if (freshHabits.isEmpty && freshTasks.isEmpty && freshFinance.isEmpty && freshSavings.isEmpty && freshNotes.isEmpty)
            Text('Nothing connected yet.', style: theme.textTheme.bodySmall),
          ...freshHabits.map((h) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Checkbox(value: h.isCompletedOn(DateTime.now()), onChanged: (_) => state.toggleHabit(h.id)), title: Text(h.name), subtitle: const Text('Habit'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.id))))),
          ...freshTasks.take(20).map((t) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Checkbox(value: t.status == TaskStatus.done, onChanged: (_) => state.toggleTaskDone(t.id)), title: Text(t.title), subtitle: const Text('Task'), onTap: () => showEditTaskDialog(context, t))),
          ...freshFinance.map((f) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_balance_wallet_outlined), title: Text(f.title), subtitle: Text('₱${f.amount.toStringAsFixed(2)}'), onTap: () => showEditFinanceDialog(context, f))),
          ...freshSavings.map((s) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.savings_outlined), title: Text(s.title), subtitle: const Text('Savings goal'))),
          ...freshNotes.map((n) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.sticky_note_2_outlined), title: Text(n.title), subtitle: const Text('Note'), onTap: () => showEditNoteDialog(context, n))),
        ]),
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final Goal goal;
  const _MilestonesCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    // Re-read goal from state so milestone toggles reflect immediately.
    final freshGoal = state.goalsRepo.getAll(includeArchived: true)
        .where((g) => g.id == goal.id).firstOrNull ?? goal;
    return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Milestones', style: theme.textTheme.titleMedium)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          tooltip: 'Add milestone',
          onPressed: () => _showAddMilestoneDialog(context, freshGoal.id),
        ),
      ]),
      if (freshGoal.milestones.isEmpty)
        Text('No milestones yet. Add one to track key checkpoints.', style: theme.textTheme.bodySmall)
      else
        ...freshGoal.milestones.asMap().entries.map((entry) {
          final i = entry.key; final m = entry.value;
          return CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: m.completed, title: Text(m.title), subtitle: m.dueDate == null ? null : Text('Due ${m.dueDate!.month}/${m.dueDate!.day}'), onChanged: (_) => state.toggleGoalMilestone(freshGoal.id, i));
        }),
    ])));
  }

  void _showAddMilestoneDialog(BuildContext context, String goalId) {
    final titleController = TextEditingController();
    DateTime? dueDate;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Milestone'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Milestone title'), autofocus: true),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date (optional)'),
              subtitle: Text(dueDate == null ? 'Not set' : '${dueDate!.month}/${dueDate!.day}/${dueDate!.year}'),
              trailing: dueDate == null
                  ? TextButton(onPressed: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                      if (picked != null) setDialogState(() => dueDate = picked);
                    }, child: const Text('Pick'))
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setDialogState(() => dueDate = null)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              context.read<AppState>().addGoalMilestone(goalId, title, dueDate: dueDate);
              Navigator.pop(ctx);
            }, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}

class _ManualProgressCard extends StatelessWidget {
  final Goal goal;
  const _ManualProgressCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    // Re-read goal from state so manual progress slider reflects current value.
    final freshGoal = state.goalsRepo.getAll(includeArchived: true)
        .where((g) => g.id == goal.id).firstOrNull ?? goal;
    final currentValue = freshGoal.currentValue.clamp(0.0, freshGoal.targetValue).toDouble();
    return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Manual Progress', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('Drag to update progress: ${freshGoal.currentValue.toStringAsFixed(0)} / ${freshGoal.targetValue.toStringAsFixed(0)}', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      Slider(
        value: currentValue,
        max: freshGoal.targetValue > 0 ? freshGoal.targetValue : 1.0,
        divisions: freshGoal.targetValue <= 100 ? freshGoal.targetValue.round() : null,
        label: currentValue.toStringAsFixed(0),
        onChanged: (value) {
          state.updateGoalProgress(freshGoal.id, value);
        },
      ),
    ])));
  }
}
