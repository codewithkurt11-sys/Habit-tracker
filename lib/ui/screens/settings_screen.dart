import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/user_settings.dart';
import '../../core/theme/app_spacing.dart';
import 'export_screen.dart';
import 'friends_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),

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

        const _SectionLabel('Reminders'),
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

        // About section
        const _SectionLabel('About'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                title: const Text('Habit Tracker'),
                subtitle: const Text('Version 1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    Icon(Icons.code_outlined, color: theme.colorScheme.primary),
                title: const Text('Built with Flutter'),
                subtitle: const Text('Local-first, privacy-focused'),
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
        const _SectionLabel('Data Management'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.download_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Export All Data'),
                subtitle: const Text('Download a JSON backup'),
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

        // Cloud / Account section
        const _SectionLabel('Cloud & Friends'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.cloud_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Cloud Sync & Friends'),
                subtitle: const Text('Sign in, claim username, find friends'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Friends')),
                        body: const FriendsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

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
