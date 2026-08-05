import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/habit.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/heatmap_widget.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final habits = state.habits;

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddHabitDialog(context),
          child: const Icon(Icons.add),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitleBar(
                title: 'Habits',
                subtitle: '${habits.length} total • ${state.totalCurrentStreaks} active streaks',
              ),
            ),
            if (habits.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.repeat_rounded,
                  title: 'No habits yet',
                  subtitle: 'Create your first habit to start tracking',
                  actionLabel: 'Add Habit',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final h = habits[index];
                    return _HabitCard(habit: h);
                  },
                  childCount: habits.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddHabitSheet(),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isDone = habit.isCompletedOn(DateTime.now());
    final color = habit.customColor ?? theme.colorScheme.primary;
    final streak = habit.currentStreak();
    final milestone = habit.checkMilestone();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await state.toggleHabit(habit.id);
                    showUndoToast(context, isDone ? 'Undone' : 'Habit completed',
                        () => state.toggleHabit(habit.id));
                  },
                  child: CompletionRing(completed: isDone, color: color, milestone: milestone),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.title, style: theme.textTheme.titleMedium),
                      Text(
                        '${habit.frequency.name} • ${streak} day streak • ${habit.consistencyScore}% consistent',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(habit.icon, color: color, size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet();

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  HabitFrequency _frequency = HabitFrequency.daily;
  List<int> _customDays = [];
  TimeOfDay? _reminderTime;
  int _iconIndex = 0;
  int _selectedColorIndex = 0;
  String? _linkedGoalId;

  static const _colors = [
    Color(0xFFE8946F), Color(0xFF6B9080), Color(0xFF7B93B5),
    Color(0xFFC4A895), Color(0xFFB58BB5), Color(0xFF8FC0A0),
    Color(0xFFE8B66F), Color(0xFFD67474),
  ];

  static const _icons = [
    Icons.fitness_center, Icons.menu_book, Icons.water_drop, Icons.self_improvement,
    Icons.bedtime, Icons.restaurant, Icons.directions_walk, Icons.school,
    Icons.music_note, Icons.palette, Icons.code, Icons.favorite,
    Icons.savings, Icons.people, Icons.park, Icons.star,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final goals = state.activeGoals;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Habit', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Habit title'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            // Frequency
            Text('Frequency', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: HabitFrequency.values.map((f) {
                return ChoiceChip(
                  label: Text(f.name),
                  selected: _frequency == f,
                  onSelected: (selected) {
                    if (selected) setState(() => _frequency = f);
                  },
                );
              }).toList(),
            ),
            if (_frequency == HabitFrequency.custom) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return FilterChip(
                    label: Text(labels[i]),
                    selected: _customDays.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _customDays.add(day);
                        } else {
                          _customDays.remove(day);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // Reminder time
            Row(
              children: [
                Text('Reminder', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) setState(() => _reminderTime = time);
                  },
                  child: Text(_reminderTime != null
                      ? '${_reminderTime!.hour}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                      : 'None'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Link to goal
            if (goals.isNotEmpty) ...[
              Text('Link to Goal', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              DropdownButton<String?>(
                value: _linkedGoalId,
                hint: const Text('None'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...goals.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.title),
                  )),
                ],
                onChanged: (v) => setState(() => _linkedGoalId = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Color
            Text('Color', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: List.generate(_colors.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = i),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      shape: BoxShape.circle,
                      border: _selectedColorIndex == i
                          ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            // Icon
            Text('Icon', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: List.generate(_icons.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _iconIndex = i),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _iconIndex == i
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _iconIndex == i
                          ? Border.all(color: theme.colorScheme.primary)
                          : null,
                    ),
                    child: Icon(_icons[i], size: 20,
                        color: _iconIndex == i ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_titleController.text.trim().isEmpty) return;
                  context.read<AppState>().addHabit(
                    title: _titleController.text.trim(),
                    description: _descController.text.trim(),
                    linkedGoalId: _linkedGoalId,
                    frequency: _frequency,
                    customDays: _frequency == HabitFrequency.custom ? _customDays : null,
                    reminderTime: _reminderTime != null
                        ? DateTime(2000, 1, 1, _reminderTime!.hour, _reminderTime!.minute)
                        : null,
                    iconIndex: _iconIndex,
                    colorValue: _colors[_selectedColorIndex].value,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Create Habit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
