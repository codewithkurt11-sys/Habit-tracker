import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/habits_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/file_manager_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _bottomIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _bottomScreens = <Widget>[
    const DashboardScreen(),
    const HabitsScreen(),
    const TasksScreen(),
    const GoalsScreen(),
    const CalendarScreen(),
  ];

  final _bottomLabels = ['Home', 'Habits', 'Tasks', 'Goals', 'Calendar'];
  final _bottomIcons = [
    Icons.dashboard_outlined,
    Icons.repeat_rounded,
    Icons.check_circle_outline,
    Icons.track_changes_outlined,
    Icons.calendar_month_outlined,
  ];

  Widget _sidebarScreen(int index) {
    switch (index) {
      case 0: return const NotesScreen();
      case 1: return const FinanceScreen();
      case 2: return const FileManagerScreen();
      case 3: return const ProfileScreen();
      case 4: return const SettingsScreen();
      default: return const SizedBox.shrink();
    }
  }

  String _sidebarLabel(int index) {
    const labels = ['Notes', 'Finance', 'File Manager', 'Profile', 'Settings'];
    return labels[index];
  }

  IconData _sidebarIcon(int index) {
    const icons = [
      Icons.sticky_note_2_outlined,
      Icons.savings_outlined,
      Icons.folder_outlined,
      Icons.person_outline,
      Icons.settings_outlined,
    ];
    return icons[index];
  }

  void _openSidebarScreen(int index) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(_sidebarLabel(index)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: _sidebarScreen(index),
        ),
      ),
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
            Text('Life Tracker v2.0.0', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_sidebarIcon(index), color: theme.colorScheme.primary, size: 22),
      title: Text(_sidebarLabel(index), style: theme.textTheme.bodyLarge),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      onTap: () => _openSidebarScreen(index),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  for (int i = 0; i < 5; i++) _buildSidebarItem(context, i),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
      body: _bottomScreens[_bottomIndex],
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
}

/// Global helper to open the drawer from any screen.
void openAppDrawer(BuildContext context) {
  Scaffold.of(context).openDrawer();
}
