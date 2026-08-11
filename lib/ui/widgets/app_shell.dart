import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/habits_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/focus_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/quotes_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/file_manager_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/export_screen.dart';
import '../screens/kanban_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/search_screen.dart';
import '../screens/journal_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _bottomIndex = 0;
  bool _showQuickCapture = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _bottomScreens = <Widget>[
    const DashboardScreen(),
    const HabitsScreen(),
    const TasksScreen(),
    const FinanceScreen(),
    const FocusScreen(),
  ];

  final _bottomLabels = ['Home', 'Habits', 'Tasks', 'Finance', 'Focus'];
  final _bottomIcons = [
    Icons.dashboard_outlined,
    Icons.repeat_rounded,
    Icons.check_circle_outline,
    Icons.account_balance_wallet_outlined,
    Icons.timer_outlined,
  ];

  Widget _sidebarScreen(int index) {
    switch (index) {
      case 0:
        return const NotesScreen();
      case 1:
        return const GoalsScreen();
      case 2:
        return const QuotesScreen();
      case 3:
        return const ScheduleScreen();
      case 4:
        return const KanbanScreen();
      case 5:
        return const AnalyticsScreen();
      case 6:
        return const CalendarScreen();
      case 7:
        return const FileManagerScreen();
      case 8:
        return const ProfileScreen();
      case 9:
        return const SettingsScreen();
      case 10:
        return const ExportScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  String _sidebarLabel(int index) {
    const labels = [
      'Notes',
      'Goals',
      'Quotes',
      'Schedule',
      'Kanban Board',
      'Analytics',
      'Calendar',
      'File Manager',
      'Profile',
      'Settings',
      'Backup & Export',
    ];
    return labels[index];
  }

  IconData _sidebarIcon(int index) {
    const icons = [
      Icons.sticky_note_2_outlined,
      Icons.track_changes_outlined,
      Icons.format_quote_outlined,
      Icons.calendar_today_outlined,
      Icons.view_kanban_outlined,
      Icons.analytics_outlined,
      Icons.calendar_month_outlined,
      Icons.folder_outlined,
      Icons.person_outline,
      Icons.settings_outlined,
      Icons.download_outlined,
    ];
    return icons[index];
  }

  void _openSidebarScreen(int index) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(_sidebarLabel(index)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                      builder: (_) => const Scaffold(body: SearchScreen())),
                ),
              ),
            ],
          ),
          body: _sidebarScreen(index),
          floatingActionButton: _sidebarFab(ctx, index),
        ),
      ),
    );
  }

  Widget? _sidebarFab(BuildContext context, int index) {
    switch (index) {
      case 0: // Notes
        return FloatingActionButton(
          onPressed: () => showAddNoteDialog(context),
          child: const Icon(Icons.add),
        );
      case 1: // Goals
        return FloatingActionButton(
          onPressed: () => showAddGoalDialog(context),
          child: const Icon(Icons.add),
        );
      case 2: // Quotes
        return FloatingActionButton(
          onPressed: () => showAddQuoteDialog(context),
          child: const Icon(Icons.add),
        );
      case 3: // Schedule
        return FloatingActionButton(
          onPressed: () => showAddScheduleDialog(context),
          child: const Icon(Icons.add),
        );
      case 4: // Kanban
        return FloatingActionButton(
          onPressed: () => showAddTaskDialog(context),
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  Widget _buildSidebarHeader(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final state = context.read<AppState>();
    final name = state.settings.userName ?? 'User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ext.gradientTop, theme.colorScheme.surface],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(name, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    return ListTile(
      leading:
          Icon(_sidebarIcon(index), color: theme.colorScheme.primary, size: 22),
      title: Text(_sidebarLabel(index), style: theme.textTheme.bodyLarge),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      onTap: () => _openSidebarScreen(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < 11; i++) _buildSidebarItem(context, i),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
      body: _bottomScreens[_bottomIndex],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Quick Capture row (above the existing Add button) ──
          if (_showQuickCapture) ...[
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _quickCaptureChip(context, Icons.check_circle, 'Task',
                      () => showAddTaskDialog(context)),
                  _quickCaptureChip(context, Icons.sticky_note_2_outlined,
                      'Note', () => showAddNoteDialog(context)),
                  _quickCaptureChip(context, Icons.book_outlined, 'Journal',
                      () => showAddJournalDialog(context)),
                  _quickCaptureChip(context, Icons.repeat_rounded, 'Habit',
                      () => showAddHabitDialog(context)),
                  _quickCaptureChip(context, Icons.track_changes_outlined,
                      'Goal', () => showAddGoalDialog(context)),
                  _quickCaptureChip(
                      context,
                      Icons.account_balance_wallet_outlined,
                      'Finance',
                      () => showAddFinanceDialog(context)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // ── Existing Add button (unchanged, now toggles Quick Capture) ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showQuickCapture)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FloatingActionButton.small(
                    heroTag: 'quick-close',
                    tooltip: 'Close',
                    onPressed: () => setState(() => _showQuickCapture = false),
                    child: const Icon(Icons.close),
                  ),
                ),
              FloatingActionButton.small(
                heroTag: 'global-note',
                tooltip: _showQuickCapture ? 'Quick capture' : 'Quick capture',
                onPressed: () =>
                    setState(() => _showQuickCapture = !_showQuickCapture),
                child:
                    Icon(_showQuickCapture ? Icons.edit_note : Icons.flash_on),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) => setState(() => _bottomIndex = i),
        destinations: List.generate(5, (i) {
          return NavigationDestination(
            icon: Icon(_bottomIcons[i]),
            selectedIcon: Icon(_bottomIcons[i]),
            label: _bottomLabels[i],
          );
        }),
      ),
    );
  }

  Widget _quickCaptureChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label, style: theme.textTheme.labelSmall),
      onPressed: () {
        setState(() => _showQuickCapture = false);
        onTap();
      },
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
