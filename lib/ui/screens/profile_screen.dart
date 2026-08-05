import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final name = state.settings.userName ?? 'User';
    final memberSince = state.settings.memberSince;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(name, style: theme.textTheme.headlineSmall),
            if (memberSince != null)
              Text('Member since ${memberSince.year}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            // Stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              children: [
                _StatCard(
                  icon: Icons.local_fire_department,
                  label: 'Active Streaks',
                  value: '${state.totalCurrentStreaks}',
                  color: ext.categoryWorkout,
                ),
                _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Total Completions',
                  value: '${state.totalCompletions}',
                  color: ext.categoryLifestyle,
                ),
                _StatCard(
                  icon: Icons.emoji_events,
                  label: 'Goals Achieved',
                  value: '${state.goalsAchieved}',
                  color: const Color(0xFFE8B66F),
                ),
                _StatCard(
                  icon: Icons.repeat_rounded,
                  label: 'Total Habits',
                  value: '${state.totalHabits}',
                  color: ext.categoryOther,
                ),
                _StatCard(
                  icon: Icons.task_outlined,
                  label: 'Total Tasks',
                  value: '${state.totalTasks}',
                  color: ext.categoryLifestyle,
                ),
                _StatCard(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Notes Written',
                  value: '${state.totalNotes}',
                  color: ext.categoryOther,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Best streaks
            if (state.habits.isNotEmpty) ...[
              const SectionHeader(title: 'Best Streaks'),
              ...state.habits.map((h) {
                final best = h.bestStreak();
                final current = h.currentStreak();
                if (best == 0 && current == 0) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(h.icon, color: h.customColor ?? theme.colorScheme.primary),
                  title: Text(h.title),
                  subtitle: Text('Current: $current • Best: $best'),
                  trailing: Text('$best', style: theme.textTheme.headlineSmall?.copyWith(color: h.customColor ?? theme.colorScheme.primary)),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
