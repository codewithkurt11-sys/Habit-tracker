import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/models/goal.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/note.dart';
import '../widgets/shared_widgets.dart';
import 'habit_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMissedFinance();
    });
  }

  void _checkMissedFinance() {
    final state = context.read<AppState>();
    final missed = state.getMissedFinanceDays();
    if (missed.isNotEmpty && mounted) {
      for (final (finance, date) in missed) {
        final currency = state.settings.currencySymbol;
        showMissedFinanceBanner(
          context,
          'Missed $currency${finance.dailyAmount.toStringAsFixed(0)} on '
          '${date.month}/${date.day} — recalculate remaining days?',
          onYes: () {
            state.refresh();
          },
        );
        break; // show one at a time
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final order = state.settings.dashboardWidgetOrder;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitleBar(
              title: _greeting(state.settings.userName),
              subtitle: _dateString(),
            ),
            for (final widget in order) ..._buildWidget(widget, state, theme),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWidget(String key, AppState state, ThemeData theme) {
    switch (key) {
      case 'habits':
        return [_buildHabitsSection(state, theme)];
      case 'tasks':
        return [_buildTasksSection(state, theme)];
      case 'goals':
        return [_buildGoalsSection(state, theme)];
      case 'finance':
        return [_buildFinanceSection(state, theme)];
      case 'notes':
        return [_buildNotesSection(state, theme)];
      default:
        return [];
    }
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    return '$greeting, ${name ?? 'there'}';
  }

  String _dateString() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  // ---------- Habits ----------
  Widget _buildHabitsSection(AppState state, ThemeData theme) {
    final habits = state.habitsDueToday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Today\'s Habits', subtitle: '${habits.where((h) => h.isCompletedOn(DateTime.now())).length}/${habits.length} done'),
        if (habits.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('No habits due today', style: TextStyle(color: Colors.grey)))
        else
          ...habits.map((h) => _HabitRow(habit: h)),
      ],
    );
  }

  // ---------- Tasks ----------
  Widget _buildTasksSection(AppState state, ThemeData theme) {
    final tasks = state.tasksDueToday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Today\'s Tasks', subtitle: '${tasks.where((t) => t.isDone).length}/${tasks.length} done'),
        if (tasks.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('No tasks due today', style: TextStyle(color: Colors.grey)))
        else
          ...tasks.map((t) => _TaskRow(task: t)),
      ],
    );
  }

  // ---------- Goals ----------
  Widget _buildGoalsSection(AppState state, ThemeData theme) {
    final goals = state.activeGoals.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Active Goals'),
        if (goals.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('No active goals', style: TextStyle(color: Colors.grey)))
        else
          ...goals.map((g) => _GoalRow(goal: g, progress: state.computeGoalProgress(g))),
      ],
    );
  }

  // ---------- Finance ----------
  Widget _buildFinanceSection(AppState state, ThemeData theme) {
    final finances = state.financesDueToday;
    final currency = state.settings.currencySymbol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Savings Due Today'),
        if (finances.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('No savings due today', style: TextStyle(color: Colors.grey)))
        else
          ...finances.map((f) => _FinanceRow(finance: f, currency: currency)),
      ],
    );
  }

  // ---------- Notes ----------
  Widget _buildNotesSection(AppState state, ThemeData theme) {
    final notes = state.notesRepo.getRecent(limit: 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Recent Notes'),
        if (notes.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('No notes yet', style: TextStyle(color: Colors.grey)))
        else
          ...notes.map((n) => _NoteRow(note: n)),
      ],
    );
  }
}

// ---------- Row widgets ----------

class _HabitRow extends StatelessWidget {
  final Habit habit;
  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isDone = habit.isCompletedOn(DateTime.now());
    final color = habit.customColor ?? theme.colorScheme.primary;
    final streak = habit.currentStreak();
    final milestone = habit.checkMilestone();

    return Dismissible(
      key: ValueKey('habit_${habit.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        color: Colors.grey.withValues(alpha: 0.2),
        child: const Icon(Icons.check, color: Colors.green),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: Colors.orange.withValues(alpha: 0.2),
        child: const Icon(Icons.skip_next, color: Colors.orange),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Complete
          await state.toggleHabit(habit.id);
          showUndoToast(context, 'Habit completed', () => state.toggleHabit(habit.id));
        } else {
          // Skip
          await state.skipHabit(habit.id);
          showUndoToast(context, 'Habit skipped (excused)', null);
        }
        return false; // don't actually remove
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: GestureDetector(
          onTap: () async {
            await state.toggleHabit(habit.id);
            showUndoToast(context, isDone ? 'Undone' : 'Habit completed',
                () => state.toggleHabit(habit.id));
          },
          child: CompletionRing(completed: isDone, color: color, milestone: milestone),
        ),
        title: Text(
          habit.title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (streak > 0) ...[
              Icon(Icons.local_fire_department, size: 14, color: color),
              const SizedBox(width: 2),
              Text('$streak day streak', style: TextStyle(fontSize: 12, color: color)),
            ],
          ],
        ),
        trailing: isDone
          ? QuickNoteButton(entityType: 'habit', entityId: habit.id)
          : null,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id))),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isDone = task.isDone;

    return ListTile(
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
      subtitle: task.dueTime != null
        ? Text('${task.dueTime!.hour}:${task.dueTime!.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 12, color: task.priority.color))
        : null,
      trailing: isDone
        ? QuickNoteButton(entityType: 'task', entityId: task.id)
        : null,
    );
  }
}

class _GoalRow extends StatelessWidget {
  final Goal goal;
  final double progress;
  const _GoalRow({required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        child: Row(
          children: [
            CircularFillIcon(progress: progress / 100, icon: goal.category.icon, color: goal.color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title, style: theme.textTheme.titleSmall),
                  if (goal.targetDate != null)
                    Text('${goal.daysLeft} days left', style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: goal.color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(goal.color),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('${progress.round()}%', style: theme.textTheme.titleMedium?.copyWith(color: goal.color)),
          ],
        ),
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  final FinanceEntry finance;
  final String currency;
  const _FinanceRow({required this.finance, required this.currency});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isConfirmed = finance.isConfirmedOn(DateTime.now());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: GestureDetector(
        onTap: () async {
          if (isConfirmed) {
            await state.unconfirmFinanceToday(finance.id);
            showUndoToast(context, 'Contribution undone', null);
          } else {
            await state.confirmFinanceToday(finance.id);
            showUndoToast(context, '$currency${finance.dailyAmount.toStringAsFixed(0)} saved!', null);
          }
        },
        child: CompletionRing(completed: isConfirmed, color: const Color(0xFF6B9080), size: 24),
      ),
      title: Text(finance.title),
      subtitle: Text('$currency${finance.dailyAmount.toStringAsFixed(0)}/day • ${finance.confirmedDays}/${finance.targetDays} days'),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final Note note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        onTap: () {
          // Navigate to note editor (handled by notes screen)
        },
        child: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(note.body, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
