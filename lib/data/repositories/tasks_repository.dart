import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/task.dart';

class TasksRepository {
  Box<Task> get _box => Hive.box<Task>(HiveBoxes.tasks);
  final _uuid = const Uuid();

  List<Task> getAll({bool includeArchived = false}) {
    final list =
        _box.values.where((t) => includeArchived || !t.archived).toList();
    list.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      final pCmp = b.priority.index.compareTo(a.priority.index);
      if (pCmp != 0) return pCmp;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Task> getActive() =>
      getAll().where((t) => t.status != TaskStatus.done).toList();

  List<Task> getDone() =>
      getAll().where((t) => t.status == TaskStatus.done).toList();

  List<Task> getForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return getAll().where((t) {
      if (t.dueDate == null) return false;
      final td = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return td.isAtSameMomentAs(d);
    }).toList();
  }

  List<Task> getOverdue() => getAll().where((t) => t.isOverdue).toList();

  List<Task> getDueToday() => getForDate(DateTime.now());

  Map<String, List<Task>> groupedByDueDate() {
    final groups = <String, List<Task>>{};
    for (final t in getAll()) {
      String key;
      if (t.dueDate == null) {
        key = 'No date';
      } else {
        final today = DateTime.now();
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        final todayNorm = DateTime(today.year, today.month, today.day);
        final diff = due.difference(todayNorm).inDays;
        if (diff < 0) {
          key = 'Overdue';
        } else if (diff == 0) {
          key = 'Today';
        } else if (diff == 1) {
          key = 'Tomorrow';
        } else if (diff <= 7) {
          key = 'This week';
        } else {
          key = 'Later';
        }
      }
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  Task? getById(String id) {
    try {
      return _box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Task> create({
    required String title,
    String description = '',
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.personal,
    DateTime? dueDate,
    DateTime? dueTime,
    List<String> tags = const [],
    List<String> subtaskTitles = const [],
    bool recurring = false,
    String recurrenceRule = '',
    String? linkedGoalId,
    String? linkedHabitId,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dueDate,
      dueTime: dueTime,
      tags: List.from(tags),
      subtaskTitles: List.from(subtaskTitles),
      subtaskDone: List.filled(subtaskTitles.length, false),
      recurring: recurring,
      recurrenceRule: recurrenceRule,
      linkedGoalId: linkedGoalId,
      linkedHabitId: linkedHabitId,
    );
    await _box.put(task.id, task);
    return task;
  }

  Future<void> update(Task task) async {
    task.touch();
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async => _box.delete(id);

  Future<void> toggleDone(Task task) async {
    if (task.status == TaskStatus.done) {
      task.status = TaskStatus.todo;
      task.completedAt = null;
    } else {
      task.status = TaskStatus.done;
      task.completedAt = DateTime.now();
      // Handle recurring tasks — create next instance
      if (task.recurring && task.recurrenceRule.isNotEmpty) {
        final next = _computeNextDueDate(task.dueDate, task.recurrenceRule);
        if (next != null) {
          final newTask = Task(
            id: _uuid.v4(),
            title: task.title,
            description: task.description,
            priority: task.priority,
            status: TaskStatus.todo,
            category: task.category,
            dueDate: next,
            dueTime: task.dueTime,
            tags: List.from(task.tags),
            recurring: true,
            recurrenceRule: task.recurrenceRule,
            linkedGoalId: task.linkedGoalId,
            linkedHabitId: task.linkedHabitId,
          );
          await _box.put(newTask.id, newTask);
        }
      }
    }
    task.touch();
    await _box.put(task.id, task);
  }

  DateTime? _computeNextDueDate(DateTime? current, String rule) {
    if (current == null) return null;
    switch (rule) {
      case 'daily':
        return DateTime(current.year, current.month, current.day + 1);
      case 'weekly':
        return DateTime(current.year, current.month, current.day + 7);
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'weekdays':
        final next = DateTime(current.year, current.month, current.day + 1);
        if (next.weekday >= 6) {
          return DateTime(current.year, current.month, current.day + (8 - current.weekday));
        }
        return next;
      default:
        return null;
    }
  }

  Future<void> toggleSubtask(Task task, int index) async {
    if (index < 0 || index >= task.subtaskDone.length) return;
    task.subtaskDone[index] = !task.subtaskDone[index];
    final allDone = task.subtaskDone.isNotEmpty &&
        task.subtaskDone.length >= task.subtaskTitles.length &&
        task.subtaskDone.take(task.subtaskTitles.length).every((done) => done);
    if (allDone) {
      task.status = TaskStatus.done;
      task.completedAt ??= DateTime.now();
    } else if (task.status == TaskStatus.done) {
      task.status = TaskStatus.todo;
      task.completedAt = null;
    }
    task.touch();
    await _box.put(task.id, task);
  }

  Future<void> archive(Task task) async {
    task.archived = true;
    task.touch();
    await _box.put(task.id, task);
  }
}
