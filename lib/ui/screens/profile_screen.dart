import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final name = state.settings.userName ?? 'User';

    final habitsCount = state.habitsRepo.getAll().length;
    final tasksCount = state.tasksRepo.getActive().length;
    final goalsCount = state.goalsRepo.getActive().length;
    final journalCount = state.journalRepo.getAll().length;
    final notesCount = state.notesRepo.getAll().length;
    final focusMinutes = state.focusRepo.getTotalFocusMinutesThisWeek();
    final financeEntries = state.financeRepo.getAll().length;
    final quotesCount = state.quotesRepo.getAll().length;
    final scheduleCount = state.scheduleRepo.getAll().length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),
        // Avatar + name
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Productivity OS', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Edit name button
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _showEditNameDialog(context, name),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Name'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Stats grid
        Text('Your Statistics', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              icon: Icons.repeat_rounded,
              label: 'Habits',
              value: '$habitsCount',
              color: ext.categoryWorkout,
            ),
            _StatCard(
              icon: Icons.check_circle_outline,
              label: 'Active Tasks',
              value: '$tasksCount',
              color: ext.categoryLifestyle,
            ),
            _StatCard(
              icon: Icons.track_changes_outlined,
              label: 'Active Goals',
              value: '$goalsCount',
              color: ext.categoryOther,
            ),
            _StatCard(
              icon: Icons.book_outlined,
              label: 'Journal Entries',
              value: '$journalCount',
              color: const Color(0xFF7B93B5),
            ),
            _StatCard(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              value: '$notesCount',
              color: const Color(0xFFE8C56F),
            ),
            _StatCard(
              icon: Icons.timer_outlined,
              label: 'Focus (this week)',
              value: '${focusMinutes}m',
              color: ext.success,
            ),
            _StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Transactions',
              value: '$financeEntries',
              color: const Color(0xFF6B9080),
            ),
            _StatCard(
              icon: Icons.calendar_today_outlined,
              label: 'Scheduled',
              value: '$scheduleCount',
              color: const Color(0xFFB58BB5),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Quotes count
        Card(
          child: ListTile(
            leading: Icon(Icons.format_quote_outlined,
                color: theme.colorScheme.primary),
            title:
                Text('Quotes in Collection', style: theme.textTheme.bodyLarge),
            trailing: Text('$quotesCount', style: theme.textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Your name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<AppState>().completeOnboarding(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
