import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/models/goal.dart';
import '../data/models/schedule_item.dart';

/// One-way mirror outward (device -> cloud) of the signed-in user's own data,
/// and reconciliation on reconnect/sign-in for multi-device last-write-wins.
///
/// Local Hive is ALWAYS the source of truth for the signed-in user's own data.
/// A failed cloud push must never roll back or block the local Hive write.
class SyncService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<User?>? _authSub;
  bool _isReconciling = false;

  SyncService() {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    _connSub =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    // Check initial connectivity.
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _onConnectivityChanged(result);
    } catch (e) {
      // connectivity_plus may throw on some platforms; treat as offline.
      _isOnline = false;
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final wasOnline = _isOnline;
    _isOnline = result.any((r) => r != ConnectivityResult.none);
    if (_isOnline && !wasOnline) {
      // Offline -> online transition: reconcile.
      _reconcile();
    }
    notifyListeners();
  }

  void _onAuthChanged(User? user) {
    if (user != null && _isOnline) {
      // Reconcile on sign-in.
      _reconcile();
    }
  }

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference _collection(String type) =>
      _db.collection('users').doc(_uid!).collection(type);

  // ===================== Push (fire-and-forget) =====================

  /// Push a single record. Best effort — failures are only logged.
  Future<void> pushRecord(
      String type, String id, Map<String, dynamic> data) async {
    if (_uid == null || !_isOnline) return; // no-op while offline/signed-out
    try {
      await _collection(type).doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.pushRecord($type) error: $e');
    }
  }

  /// Propagate a delete to the cloud. Failures are only logged.
  Future<void> pushDelete(String type, String id) async {
    if (_uid == null || !_isOnline) return;
    try {
      await _collection(type).doc(id).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.pushDelete($type) error: $e');
    }
  }

  // ===================== Serialization =====================

  Map<String, dynamic> habitToMap(Habit h) => {
        'id': h.id,
        'name': h.name,
        'category': h.category.index,
        'frequency': h.frequency.index,
        'customDays': h.customDays,
        'completionLog':
            h.completionLog.map((d) => d.toIso8601String()).toList(),
        'createdAt': h.createdAt.toIso8601String(),
        'iconIndex': h.iconIndex,
        'colorValue': h.colorValue,
        'targetStreak': h.targetStreak,
        'updatedAt': h.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> taskToMap(Task t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'priority': t.priority.index,
        'status': t.status.index,
        'category': t.category.index,
        'dueDate': t.dueDate?.toIso8601String(),
        'dueTime': t.dueTime?.toIso8601String(),
        'tags': t.tags,
        'subtaskTitles': t.subtaskTitles,
        'subtaskDone': t.subtaskDone,
        'isRecurring': t.isRecurring,
        'recurringPattern': t.recurringPattern,
        'createdAt': t.createdAt.toIso8601String(),
        'completedAt': t.completedAt?.toIso8601String(),
        'archived': t.archived,
        'updatedAt': t.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> goalToMap(Goal g) => {
        'id': g.id,
        'title': g.title,
        'description': g.description,
        'categoryIndex': g.categoryIndex,
        'deadline': g.deadline?.toIso8601String(),
        'targetValue': g.targetValue,
        'currentValue': g.currentValue,
        'milestoneIds': g.milestoneIds,
        'milestoneTitles': g.milestoneTitles,
        'milestoneDone': g.milestoneDone,
        'milestoneDates':
            g.milestoneDates.map((d) => d?.toIso8601String()).toList(),
        'completed': g.completed,
        'archived': g.archived,
        'colorValue': g.colorValue,
        'createdAt': g.createdAt.toIso8601String(),
        'updatedAt': g.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> scheduleToMap(ScheduleItem s) => {
        'id': s.id,
        'title': s.title,
        'dateTime': s.dateTime.toIso8601String(),
        'done': s.done,
        'updatedAt': s.updatedAt.toIso8601String(),
      };

  // ===================== Reconciliation =====================

  /// Push ALL current local records for the four syncable types in a single
  /// Firestore WriteBatch (capped at 500 writes — chunked if needed).
  /// Required because per-mutation fire-and-forget pushes silently no-op
  /// while offline/signed-out.
  ///
  /// Multi-device conflict: for each record ID present both locally and in the
  /// cloud, keep whichever has the newer `updatedAt`; pull down cloud-only
  /// records; push up local-only records. The pull-down part is reported via
  /// the returned callbacks so AppState can merge cloud records into Hive.
  Future<void> reconcile({
    required List<Habit> localHabits,
    required List<Task> localTasks,
    required List<Goal> localGoals,
    required List<ScheduleItem> localSchedule,
    required void Function(Habit) onHabitFromCloud,
    required void Function(Task) onTaskFromCloud,
    required void Function(Goal) onGoalFromCloud,
    required void Function(ScheduleItem) onScheduleFromCloud,
  }) async {
    await _reconcileWith(
      localHabits: localHabits,
      localTasks: localTasks,
      localGoals: localGoals,
      localSchedule: localSchedule,
      onHabitFromCloud: onHabitFromCloud,
      onTaskFromCloud: onTaskFromCloud,
      onGoalFromCloud: onGoalFromCloud,
      onScheduleFromCloud: onScheduleFromCloud,
    );
  }

  Future<void> _reconcileWith({
    required List<Habit> localHabits,
    required List<Task> localTasks,
    required List<Goal> localGoals,
    required List<ScheduleItem> localSchedule,
    required void Function(Habit) onHabitFromCloud,
    required void Function(Task) onTaskFromCloud,
    required void Function(Goal) onGoalFromCloud,
    required void Function(ScheduleItem) onScheduleFromCloud,
  }) async {
    if (_uid == null || !_isOnline) return;
    if (_isReconciling) return;
    _isReconciling = true;
    try {
      // Fetch all cloud docs for the four types (simple queries, no indexes).
      final cloudHabits = await _fetchAll('habits');
      final cloudTasks = await _fetchAll('tasks');
      final cloudGoals = await _fetchAll('goals');
      final cloudSchedule = await _fetchAll('schedule');

      final batchWrites = <Map<String, dynamic>>[];
      void addWrite(String type, String id, Map<String, dynamic> data) =>
          batchWrites.add({'type': type, 'id': id, 'data': data});

      // --- Habits ---
      final localHabitMap = {for (final h in localHabits) h.id: h};
      for (final entry in cloudHabits.entries) {
        final id = entry.key;
        final cloudUpdated = _parseDate(entry.value['updatedAt']);
        final local = localHabitMap[id];
        if (local == null) {
          // cloud-only -> pull down
          onHabitFromCloud(_habitFromCloud(entry.value));
        } else if (cloudUpdated != null &&
            cloudUpdated.isAfter(local.updatedAt)) {
          // cloud newer -> pull down
          onHabitFromCloud(_habitFromCloud(entry.value));
        } else {
          // local newer or equal -> push up
          addWrite('habits', id, habitToMap(local));
        }
      }
      // local-only -> push up
      for (final h in localHabits) {
        if (!cloudHabits.containsKey(h.id)) {
          addWrite('habits', h.id, habitToMap(h));
        }
      }

      // --- Tasks ---
      final localTaskMap = {for (final t in localTasks) t.id: t};
      for (final entry in cloudTasks.entries) {
        final id = entry.key;
        final cloudUpdated = _parseDate(entry.value['updatedAt']);
        final local = localTaskMap[id];
        if (local == null) {
          onTaskFromCloud(_taskFromCloud(entry.value));
        } else if (cloudUpdated != null &&
            cloudUpdated.isAfter(local.updatedAt)) {
          onTaskFromCloud(_taskFromCloud(entry.value));
        } else {
          addWrite('tasks', id, taskToMap(local));
        }
      }
      for (final t in localTasks) {
        if (!cloudTasks.containsKey(t.id)) {
          addWrite('tasks', t.id, taskToMap(t));
        }
      }

      // --- Goals ---
      final localGoalMap = {for (final g in localGoals) g.id: g};
      for (final entry in cloudGoals.entries) {
        final id = entry.key;
        final cloudUpdated = _parseDate(entry.value['updatedAt']);
        final local = localGoalMap[id];
        if (local == null) {
          onGoalFromCloud(_goalFromCloud(entry.value));
        } else if (cloudUpdated != null &&
            cloudUpdated.isAfter(local.updatedAt)) {
          onGoalFromCloud(_goalFromCloud(entry.value));
        } else {
          addWrite('goals', id, goalToMap(local));
        }
      }
      for (final g in localGoals) {
        if (!cloudGoals.containsKey(g.id)) {
          addWrite('goals', g.id, goalToMap(g));
        }
      }

      // --- Schedule ---
      final localSchedMap = {for (final s in localSchedule) s.id: s};
      for (final entry in cloudSchedule.entries) {
        final id = entry.key;
        final cloudUpdated = _parseDate(entry.value['updatedAt']);
        final local = localSchedMap[id];
        if (local == null) {
          onScheduleFromCloud(_scheduleFromCloud(entry.value));
        } else if (cloudUpdated != null &&
            cloudUpdated.isAfter(local.updatedAt)) {
          onScheduleFromCloud(_scheduleFromCloud(entry.value));
        } else {
          addWrite('schedule', id, scheduleToMap(local));
        }
      }
      for (final s in localSchedule) {
        if (!cloudSchedule.containsKey(s.id)) {
          addWrite('schedule', s.id, scheduleToMap(s));
        }
      }

      // Push in chunked batches (500 writes max per batch).
      const chunkSize = 450;
      for (var i = 0; i < batchWrites.length; i += chunkSize) {
        final end = (i + chunkSize > batchWrites.length)
            ? batchWrites.length
            : i + chunkSize;
        final batch = _db.batch();
        for (var j = i; j < end; j++) {
          final w = batchWrites[j];
          batch.set(
            _collection(w['type'] as String).doc(w['id'] as String),
            w['data'] as Map<String, dynamic>,
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.reconcile error: $e');
    } finally {
      _isReconciling = false;
    }
  }

  Future<void> _reconcile() async {
    // The actual reconcile is driven by AppState which holds the local data.
    // AppState listens to SyncService and calls reconcile() with local lists.
    // We just notify so AppState can trigger.
    notifyListeners();
  }

  /// AppState should call this when it wants a reconcile pass.
  bool get shouldReconcile => _uid != null && _isOnline && !_isReconciling;

  Future<Map<String, Map<String, dynamic>>> _fetchAll(String type) async {
    try {
      final snap = await _collection(type).get();
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        result[doc.id] = doc.data() as Map<String, dynamic>;
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService._fetchAll($type) error: $e');
      return {};
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ===================== Deserialization (cloud -> local model) =====================

  Habit _habitFromCloud(Map<String, dynamic> d) => Habit(
        id: d['id'] as String,
        name: d['name'] as String,
        category: HabitCategory.values[(d['category'] as int?) ?? 0],
        frequency: HabitFrequency.values[(d['frequency'] as int?) ?? 0],
        customDays: ((d['customDays'] as List?) ?? []).cast<int>(),
        completionLog: ((d['completionLog'] as List?) ?? [])
            .map((s) => DateTime.tryParse(s as String) ?? DateTime.now())
            .toList(),
        createdAt: _parseDate(d['createdAt']) ?? DateTime.now(),
        iconIndex: (d['iconIndex'] as int?) ?? 15,
        colorValue: d['colorValue'] as int?,
        targetStreak: (d['targetStreak'] as int?) ?? 0,
        updatedAt: _parseDate(d['updatedAt']) ?? DateTime.now(),
      );

  Task _taskFromCloud(Map<String, dynamic> d) => Task(
        id: d['id'] as String,
        title: d['title'] as String,
        description: (d['description'] as String?) ?? '',
        priority: TaskPriority.values[(d['priority'] as int?) ?? 1],
        status: TaskStatus.values[(d['status'] as int?) ?? 0],
        category: TaskCategory.values[(d['category'] as int?) ?? 7],
        dueDate: _parseDate(d['dueDate']),
        dueTime: _parseDate(d['dueTime']),
        tags: ((d['tags'] as List?) ?? []).cast<String>(),
        subtaskTitles: ((d['subtaskTitles'] as List?) ?? []).cast<String>(),
        subtaskDone: ((d['subtaskDone'] as List?) ?? []).cast<bool>(),
        isRecurring: (d['isRecurring'] as bool?) ?? false,
        recurringPattern: (d['recurringPattern'] as String?) ?? '',
        createdAt: _parseDate(d['createdAt']) ?? DateTime.now(),
        completedAt: _parseDate(d['completedAt']),
        archived: (d['archived'] as bool?) ?? false,
        updatedAt: _parseDate(d['updatedAt']) ?? DateTime.now(),
      );

  Goal _goalFromCloud(Map<String, dynamic> d) => Goal(
        id: d['id'] as String,
        title: d['title'] as String,
        description: (d['description'] as String?) ?? '',
        categoryIndex: (d['categoryIndex'] as int?) ?? 6,
        deadline: _parseDate(d['deadline']),
        targetValue: (d['targetValue'] as num?)?.toDouble() ?? 100,
        currentValue: (d['currentValue'] as num?)?.toDouble() ?? 0,
        milestoneIds: ((d['milestoneIds'] as List?) ?? []).cast<String>(),
        milestoneTitles: ((d['milestoneTitles'] as List?) ?? []).cast<String>(),
        milestoneDone: ((d['milestoneDone'] as List?) ?? []).cast<bool>(),
        milestoneDates: ((d['milestoneDates'] as List?) ?? [])
            .map((s) => s == null ? null : DateTime.tryParse(s as String))
            .cast<DateTime?>()
            .toList(),
        completed: (d['completed'] as bool?) ?? false,
        archived: (d['archived'] as bool?) ?? false,
        colorValue: (d['colorValue'] as int?) ?? 0xFF6B9080,
        createdAt: _parseDate(d['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDate(d['updatedAt']) ?? DateTime.now(),
      );

  ScheduleItem _scheduleFromCloud(Map<String, dynamic> d) => ScheduleItem(
        id: d['id'] as String,
        title: d['title'] as String,
        dateTime: _parseDate(d['dateTime']) ?? DateTime.now(),
        done: (d['done'] as bool?) ?? false,
        updatedAt: _parseDate(d['updatedAt']) ?? DateTime.now(),
      );

  @override
  void dispose() {
    _connSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
