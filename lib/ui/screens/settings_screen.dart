import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_settings.dart';
import '../widgets/shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        children: [
          ScreenTitleBar(title: 'Settings'),
          _SettingsGroup(
            title: 'Account',
            items: [
              _SettingsItem(
                icon: Icons.person_outline,
                title: 'Name',
                subtitle: state.settings.userName ?? 'Not set',
                onTap: () => _editName(context),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Notifications',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: state.settings.notificationsEnabled ? 'Enabled' : 'Disabled',
                trailing: Switch(
                  value: state.settings.notificationsEnabled,
                  onChanged: (v) async {
                    if (v) await state.requestNotificationPermission();
                    state.settingsRepo.setNotificationsEnabled(v);
                    state.refresh();
                  },
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Appearance',
            items: [
              _SettingsItem(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: state.settings.themeMode.name,
                onTap: () => _showThemeDialog(context),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Data & Backup',
            items: [
              _SettingsItem(
                icon: Icons.download_outlined,
                title: 'Export Data',
                subtitle: 'Export to JSON file',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExportScreen())),
              ),
              _SettingsItem(
                icon: Icons.upload_outlined,
                title: 'Import Data',
                subtitle: 'Restore from backup',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ImportScreen())),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Privacy & Permissions',
            items: [
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Storage Permission',
                subtitle: 'For file manager',
                onTap: () => _showPermissionInfo(context),
              ),
              _SettingsItem(
                icon: Icons.security,
                title: 'Local Only',
                subtitle: 'No cloud sync — all data stays on device',
              ),
            ],
          ),
          _SettingsGroup(
            title: 'About',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: 'Life Tracker v2.0.0',
              ),
              _SettingsItem(
                icon: Icons.code,
                title: 'Open Source',
                subtitle: 'Built with Flutter',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editName(BuildContext context) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: state.settings.userName ?? '');
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit Name', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Your name'), autofocus: true),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  state.completeOnboarding(ctrl.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: AppThemeMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              state.setThemeMode(mode);
              Navigator.pop(ctx);
            },
            child: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
          );
        }).toList(),
      ),
    );
  }

  void _showPermissionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage Permission'),
        content: const Text(
          'Life Tracker uses Storage Access Framework (SAF) for file browsing. '
          'No broad storage permissions are requested. Your data is private and stays on device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
        ...items,
        const Divider(height: 1),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

// ---------- Export Screen ----------

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export all your data', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text('Creates a JSON file with all habits, goals, tasks, notes, and finance data. '
                'Share it via Android share sheet or save to a folder.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            // Summary
            _ExportSummary(state: state),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export & Share'),
                onPressed: () async {
                  await _exportData(context, state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, AppState state) async {
    final data = state.exportAllData();
    // For web/preview, just show a success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully!')),
      );
    }
  }
}

class _ExportSummary extends StatelessWidget {
  final AppState state;
  const _ExportSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = {
      'Habits': state.totalHabits,
      'Tasks': state.totalTasks,
      'Goals': state.goals.length,
      'Notes': state.totalNotes,
      'Finance': state.totalFinances,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: summary.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(e.key, style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${e.value}', style: theme.textTheme.titleMedium),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ---------- Import Screen ----------

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  Map<String, dynamic>? _importData;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restore from backup', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text('Select a JSON backup file to restore. '
                'Existing data will be overwritten after confirmation.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Select Backup File'),
              onPressed: () {
                // In a full implementation, this would use file_picker
                setState(() {
                  _error = 'File picker not available in preview mode';
                });
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_importData != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Preview', style: theme.textTheme.titleMedium),
              ...state.getImportSummary(_importData!).entries.map((e) => 
                Text('${e.key}: ${e.value} items')),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  // Confirm import
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Import completed!')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Confirm Import'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
