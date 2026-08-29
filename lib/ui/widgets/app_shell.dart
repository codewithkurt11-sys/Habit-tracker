import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/habits_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/focus_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/quotes_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/file_manager_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/kanban_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/search_screen.dart';
import '../screens/journal_screen.dart';
import 'shared_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _bottomIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _bottomScreens = const <Widget>[
    DashboardScreen(),
    HabitsScreen(),
    TasksScreen(),
    FinanceScreen(),
  ];

  final _bottomLabels = const ['Home', 'Habits', 'Tasks', 'Finance'];
  final _bottomIcons = const [
    Icons.home_outlined,
    Icons.repeat_rounded,
    Icons.check_circle_outline,
    Icons.account_balance_wallet_outlined,
  ];

  final _sidebarItems = const <({String label, IconData icon, Widget screen})>[
    (label: 'Goals', icon: Icons.track_changes_outlined, screen: GoalsScreen()),
    (label: 'Focus', icon: Icons.timer_outlined, screen: FocusScreen()),
    (label: 'Notes', icon: Icons.sticky_note_2_outlined, screen: NotesScreen()),
    (label: 'Journal', icon: Icons.book_outlined, screen: JournalScreen()),
    (label: 'Schedule', icon: Icons.calendar_today_outlined, screen: ScheduleScreen()),
    (label: 'Kanban Board', icon: Icons.view_kanban_outlined, screen: KanbanScreen()),
    (label: 'Calendar', icon: Icons.calendar_month_outlined, screen: CalendarScreen()),
    (label: 'Analytics', icon: Icons.analytics_outlined, screen: AnalyticsScreen()),
    (label: 'Quotes', icon: Icons.format_quote_outlined, screen: QuotesScreen()),
    (label: 'File Manager', icon: Icons.folder_outlined, screen: FileManagerScreen()),
    (label: 'Profile', icon: Icons.person_outline, screen: ProfileScreen()),
    (label: 'Settings', icon: Icons.settings_outlined, screen: SettingsScreen()),
  ];

  void _openSearch() {
    context.read<AppState>().hideQuickCapture();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openSidebarScreen(int index) {
    final item = _sidebarItems[index];
    final state = context.read<AppState>();
    state.hideQuickCapture();
    Navigator.of(context).pop();

    const screensWithOwnScaffold = {
      'Journal', 'Focus', 'Kanban Board', 'Analytics',
    };
    final content = AppDrawerScope(
      onOpen: () {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        _scaffoldKey.currentState?.openDrawer();
      },
      child: item.screen,
    );

    final Widget page = screensWithOwnScaffold.contains(item.label)
        ? content
        : Scaffold(
            body: content,
            floatingActionButton: _sidebarFab(context, item.label),
          );

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget? _sidebarFab(BuildContext context, String label) {
    final state = context.read<AppState>();
    VoidCallback? action;
    switch (label) {
      case 'Notes':
        action = () => showAddNoteDialog(context);
        break;
      case 'Goals':
        action = () => showAddGoalDialog(context);
        break;
      case 'Journal':
        action = () => showAddJournalDialog(context);
        break;
      case 'Focus':
        action = () => showFocusTimerDialog(context);
        break;
      case 'Quotes':
        action = () => showAddQuoteDialog(context);
        break;
      case 'Schedule':
        action = () => showAddScheduleDialog(context);
        break;
      case 'Kanban Board':
        action = () => showAddTaskDialog(context);
        break;
    }
    if (action == null) return null;
    return FloatingActionButton(
      heroTag: 'sidebar-$label-add',
      tooltip: 'Add $label',
      onPressed: () {
        state.hideQuickCapture();
        action!();
      },
      child: const Icon(Icons.add),
    );
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Text(
                state.settings.profileEmoji.isNotEmpty
                    ? state.settings.profileEmoji
                    : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleLarge),
                  if (state.settings.profileBio.isNotEmpty)
                    Text(
                      state.settings.profileBio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final item = _sidebarItems[index];
    return ListTile(
      leading: Icon(item.icon, color: theme.colorScheme.primary, size: 22),
      title: Text(item.label, style: theme.textTheme.bodyLarge),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      onTap: () => _openSidebarScreen(index),
    );
  }

  void _selectBottom(int index) {
    context.read<AppState>().hideQuickCapture();
    setState(() => _bottomIndex = index);
  }

  Widget _bottomDestination(BuildContext context, int index) {
    final theme = Theme.of(context);
    final selected = _bottomIndex == index;
    return Expanded(
      child: InkResponse(
        onTap: () => _selectBottom(index),
        radius: 28,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_bottomIcons[index],
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                _bottomLabels[index],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
                  for (int i = 0; i < _sidebarItems.length; i++)
                    _buildSidebarItem(context, i),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          AppDrawerScope(
            onOpen: () => _scaffoldKey.currentState?.openDrawer(),
            child: _bottomScreens[_bottomIndex],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildQuickCapture(context, state, theme),
      bottomNavigationBar: BottomAppBar(
        height: 70,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        child: Row(
          children: [
            _bottomDestination(context, 0),
            _bottomDestination(context, 1),
            const SizedBox(width: 112),
            _bottomDestination(context, 2),
            _bottomDestination(context, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCapture(
      BuildContext context, AppState state, ThemeData theme) {
    final open = state.quickCaptureOpen;
    final actions = <({IconData icon, String label, VoidCallback action})>[
      (icon: Icons.check_circle, label: 'Task', action: () => showAddTaskDialog(context)),
      (icon: Icons.repeat_rounded, label: 'Habit', action: () => showAddHabitDialog(context)),
      (icon: Icons.track_changes_outlined, label: 'Goal', action: () => showAddGoalDialog(context)),
      (icon: Icons.sticky_note_2_outlined, label: 'Note', action: () => showAddNoteDialog(context)),
      (icon: Icons.book_outlined, label: 'Journal', action: () => showAddJournalDialog(context)),
      (icon: Icons.account_balance_wallet_outlined, label: 'Finance', action: () => showAddFinanceDialog(context)),
      (icon: Icons.calendar_today_outlined, label: 'Schedule', action: () => showAddScheduleDialog(context)),
      (icon: Icons.timer_outlined, label: 'Focus', action: () => showFocusTimerDialog(context)),
    ];

    return TapRegion(
      onTapOutside: (_) => state.hideQuickCapture(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        if (open)
          Material(
            elevation: 8,
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: actions.map((item) {
                    return ActionChip(
                      avatar: Icon(item.icon,
                          size: 16, color: theme.colorScheme.primary),
                      label: Text(item.label,
                          style: theme.textTheme.labelSmall),
                      onPressed: () {
                        state.hideQuickCapture();
                        item.action();
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'global-quick-capture',
          tooltip: open ? 'Close quick actions' : 'Quick action',
          onPressed: state.toggleQuickCapture,
          icon: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(open ? Icons.close : Icons.add),
          ),
          label: Text(open ? 'Close' : 'Quick'),
        ),
        ],
      ),
    );
  }
}
