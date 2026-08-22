import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/habit.dart';
import '../../data/models/goal.dart';
import '../../data/models/task.dart';
import '../../data/models/focus_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';
import 'habit_detail_screen.dart';
import 'goal_detail_screen.dart';
import 'notes_screen.dart';
import 'finance_screen.dart';
import 'tasks_screen.dart';
import 'journal_screen.dart';
import 'schedule_screen.dart';
import 'quotes_screen.dart';
import 'focus_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.toLowerCase().trim();

    List<_SearchResult> results = [];
    if (q.isNotEmpty) {
      // Habits
      for (final h in state.habitsRepo.getAll()) {
        if (h.name.toLowerCase().contains(q) || h.category.name.contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.habit,
              title: h.name,
              subtitle: 'Habit • ${h.frequency.name}',
              icon: h.icon.data,
              color: h.customColor ?? AppColors.categoryLifestyle,
              id: h.id));
        }
      }
      // Tasks
      for (final t in state.tasksRepo.getAll(includeArchived: true)) {
        if (t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.category.name.contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.task,
              title: t.title,
              subtitle: 'Task • ${t.priority.label}',
              icon: t.category.icon,
              color: t.priority.color,
              id: t.id));
        }
      }
      // Goals
      for (final g in state.goalsRepo.getAll(includeArchived: true)) {
        if (g.title.toLowerCase().contains(q) ||
            g.description.toLowerCase().contains(q) ||
            g.category.label.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.goal,
              title: g.title,
              subtitle: 'Goal • ${g.category.label}',
              icon: g.category.icon,
              color: g.color,
              id: g.id));
        }
      }
      // Journal
      for (final j in state.journalRepo.getAll()) {
        if (j.title.toLowerCase().contains(q) ||
            j.body.toLowerCase().contains(q) ||
            j.tags.any((t) => t.toLowerCase().contains(q))) {
          results.add(_SearchResult(
              type: _SearchType.journal,
              title: j.title,
              subtitle:
                  'Journal • ${j.date.month}/${j.date.day}/${j.date.year}',
              icon: Icons.book_outlined,
              color: const Color(0xFF7B93B5),
              id: j.id));
        }
      }
      // Notes
      for (final n in state.notesRepo.getAll(includeArchived: true)) {
        if (n.title.toLowerCase().contains(q) ||
            n.body.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q))) {
          results.add(_SearchResult(
              type: _SearchType.note,
              title: n.title,
              subtitle: 'Note • ${n.timestamp.month}/${n.timestamp.day}',
              icon: Icons.sticky_note_2_outlined,
              color: const Color(0xFFE8C56F),
              id: n.id));
        }
      }
      // Finance
      for (final f in state.financeRepo.getAll()) {
        if (f.title.toLowerCase().contains(q) ||
            f.note.toLowerCase().contains(q) ||
            f.categoryLabel.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.finance,
              title: f.title,
              subtitle:
                  'Finance • ${f.categoryLabel} • \$${f.amount.toStringAsFixed(2)}',
              icon: f.categoryIcon,
              color: f.categoryColor,
              id: f.id));
        }
      }
      // Schedule
      for (final s in state.scheduleRepo.getAll()) {
        if (s.title.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.schedule,
              title: s.title,
              subtitle: 'Schedule • ${s.dateTime.month}/${s.dateTime.day}',
              icon: Icons.calendar_today,
              color: const Color(0xFFB58BB5),
              id: s.id));
        }
      }
      // Savings goals
      for (final sg in state.savingsGoalsRepo.getAll()) {
        if (sg.title.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.savings,
              title: sg.title,
              subtitle:
                  'Savings • ${sg.totalContributed.toStringAsFixed(0)}/${sg.targetAmount.toStringAsFixed(0)}',
              icon: Icons.savings_outlined,
              color: const Color(0xFF6B9080),
              id: sg.id));
        }
      }
      // Quotes
      for (final quote in state.quotesRepo.getAll()) {
        if (quote.text.toLowerCase().contains(q) ||
            quote.author.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.quote,
              title: quote.text,
              subtitle: quote.author.isEmpty
                  ? 'Quote'
                  : 'Quote • ${quote.author}',
              icon: Icons.format_quote_outlined,
              color: const Color(0xFFE8946F),
              id: quote.id));
        }
      }
      // Focus sessions (searchable by the linked task title)
      for (final session in state.focusRepo.getAll()) {
        final title = session.taskTitle ?? '';
        if (title.toLowerCase().contains(q) ||
            session.type.name.toLowerCase().contains(q)) {
          results.add(_SearchResult(
              type: _SearchType.focus,
              title: title.isEmpty ? session.type.label : title,
              subtitle:
                  'Focus • ${session.type.label} • ${(session.completedSeconds / 60).round()} min',
              icon: Icons.timer_outlined,
              color: const Color(0xFF7B93B5),
              id: session.id));
        }
      }
    }

    // Group by type
    final grouped = <_SearchType, List<_SearchResult>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search habits, tasks, goals, notes, finance...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                })
                            : null,
                        isDense: true,
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _SearchHints()
                  : results.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No results',
                          subtitle: 'Try a different search term')
                      : ListView(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xxl),
                          children: [
                            for (final entry in grouped.entries) ...[
                              _GroupHeader(
                                  type: entry.key, count: entry.value.length),
                              ...entry.value.map(
                                  (r) => _ResultTile(result: r, state: state)),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SearchType { habit, task, goal, journal, note, finance, schedule, savings, quote, focus }

extension _SearchTypeExt on _SearchType {
  String get label {
    switch (this) {
      case _SearchType.habit:
        return 'Habits';
      case _SearchType.task:
        return 'Tasks';
      case _SearchType.goal:
        return 'Goals';
      case _SearchType.journal:
        return 'Journal';
      case _SearchType.note:
        return 'Notes';
      case _SearchType.finance:
        return 'Finance';
      case _SearchType.schedule:
        return 'Schedule';
      case _SearchType.savings:
        return 'Savings Goals';
      case _SearchType.quote:
        return 'Quotes';
      case _SearchType.focus:
        return 'Focus';
    }
  }
}

class _SearchResult {
  final _SearchType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String id;
  const _SearchResult(
      {required this.type,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.id});
}

class _SearchHints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hints = [
      (Icons.repeat_rounded, 'Habits', 'Search by name or category'),
      (
        Icons.check_circle_outline,
        'Tasks',
        'Search by title, description, or category'
      ),
      (Icons.track_changes, 'Goals', 'Search by title or description'),
      (Icons.book_outlined, 'Journal', 'Search by title, body, or tags'),
      (Icons.sticky_note_2_outlined, 'Notes', 'Search by title, content, or tags'),
      (
        Icons.account_balance_wallet_outlined,
        'Finance',
        'Search by title, note, or category'
      ),
      (Icons.calendar_today, 'Schedule', 'Search by event title'),
      (Icons.savings_outlined, 'Savings Goals', 'Search by savings goal title'),
      (Icons.format_quote_outlined, 'Quotes', 'Search by quote text or author'),
      (Icons.timer_outlined, 'Focus', 'Search by session task or type'),
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.lg),
            Text('Global Search', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('Search across all your data',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            ...hints.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(h.$1,
                          size: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.$2, style: theme.textTheme.bodyMedium),
                          Text(h.$3, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final _SearchType type;
  final int count;
  const _GroupHeader({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Text('${type.label} ($count)',
          style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold)),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final AppState state;
  const _ResultTile({required this.result, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      child: Card(
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: result.color.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall)),
                  child: Icon(result.icon, color: result.color, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title,
                          style: theme.textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(result.subtitle,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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

  void _handleTap(BuildContext context) {
    switch (result.type) {
      case _SearchType.habit:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: result.id),
          ),
        );
      case _SearchType.task:
        final task = state.tasksRepo.getById(result.id);
        if (task != null) showEditTaskDialog(context, task);
      case _SearchType.goal:
        if (state.goalsRepo.getAll(includeArchived: true).any((g) => g.id == result.id)) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: result.id)));
        }
      case _SearchType.journal:
        final entry = state.journalRepo.getAll().where((e) => e.id == result.id).firstOrNull;
        if (entry != null) {
          showEditJournalDialog(context, entry);
        }
      case _SearchType.note:
        final note = state.notesRepo.getAll(includeArchived: true).where((n) => n.id == result.id).firstOrNull;
        if (note != null) showEditNoteDialog(context, note);
      case _SearchType.finance:
        final entry = state.financeRepo.getAll().where((e) => e.id == result.id).firstOrNull;
        if (entry != null) showEditFinanceDialog(context, entry);
      case _SearchType.schedule:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
        );
      case _SearchType.savings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinanceScreen()),
        );
      case _SearchType.quote:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuotesScreen()),
        );
      case _SearchType.focus:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FocusScreen()),
        );
    }
  }
}
