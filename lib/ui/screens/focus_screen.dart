import 'dart:async';
import 'package:flutter/services.dart';
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Start focus timer',
        onPressed: () => showFocusTimerDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Focus',
              subtitle: '$pomodorosToday pomodoros today',
              onMenuTap: null,
            ),
            _FocusStats(
              todayMinutes: todayMinutes,
              weekMinutes: weekMinutes,
              pomodoros: pomodorosToday,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: sessions.isEmpty
                  ? EmptyState(
                      icon: Icons.timer_outlined,
                      title: 'No focus sessions yet',
                      subtitle: 'Start a timer to begin focusing',
                      actionLabel: 'Start Timer',
                      onAction: () => showFocusTimerDialog(context),
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
    );
  }
}

void showFocusTimerDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _FocusTimerDialog(),
  );
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
            Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
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
                    color: (session.completed
                            ? const Color(0xFF6B9080)
                            : const Color(0xFFB8AEA4))
                        .withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Icon(
                    session.completed
                        ? Icons.check_circle
                        : Icons.timer_outlined,
                    color: session.completed
                        ? const Color(0xFF6B9080)
                        : const Color(0xFFB8AEA4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.type.label,
                          style: theme.textTheme.titleSmall),
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
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
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
  int _typeIndex = FocusType.pomodoro.index;
  int _durationSeconds = FocusType.pomodoro.defaultSeconds;
  int _remainingSeconds = FocusType.pomodoro.defaultSeconds;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _running = false;
  bool _saving = false;
  bool _sound = true;
  bool _vibration = true;
  final _taskController = TextEditingController();

  bool get _isStopwatch => FocusType.values[_typeIndex] == FocusType.stopwatch;

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _start() {
    if (_running || _saving) return;
    if (!_isStopwatch && _remainingSeconds <= 0) {
      _resetTimer();
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isStopwatch) {
          _elapsedSeconds++;
        } else if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _elapsedSeconds = _durationSeconds - _remainingSeconds;
        }
      });
      if (!_isStopwatch && _remainingSeconds <= 0) {
        _timer?.cancel();
        setState(() => _running = false);
        _finish(completed: true);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _running = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _elapsedSeconds = 0;
      _remainingSeconds = _durationSeconds;
    });
  }

  Future<void> _finish({bool completed = false}) async {
    if (_saving) return;
    _timer?.cancel();
    final elapsed = _isStopwatch ? _elapsedSeconds : (_durationSeconds - _remainingSeconds);
    if (elapsed <= 0) {
      if (mounted && !completed) Navigator.pop(context);
      return;
    }
    setState(() {
      _running = false;
      _saving = true;
    });
    if (_sound) await SystemSound.play(SystemSoundType.alert);
    if (_vibration) await HapticFeedback.mediumImpact();

    final taskTitle = _taskController.text.trim();
    await context.read<AppState>().saveFocusSession(
          typeIndex: _typeIndex,
          durationSeconds: _isStopwatch ? elapsed : _durationSeconds,
          completedSeconds: elapsed,
          taskTitle: taskTitle.isEmpty ? null : taskTitle,
        );
    if (!mounted) return;
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
    if (_running || _saving) return;
    final type = FocusType.values[index];
    setState(() {
      _typeIndex = index;
      _durationSeconds = type.defaultSeconds;
      _remainingSeconds = _durationSeconds;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _setCustomCountdown() async {
    if (_running || _saving) return;
    final controller = TextEditingController(text: '${(_durationSeconds / 60).round()}');
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Countdown duration'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes', suffixText: 'min'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1 && value <= 24 * 60) Navigator.pop(context, value);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || !mounted) return;
    setState(() {
      _durationSeconds = minutes * 60;
      _remainingSeconds = _durationSeconds;
      _elapsedSeconds = 0;
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final selected = FocusType.values[_typeIndex];
    final displaySeconds = _isStopwatch ? _elapsedSeconds : _remainingSeconds;
    return AlertDialog(
      title: const Text('Focus Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(FocusType.values.length, (i) {
                final sel = i == _typeIndex;
                return ChoiceChip(
                  label: Text(FocusType.values[i].label),
                  selected: sel,
                  onSelected: (_) => _selectType(i),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            if (selected == FocusType.countdown && !_running)
              TextButton.icon(
                onPressed: _setCustomCountdown,
                icon: const Icon(Icons.tune),
                label: Text('Duration: ${(_durationSeconds / 60).round()} min'),
              ),
            if (selected == FocusType.pomodoro || selected == FocusType.shortBreak || selected == FocusType.longBreak)
              Wrap(
                spacing: 6,
                children: [15, 25, 45, 60].map((m) => ActionChip(
                  label: Text('${m}m'),
                  onPressed: _running ? null : () => setState(() {
                    _durationSeconds = m * 60;
                    _remainingSeconds = _durationSeconds;
                    _elapsedSeconds = 0;
                  }),
                )).toList(),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _formatTime(displaySeconds),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'What are you working on? (optional)',
                isDense: true,
              ),
              enabled: !_running,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound on completion'),
              value: _sound,
              onChanged: _running ? null : (v) => setState(() => _sound = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibrate on completion'),
              value: _vibration,
              onChanged: _running ? null : (v) => setState(() => _vibration = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_running)
                  ElevatedButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                IconButton(
                  tooltip: 'Reset',
                  onPressed: _saving ? null : _resetTimer,
                  icon: const Icon(Icons.restart_alt),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : () => _finish(),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Save'),
                ),
              ],
            ),
            if (selected == FocusType.stopwatch)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Stopwatch records the actual elapsed time.', style: theme.textTheme.bodySmall),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('A session counts as completed after at least 80% of its planned time.', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () {
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('Close without saving'),
        ),
      ],
    );
  }
}
