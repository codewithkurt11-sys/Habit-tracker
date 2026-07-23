import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../services/friends_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/heatmap_widget.dart';

/// Read-only view of a friend's Habits, Goals, Tasks, Schedule, and a combined
/// activity heatmap. All data is streamed from the friend's Firestore subcollections.
/// No edit controls — this is strictly a visibility feature.
class FriendProfileScreen extends StatelessWidget {
  final FriendProfile friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().friendsRepo;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(friend.username != null
              ? '@${friend.username}'
              : friend.displayName),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Remove friend',
              onPressed: () => _confirmRemove(context, repo),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                  icon: Icon(Icons.local_fire_department_outlined),
                  text: 'Heatmap'),
              Tab(icon: Icon(Icons.repeat_rounded), text: 'Habits'),
              Tab(icon: Icon(Icons.track_changes_outlined), text: 'Goals'),
              Tab(icon: Icon(Icons.check_circle_outline), text: 'Tasks'),
              Tab(icon: Icon(Icons.calendar_today_outlined), text: 'Schedule'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HeatmapTab(repo: repo, friendUid: friend.uid),
            _HabitsTab(repo: repo, friendUid: friend.uid),
            _GoalsTab(repo: repo, friendUid: friend.uid),
            _TasksTab(repo: repo, friendUid: friend.uid),
            _ScheduleTab(repo: repo, friendUid: friend.uid),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, FriendsRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content:
            Text('You will no longer see ${friend.displayName}\'s activity.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.removeFriend(friend.uid);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

// ==================== Heatmap tab ====================

class _HeatmapTab extends StatelessWidget {
  final FriendsRepository repo;
  final String friendUid;
  const _HeatmapTab({required this.repo, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Heatmap', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          // We need habits, tasks, and schedule streams to compute the heatmap.
          // Combine them with a StreamBuilder for each.
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: repo.friendDataStream(friendUid, 'habits'),
            builder: (context, habitsSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.friendDataStream(friendUid, 'tasks'),
                builder: (context, tasksSnap) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: repo.friendDataStream(friendUid, 'schedule'),
                    builder: (context, schedSnap) {
                      final habits = habitsSnap.data ?? [];
                      final tasks = tasksSnap.data ?? [];
                      final schedule = schedSnap.data ?? [];

                      final activity = HeatmapEngine.computeFromCloud(
                        habits: habits,
                        tasks: tasks,
                        schedule: schedule,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HeatmapWidget(activity: activity),
                          const SizedBox(height: AppSpacing.lg),
                          _StatRow(
                            label: 'Habits',
                            value: habits.length,
                            icon: Icons.repeat_rounded,
                          ),
                          _StatRow(
                            label: 'Tasks completed',
                            value: tasks
                                .where((t) => t['completedAt'] != null)
                                .length,
                            icon: Icons.check_circle_outline,
                          ),
                          _StatRow(
                            label: 'Schedule items done',
                            value:
                                schedule.where((s) => s['done'] == true).length,
                            icon: Icons.calendar_today_outlined,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==================== Habits tab ====================

class _HabitsTab extends StatelessWidget {
  final FriendsRepository repo;
  final String friendUid;
  const _HabitsTab({required this.repo, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.friendDataStream(friendUid, 'habits'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final habits = snapshot.data ?? [];
        if (habits.isEmpty) {
          return const _EmptyState(text: 'No habits visible.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: habits.length,
          itemBuilder: (context, index) {
            final h = habits[index];
            final name = (h['name'] as String?) ?? 'Unnamed';
            final log = (h['completionLog'] as List?) ?? [];
            final streak = _computeStreak(log.cast());
            return Card(
              child: ListTile(
                leading: Icon(Icons.repeat_rounded,
                    color: theme.colorScheme.primary),
                title: Text(name),
                subtitle:
                    Text('${log.length} completions  |  Streak: $streak days'),
              ),
            );
          },
        );
      },
    );
  }

  int _computeStreak(List<dynamic> log) {
    if (log.isEmpty) return 0;
    final dates = log
        .map((s) {
          if (s is Timestamp) return s.toDate();
          return DateTime.tryParse(s.toString());
        })
        .whereType<DateTime>()
        .toSet();
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
    final dayKeys = dates.map(dayKey).toSet();
    int streak = 0;
    var cursor = dayKey(DateTime.now());
    while (dayKeys.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

// ==================== Goals tab ====================

class _GoalsTab extends StatelessWidget {
  final FriendsRepository repo;
  final String friendUid;
  const _GoalsTab({required this.repo, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.friendDataStream(friendUid, 'goals'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final goals = (snapshot.data ?? [])
            .where((goal) => goal['archived'] != true)
            .toList();
        if (goals.isEmpty) {
          return const _EmptyState(text: 'No goals visible.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final g = goals[index];
            final title = (g['title'] as String?) ?? 'Untitled';
            final target = (g['targetValue'] as num?)?.toDouble() ?? 100;
            final current = (g['currentValue'] as num?)?.toDouble() ?? 0;
            final pct =
                target > 0 ? (current / target * 100).clamp(0, 100) : 0.0;
            final milestonesDone =
                (g['milestoneDone'] as List?)?.where((d) => d == true).length ??
                    0;
            final milestonesTotal =
                (g['milestoneTitles'] as List?)?.length ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(value: pct / 100),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                        '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                        style: theme.textTheme.bodySmall),
                    if (milestonesTotal > 0)
                      Text('Milestones: $milestonesDone / $milestonesTotal',
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== Tasks tab ====================

class _TasksTab extends StatelessWidget {
  final FriendsRepository repo;
  final String friendUid;
  const _TasksTab({required this.repo, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.friendDataStream(friendUid, 'tasks'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = List<Map<String, dynamic>>.from(snapshot.data ?? [])
          ..sort((a, b) {
            final aDate = _parseDate(a['completedAt']) ??
                _parseDate(a['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = _parseDate(b['completedAt']) ??
                _parseDate(b['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        final recentTasks = tasks.take(20).toList();
        if (recentTasks.isEmpty) {
          return const _EmptyState(text: 'No tasks visible.');
        }
        const statusLabels = ['Todo', 'In Progress', 'Done', 'Archived'];
        const statusIcons = [
          Icons.radio_button_unchecked,
          Icons.play_circle_outline,
          Icons.check_circle,
          Icons.archive_outlined,
        ];
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: recentTasks.length,
          itemBuilder: (context, index) {
            final t = recentTasks[index];
            final title = (t['title'] as String?) ?? 'Untitled';
            final statusIdx = (t['status'] as int?) ?? 0;
            final statusLabel = statusIdx < statusLabels.length
                ? statusLabels[statusIdx]
                : 'Unknown';
            final statusIcon = statusIdx < statusIcons.length
                ? statusIcons[statusIdx]
                : Icons.help_outline;
            return Card(
              child: ListTile(
                leading: Icon(statusIcon, color: theme.colorScheme.primary),
                title: Text(title),
                subtitle: Text(statusLabel),
                trailing: t['archived'] == true
                    ? const Chip(
                        label: Text('Archived', style: TextStyle(fontSize: 10)))
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

// ==================== Schedule tab ====================

class _ScheduleTab extends StatelessWidget {
  final FriendsRepository repo;
  final String friendUid;
  const _ScheduleTab({required this.repo, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.friendDataStream(friendUid, 'schedule'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final items = (snapshot.data ?? []).where((item) {
          final date = _parseDate(item['dateTime']);
          return date != null && !date.isBefore(now);
        }).toList();
        if (items.isEmpty) {
          return const _EmptyState(text: 'No upcoming schedule items.');
        }
        // Sort upcoming items by dateTime ascending.
        items.sort((a, b) {
          final aDt = _parseDate(a['dateTime']);
          final bDt = _parseDate(b['dateTime']);
          if (aDt == null && bDt == null) return 0;
          if (aDt == null) return 1;
          if (bDt == null) return -1;
          return aDt.compareTo(bDt);
        });
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final s = items[index];
            final title = (s['title'] as String?) ?? 'Untitled';
            final done = (s['done'] as bool?) ?? false;
            final dt = _parseDate(s['dateTime']);
            final dtStr = dt != null
                ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                : '';
            return Card(
              child: ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  color: done ? Colors.green : theme.colorScheme.primary,
                ),
                title: Text(title,
                    style: done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough)
                        : null),
                subtitle: Text(dtStr),
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

// ==================== Shared widgets ====================

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text('$value', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
