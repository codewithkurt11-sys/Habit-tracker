import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/user_settings.dart';
import 'profile_screen.dart';
import '../../core/theme/app_spacing.dart';
import 'export_screen.dart';
import '../../ui/widgets/shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ScreenTitleBar(title: 'Settings', onMenuTap: null),
        const SizedBox(height: AppSpacing.sm),

        const _SectionLabel('Account'),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(state.settings.profileEmoji.isEmpty ? '🙂' : state.settings.profileEmoji)),
            title: Text(state.settings.userName ?? 'Your profile'),
            subtitle: Text(state.settings.profileBio.isEmpty ? 'Personal information and preferences' : state.settings.profileBio),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: const ProfileScreen()))),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Appearance section
        const _SectionLabel('Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<AppThemeMode>(
                  segments: AppThemeMode.values
                      .map(
                        (mode) => ButtonSegment<AppThemeMode>(
                          value: mode,
                          label: Text(_themeModeLabel(mode)),
                          icon: Icon(_themeModeIcon(mode)),
                        ),
                      )
                      .toList(),
                  selected: {state.settings.themeMode},
                  onSelectionChanged: (selection) {
                    state.setThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _themeModeSubtitle(state.settings.themeMode),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        const _SectionLabel('Dashboard'),
        Card(
          child: Column(children: [
            _DashboardSwitch(label: 'Daily progress', value: state.settings.dashboardConfig.showDailyProgress, onChanged: (v) => _setDashboard(context, state, (c) => c.showDailyProgress = v)),
            _DashboardSwitch(label: 'Quick stats', value: state.settings.dashboardConfig.showQuickStats, onChanged: (v) => _setDashboard(context, state, (c) => c.showQuickStats = v)),
            _DashboardSwitch(label: 'Today habits', value: state.settings.dashboardConfig.showTodayHabits, onChanged: (v) => _setDashboard(context, state, (c) => c.showTodayHabits = v)),
            _DashboardSwitch(label: 'Tasks', value: state.settings.dashboardConfig.showTasks, onChanged: (v) => _setDashboard(context, state, (c) => c.showTasks = v)),
            _DashboardSwitch(label: 'Goal progress', value: state.settings.dashboardConfig.showGoalProgress, onChanged: (v) => _setDashboard(context, state, (c) => c.showGoalProgress = v)),
            _DashboardSwitch(label: 'Recent notes', value: state.settings.dashboardConfig.showRecentNotes, onChanged: (v) => _setDashboard(context, state, (c) => c.showRecentNotes = v)),
            _DashboardSwitch(label: 'Daily quote', value: state.settings.dashboardConfig.showDailyQuote, onChanged: (v) => _setDashboard(context, state, (c) => c.showDailyQuote = v)),
          ]),
        ),

        const SizedBox(height: AppSpacing.xl),

        const _SectionLabel('Notifications'),
        Card(
          child: ListTile(
            leading: Icon(Icons.notifications_active_outlined,
                color: theme.colorScheme.primary),
            title: const Text('Task & schedule notifications'),
            subtitle: const Text(
              'Get a reminder when a dated task or schedule item is due',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await state.requestNotificationPermission();
              state.initNotifications();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(granted
                      ? 'Notifications enabled.'
                      : 'Notifications are disabled. Enable them in system settings.'),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        const _SectionLabel('Privacy & Permissions'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Local-first privacy'),
            subtitle: Text(
              'Your data stays on this device. Storage access is requested only for files you choose to manage.',
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // About section
        const _SectionLabel('About'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                title: const Text('Yourself'),
                subtitle: const Text('Version 2.0.0+5'),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    Icon(Icons.code_outlined, color: theme.colorScheme.primary),
                title: const Text('Built with Flutter'),
                subtitle: const Text('Offline-only and privacy-focused'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.storage_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Local Storage'),
                subtitle: const Text('All data stays on your device'),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Data section
        const _SectionLabel('Data & Backup'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.download_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Export All Data'),
                subtitle:
                    const Text('Create a local JSON file to download or share'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Export Data')),
                        body: const ExportScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Text(
            'Made with care',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  void _setDashboard(BuildContext context, AppState state, void Function(DashboardConfig) change) {
    final current = state.settings.dashboardConfig;
    final updated = DashboardConfig.fromMap(current.toMap());
    change(updated);
    state.setDashboardConfig(updated);
  }

  String _themeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  IconData _themeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.settings_suggest_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  String _themeModeSubtitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Follow your device setting';
      case AppThemeMode.light:
        return 'Always light theme';
      case AppThemeMode.dark:
        return 'Always dark theme';
    }
  }
}

class _DashboardSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DashboardSwitch({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), title: Text(label), value: value, onChanged: onChanged);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
