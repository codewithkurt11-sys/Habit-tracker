import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/focus_session.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sessions = state.focusRepo.getAll()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final todayMinutes = state.focusRepo.getTotalFocusMinutesToday();
    final weekMinutes = state.focusRepo.getTotalFocusMinutesThisWeek();
    final pomodorosToday = state.focusRepo.getCompletedPomodorosToday();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Focus',
              subtitle: '${pomodorosToday} pomodoros today',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            _FocusStats(
              todayMinutes: todayMinutes,
              weekMinutes: weekMinutes,
              pomodoros: pomodorosToday,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: sessions.isEmpty
                  ? const EmptyState(
                      icon: Icons.timer_outlined,
                      title: 'No focus sessions yet',
                      subtitle: 'Start a timer to begin focusing',
                      actionLabel: 'Start Timer',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: sessions.length,
                      itemBuilder: (_, i) => _SessionTile(session: sessions[i]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _FocusTimerDialog(),
        ),
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}

class _FocusStats extends StatelessWidget {
  final int todayMinutes;
  final int weekMinutes;
  final int pomodoros;

  const _FocusStats({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.pomodoros,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Today',
              value: '${todayMinutes}m',
              icon: Icons.today,
              color: ext.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'This Week',
              value: '${weekMinutes}m',
              icon: Icons.date_range,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Pomodoros',
              value: '$pomodoros',
              icon: Icons.local_fire_department_outlined,
              color: const Color(0xFFE8946F),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final FocusSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final minutes = (session.completedSeconds ~/ 60);
    final seconds = session.completedSeconds % 60;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteFocus(session.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (session.completed ? const Color(0xFF6B9080) : const Color(0xFFB8AEA4))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Icon(
                    session.completed ? Icons.check_circle : Icons.timer_outlined,
                    color: session.completed ? const Color(0xFF6B9080) : const Color(0xFFB8AEA4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.type.label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${session.startedAt.month}/${session.startedAt.day} '
                        '${session.startedAt.hour.toString().padLeft(2, '0')}:'
                        '${session.startedAt.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusTimerDialog extends StatefulWidget {
  const _FocusTimerDialog();

  @override
  State<_FocusTimerDialog> createState() => _FocusTimerDialogState();
}

class _FocusTimerDialogState extends State<_FocusTimerDialog> {
  int _typeIndex = 0; // Pomodoro
  int _durationSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  Timer? _timer;
  bool _running = false;
  final _taskController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stop(completed: true);
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _stop({bool completed = false}) {
    _timer?.cancel();
    setState(() => _running = false);
    final elapsed = _durationSeconds - _remainingSeconds;
    if (elapsed > 0) {
      context.read<AppState>().saveFocusSession(
            typeIndex: _typeIndex,
            durationSeconds: _durationSeconds,
            completedSeconds: elapsed,
            taskTitle: _taskController.text.trim().isEmpty ? null : _taskController.text.trim(),
          );
    }
    if (completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${FocusType.values[_typeIndex].label} complete!'),
          backgroundColor: Theme.of(context).extension<AppThemeExtension>()!.success,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _selectType(int index) {
    if (_running) return;
    setState(() {
      _typeIndex = index;
      _durationSeconds = FocusType.values[index].defaultSeconds;
      _remainingSeconds = _durationSeconds;
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return AlertDialog(
      title: const Text('Focus Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type selector
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(FocusType.values.length, (i) {
                final sel = i == _typeIndex;
                return GestureDetector(
                  onTap: () => _selectType(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? theme.colorScheme.primary : ext.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text(FocusType.values[i].label,
                        style: TextStyle(
                          color: sel ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600, fontSize: 12,
                        )),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Timer display
            Text(
              _formatTime(_remainingSeconds),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Task title
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'What are you working on? (optional)',
                isDense: true,
              ),
              enabled: !_running,
            ),
            const SizedBox(height: AppSpacing.md),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_running)
                  ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                TextButton.icon(
                  onPressed: () => _stop(),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Save'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
