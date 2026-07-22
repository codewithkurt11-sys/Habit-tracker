import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/user_settings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),

        // Appearance section
        _SectionLabel('Appearance'),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < AppThemeMode.values.length; i++)
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.values[i],
                  groupValue: state.settings.themeMode,
                  onChanged: (mode) {
                    if (mode != null) state.setThemeMode(mode);
                  },
                  title: Text(_themeModeLabel(AppThemeMode.values[i])),
                  subtitle: Text(_themeModeSubtitle(AppThemeMode.values[i])),
                  activeColor: theme.colorScheme.primary,
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // About section
        _SectionLabel('About'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                title: const Text('Habit Tracker'),
                subtitle: const Text('Version 1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.code_outlined, color: theme.colorScheme.primary),
                title: const Text('Built with Flutter'),
                subtitle: const Text('Local-first, privacy-focused'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.storage_outlined, color: theme.colorScheme.primary),
                title: const Text('Local Storage'),
                subtitle: const Text('All data stays on your device'),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Data section
        _SectionLabel('Data Management'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.download_outlined, color: theme.colorScheme.primary),
                title: const Text('Export All Data'),
                subtitle: const Text('Download a JSON backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Export Data')),
                        body: const _ExportInfo(),
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
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
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

class _ExportInfo extends StatelessWidget {
  const _ExportInfo();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_outlined, size: 64),
            SizedBox(height: AppSpacing.md),
            Text('Use the Export Data option in the sidebar',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
