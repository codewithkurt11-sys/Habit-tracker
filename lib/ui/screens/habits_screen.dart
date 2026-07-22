import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/habit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final habits = state.habitsRepo.getDueToday();
    final today = DateTime.now();
    final dateStr = '${today.month}/${today.day}/${today.year}'; // ignore: unused_local_variable

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Habits',
              subtitle: '${habits.length} due today',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: habits.isEmpty
                  ? const EmptyState(
                      icon: Icons.repeat_rounded,
                      title: 'No habits for today',
                      subtitle: 'Create your first habit to start tracking',
                      actionLabel: 'Add Habit',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          bottom: AppSpacing.xxl),
                      itemCount: habits.length,
                      itemBuilder: (_, i) =>
                          _HabitTile(habit: habits[i]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddHabitDialog(),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final Habit habit;
  const _HabitTile({required this.habit});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final done = habit.isCompletedOn(DateTime.now());
    final streak = habit.currentStreak();
    final color = habit.customColor ?? _categoryColor(habit.category);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      child: Card(
        child: InkWell(
          onTap: () => state.toggleHabit(habit.id),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Icon(habit.icon.data, color: color, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: done
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)
                                  : null)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (streak > 0)
                            PillChip(
                              label: '$streak day streak',
                              icon: Icons.local_fire_department_outlined,
                              color: AppColors.lightAccent,
                            )
                          else
                            PillChip(
                              label: habit.frequency.name,
                              color: color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done ? color : Colors.transparent,
                    border: Border.all(
                        color: color, width: 2),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: done
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(HabitCategory cat) {
    switch (cat) {
      case HabitCategory.workout:
        return AppColors.categoryWorkout;
      case HabitCategory.lifestyle:
        return AppColors.categoryLifestyle;
      case HabitCategory.other:
        return AppColors.categoryOther;
    }
  }
}

class _AddHabitDialog extends StatefulWidget {
  const _AddHabitDialog();

  @override
  State<_AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<_AddHabitDialog> {
  final _nameController = TextEditingController();
  int _categoryIndex = 0;
  int _frequencyIndex = 0;
  int _iconIndex = 0;
  int _colorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                hintText: 'e.g. Drink 8 glasses of water',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            // Category
            _buildSegmentedControl(
              'Category',
              ['Workout', 'Lifestyle', 'Other'],
              _categoryIndex,
              (i) => setState(() => _categoryIndex = i),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Frequency
            _buildSegmentedControl(
              'Frequency',
              ['Daily', 'Weekly', 'Custom'],
              _frequencyIndex,
              (i) => setState(() => _frequencyIndex = i),
            ),
            const SizedBox(height: AppSpacing.md),
            // Icon picker
            Text('Icon', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(HabitIcon.values.length, (i) {
                final sel = i == _iconIndex;
                return GestureDetector(
                  onTap: () => setState(() => _iconIndex = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.colorScheme.primary
                          : theme.extension<AppThemeExtension>()!
                              .surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      HabitIcon.values[i].data,
                      size: 20,
                      color: sel
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            // Color picker
            Text('Color', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(AppColors.habitColorPalette.length, (i) {
                final sel = i == _colorIndex;
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.habitColorPalette[i],
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            context.read<AppState>().addHabit(
                  name: name,
                  categoryIndex: _categoryIndex,
                  frequencyIndex: _frequencyIndex,
                  iconIndex: _iconIndex,
                  colorValue:
                      AppColors.habitColorPalette[_colorIndex].toARGB32(),
                );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(
    String label,
    List<String> options,
    int selected,
    ValueChanged<int> onChanged,
  ) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          children: List.generate(options.length, (i) {
            final sel = i == selected;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? theme.colorScheme.primary
                      : ext.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    color: sel
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
