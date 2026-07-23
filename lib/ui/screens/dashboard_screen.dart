import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../logic/stats_engine.dart';
import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/models/goal.dart';
import '../../data/models/quote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dueHabits = state.habitsRepo.getDueToday();
    final completedHabits = dueHabits.where((h) => h.isCompletedOn(today)).toList();
    final activeTasks = state.tasksRepo.getActive();
    final overdueTasks = activeTasks.where((t) => t.isOverdue).toList();
    final todayTasks = activeTasks.where((t) {
      if (t.dueDate == null) return false;
      final td = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return td.isAtSameMomentAs(today);
    }).toList();
    final activeGoals = state.goalsRepo.getActive();
    final todaySchedule = state.scheduleRepo.getForToday();
    final focusMinutes = state.focusRepo.getTotalFocusMinutesToday();
    final dailyQuote = state.quotesRepo.quoteForDate(today);
    final habits = state.habitsRepo.getAll();
    final insights = StatsEngine.generateInsights(
      habits: habits,
      tasks: activeTasks,
      focusSessions: state.focusRepo.getAll(),
    );

    final habitsPct = dueHabits.isEmpty ? 0.0 : completedHabits.length / dueHabits.length;
    final userName = state.settings.userName ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Hi, $userName',
              subtitle: _greeting(),
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  // Daily progress card
                  _DailyProgressCard(
                    completed: completedHabits.length,
                    total: dueHabits.length,
                    progress: habitsPct,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quick stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(child: _QuickStat(icon: Icons.check_circle_outline, label: 'Tasks', value: '${activeTasks.length}', sub: overdueTasks.isNotEmpty ? '${overdueTasks.length} overdue' : 'active', color: ext.categoryOther)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _QuickStat(icon: Icons.track_changes_outlined, label: 'Goals', value: '${activeGoals.length}', sub: 'active', color: ext.categoryLifestyle)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _QuickStat(icon: Icons.timer_outlined, label: 'Focus', value: '${focusMinutes}m', sub: 'today', color: ext.success)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quick actions
                  _QuickActionsGrid(state: state),
                  const SizedBox(height: AppSpacing.md),

                  // Today's habits
                  if (dueHabits.isNotEmpty) ...[
                    _SectionHeader(title: 'Today\'s Habits', count: '${completedHabits.length}/${dueHabits.length}'),
                    ...dueHabits.take(4).map((h) => _DashboardHabitTile(habit: h, state: state)),
                    if (dueHabits.length > 4)
                      _SeeAllButton(label: 'View all ${dueHabits.length} habits'),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Today's tasks
                  if (todayTasks.isNotEmpty || overdueTasks.isNotEmpty) ...[
                    _SectionHeader(title: 'Tasks', count: '${todayTasks.length + overdueTasks.length} pending'),
                    ...overdueTasks.take(2).map((t) => _DashboardTaskTile(task: t, state: state, isOverdue: true)),
                    ...todayTasks.take(3).map((t) => _DashboardTaskTile(task: t, state: state)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Today's schedule
                  if (todaySchedule.isNotEmpty) ...[
                    _SectionHeader(title: 'Today\'s Schedule', count: '${todaySchedule.length} items'),
                    ...todaySchedule.take(3).map((s) => _DashboardScheduleTile(item: s, state: state)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Active goals summary
                  if (activeGoals.isNotEmpty) ...[
                    _SectionHeader(title: 'Goal Progress', count: '${activeGoals.length} active'),
                    ...activeGoals.take(2).map((g) => _DashboardGoalTile(goal: g, state: state)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Top insight
                  if (insights.isNotEmpty) ...[
                    _SectionHeader(title: 'Insight', count: ''),
                    _InsightBanner(insight: insights.first),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Daily quote
                  _QuoteBanner(quote: dailyQuote),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DailyProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;
  const _DailyProgressCard({required this.completed, required this.total, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final pct = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ext.gradientTop, ext.gradientBottom],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Progress ring
                SizedBox(
                  width: 64, height: 64,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                      Center(
                        child: Text('$pct%', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Progress', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'No habits due today'
                            : completed == total
                                ? 'All done! Great work!'
                                : '$completed of $total habits completed',
                        style: theme.textTheme.bodySmall,
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

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _QuickStat({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            Text(sub, style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final AppState state;
  const _QuickActionsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
        children: [
          _QuickAction(icon: Icons.add_circle, label: 'Habit', color: AppColors.categoryLifestyle, onTap: () => _showAddHabit(context)),
          _QuickAction(icon: Icons.check_circle, label: 'Task', color: AppColors.categoryOther, onTap: () => _showAddTask(context)),
          _QuickAction(icon: Icons.edit_note, label: 'Journal', color: const Color(0xFF7B93B5), onTap: () => _showAddJournal(context)),
          _QuickAction(icon: Icons.timer, label: 'Focus', color: AppColors.lightSuccess, onTap: () => _showFocusTimer(context)),
        ],
      ),
    );
  }

  void _showAddHabit(BuildContext context) {
    showDialog(context: context, builder: (_) => const _QuickHabitDialog());
  }
  void _showAddTask(BuildContext context) {
    showDialog(context: context, builder: (_) => const _QuickTaskDialog());
  }
  void _showAddJournal(BuildContext context) {
    showDialog(context: context, builder: (_) => const _QuickJournalDialog());
  }
  void _showFocusTimer(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the Focus tab to start a timer'), duration: Duration(seconds: 2)),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.radiusSmall)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (count.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(count, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final String label;
  const _SeeAllButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: TextButton(
        onPressed: () {},
        child: Text(label),
      ),
    );
  }
}

class _DashboardHabitTile extends StatelessWidget {
  final Habit habit;
  final AppState state;
  const _DashboardHabitTile({required this.habit, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = habit.isCompletedOn(DateTime.now());
    final color = habit.customColor ?? AppColors.categoryLifestyle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      child: Card(
        child: InkWell(
          onTap: () => state.toggleHabit(habit.id),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Icon(habit.icon.data, color: color, size: 22),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    habit.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
                    ),
                  ),
                ),
                Icon(done ? Icons.check_circle : Icons.circle_outlined, size: 22, color: done ? color : theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTaskTile extends StatelessWidget {
  final Task task;
  final AppState state;
  final bool isOverdue;
  const _DashboardTaskTile({required this.task, required this.state, this.isOverdue = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      child: Card(
        child: InkWell(
          onTap: () => state.toggleTaskDone(task.id),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Icon(task.priority.icon, color: task.priority.color, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(task.title, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isOverdue)
                  PillChip(label: 'Overdue', color: theme.colorScheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardScheduleTile extends StatelessWidget {
  final dynamic item;
  final AppState state;
  const _DashboardScheduleTile({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = '${item.dateTime.hour.toString().padLeft(2, '0')}:${item.dateTime.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      child: Card(
        child: InkWell(
          onTap: () => state.toggleSchedule(item.id),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Text(time, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(child: Text(item.title, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(item.done ? Icons.check_circle : Icons.circle_outlined, size: 18, color: item.done ? AppColors.lightSuccess : theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardGoalTile extends StatelessWidget {
  final Goal goal;
  final AppState state;
  const _DashboardGoalTile({required this.goal, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(goal.category.icon, color: goal.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(goal.title, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${(goal.progressFraction * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall?.copyWith(color: goal.color, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: goal.progressFraction,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final dynamic insight;
  const _InsightBanner({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Text(insight.icon as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.title as String, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(insight.description as String, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteBanner extends StatelessWidget {
  final Quote quote;
  const _QuoteBanner({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ext.gradientTop, ext.gradientBottom]),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Icon(Icons.format_quote, color: theme.colorScheme.primary, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(quote.text, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text('— ${quote.author}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Quick add dialogs
class _QuickHabitDialog extends StatefulWidget {
  const _QuickHabitDialog();
  @override
  State<_QuickHabitDialog> createState() => _QuickHabitDialogState();
}

class _QuickHabitDialogState extends State<_QuickHabitDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Habit'),
      content: TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Habit name'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            context.read<AppState>().addHabit(name: name, categoryIndex: 1, frequencyIndex: 0, iconIndex: 15);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _QuickTaskDialog extends StatefulWidget {
  const _QuickTaskDialog();
  @override
  State<_QuickTaskDialog> createState() => _QuickTaskDialogState();
}

class _QuickTaskDialogState extends State<_QuickTaskDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Task'),
      content: TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Task title'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final title = _controller.text.trim();
            if (title.isEmpty) return;
            context.read<AppState>().addTask(title: title);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _QuickJournalDialog extends StatefulWidget {
  const _QuickJournalDialog();
  @override
  State<_QuickJournalDialog> createState() => _QuickJournalDialogState();
}

class _QuickJournalDialogState extends State<_QuickJournalDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  @override
  void dispose() { _titleController.dispose(); _bodyController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Journal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
          const SizedBox(height: 8),
          TextField(controller: _bodyController, decoration: const InputDecoration(labelText: 'What happened?'), maxLines: 3),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            context.read<AppState>().addJournal(title: title, body: _bodyController.text.trim(), date: DateTime.now());
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
