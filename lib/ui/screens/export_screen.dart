import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    final habitsCount = state.habitsRepo.getAll().length;
    final tasksCount = state.tasksRepo.getAll(includeArchived: true).length;
    final goalsCount = state.goalsRepo.getAll(includeArchived: true).length;
    final journalCount = state.journalRepo.getAll().length;
    final notesCount = state.notesRepo.getAll().length;
    final financeCount = state.financeRepo.getAll().length;
    final focusCount = state.focusRepo.getAll().length;
    final scheduleCount = state.scheduleRepo.getAll().length;
    final quotesCount = state.quotesRepo.getAll().length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            ),
            child: Icon(Icons.download_outlined, size: 36, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Backup & Export', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text('Export your data as JSON or CSV', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),

        // Data summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data to be exported:', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                _ExportRow(icon: Icons.repeat_rounded, label: 'Habits', count: habitsCount, color: ext.categoryWorkout),
                _ExportRow(icon: Icons.check_circle_outline, label: 'Tasks', count: tasksCount, color: ext.categoryLifestyle),
                _ExportRow(icon: Icons.track_changes_outlined, label: 'Goals', count: goalsCount, color: ext.categoryOther),
                _ExportRow(icon: Icons.book_outlined, label: 'Journal', count: journalCount, color: const Color(0xFF7B93B5)),
                _ExportRow(icon: Icons.sticky_note_2_outlined, label: 'Notes', count: notesCount, color: const Color(0xFFE8C56F)),
                _ExportRow(icon: Icons.account_balance_wallet_outlined, label: 'Finance', count: financeCount, color: const Color(0xFF6B9080)),
                _ExportRow(icon: Icons.timer_outlined, label: 'Focus Sessions', count: focusCount, color: ext.success),
                _ExportRow(icon: Icons.calendar_today_outlined, label: 'Schedule', count: scheduleCount, color: const Color(0xFFB58BB5)),
                _ExportRow(icon: Icons.format_quote_outlined, label: 'Quotes', count: quotesCount, color: theme.colorScheme.primary),
                const Divider(),
                _ExportRow(icon: Icons.settings_outlined, label: 'Settings', count: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Export buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _exportJson(context),
            icon: const Icon(Icons.download),
            label: const Text('Export as JSON'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export Finance as CSV'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _exportHabitsCsv(context),
            icon: const Icon(Icons.repeat_rounded),
            label: const Text('Export Habits as CSV'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Import section
        const _SectionLabel('Import Data'),
        Card(
          child: ListTile(
            leading: Icon(Icons.upload_outlined, color: theme.colorScheme.primary),
            title: const Text('Import from JSON'),
            subtitle: const Text('Restore from a previous backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showImportInfo(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  void _exportJson(BuildContext context) async {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    try {
      final data = state.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now().toIso8601String().split('.').first;
      await Share.share(jsonString, subject: 'Habit Tracker Data Export — $timestamp');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Data exported successfully!'), backgroundColor: theme.extension<AppThemeExtension>()!.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  void _exportCsv(BuildContext context) async {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    try {
      final entries = state.financeRepo.getAll();
      final csv = StringBuffer();
      csv.writeln('Date,Title,Type,Category,Amount,Note');
      for (final e in entries) {
        csv.writeln('${e.date.toIso8601String().split('T').first},${_csvEscape(e.title)},${e.type.name},${e.categoryLabel},${e.amount},${_csvEscape(e.note)}');
      }
      await Share.share(csv.toString(), subject: 'Finance Export — ${DateTime.now().toIso8601String().split('T').first}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${entries.length} transactions as CSV'), backgroundColor: theme.extension<AppThemeExtension>()!.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: theme.colorScheme.error));
      }
    }
  }

  void _exportHabitsCsv(BuildContext context) async {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    try {
      final habits = state.habitsRepo.getAll();
      final csv = StringBuffer();
      csv.writeln('Name,Category,Frequency,Total Completions,Current Streak,Best Streak,Completion Rate (30d),Created At');
      for (final h in habits) {
        csv.writeln('${_csvEscape(h.name)},${h.category.name},${h.frequency.name},${h.totalCompletions},${h.currentStreak()},${h.bestStreak()},${(h.completionRate() * 100).toStringAsFixed(1)}%,${h.createdAt.toIso8601String().split('T').first}');
      }
      await Share.share(csv.toString(), subject: 'Habits Export — ${DateTime.now().toIso8601String().split('T').first}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${habits.length} habits as CSV'), backgroundColor: theme.extension<AppThemeExtension>()!.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: theme.colorScheme.error));
      }
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showImportInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('To import data, open your JSON backup file from a file manager and share it with this app. The app will detect and restore your data automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
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
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
    );
  }
}

class _ExportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _ExportRow({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text('$count', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
