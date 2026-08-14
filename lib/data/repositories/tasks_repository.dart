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
    bool isRecurring = false,
    String recurringPattern = '',
    String? goalId,
    String? habitId,
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
      isRecurring: isRecurring,
      recurringPattern: recurringPattern,
      goalId: goalId,
      habitId: habitId,
    );
    await _box.put(task.id, task);
    return task;
  }

  Future<void> update(Task task) async {
    task.touch();
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async => _box.delete(id);

  Future<void> markDone(Task task) async {
    task.status = TaskStatus.done;
    task.completedAt = DateTime.now();
    task.touch();
    await _box.put(task.id, task);
    if (task.isRecurring && task.recurringPattern.isNotEmpty) {
      await _generateNextOccurrence(task);
    }
  }

  /// Generates the next occurrence of a recurring task after [original]
  /// is completed. Prevents duplicates by checking if a task with the
  /// same title + due date already exists.
  Future<Task?> _generateNextOccurrence(Task original) async {
    final baseDate = original.dueDate ?? original.completedAt ?? DateTime.now();
    DateTime? nextDue;

    switch (original.recurringPattern.toLowerCase()) {
      case 'daily':
        nextDue = baseDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextDue = baseDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        // Handle month-end safely: if original day is 31 and next month
        // has 30 days, use the last day of the next month.
        final nextMonth = baseDate.month == 12
            ? DateTime(baseDate.year + 1, 1, 1)
            : DateTime(baseDate.year, baseDate.month + 1, 1);
        final lastDayNextMonth =
            DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        final targetDay = baseDate.day.clamp(1, lastDayNextMonth);
        nextDue = DateTime(nextMonth.year, nextMonth.month, targetDay);
        break;
      default:
        return null;
    }

    // Normalize to midnight
    nextDue = DateTime(nextDue.year, nextDue.month, nextDue.day);

    // Prevent duplicate: check ALL tasks (regardless of status or archived
    // state) for same title + dueDate. A completed/archived occurrence
    // should still prevent a duplicate from being generated.
    final existing = _box.values.any((t) =>
        t.title == original.title &&
        t.dueDate != null &&
        t.dueDate!.year == nextDue!.year &&
        t.dueDate!.month == nextDue.month &&
        t.dueDate!.day == nextDue.day);
    if (existing) return null;

    final next = Task(
      id: _uuid.v4(),
      title: original.title,
      description: original.description,
      priority: original.priority,
      status: TaskStatus.todo,
      category: original.category,
      dueDate: nextDue,
      dueTime: original.dueTime,
      tags: List.from(original.tags),
      subtaskTitles: List.from(original.subtaskTitles),
      subtaskDone: List.filled(original.subtaskTitles.length, false),
      isRecurring: true,
      recurringPattern: original.recurringPattern,
      goalId: original.goalId,
      habitId: original.habitId,
    );
    await _box.put(next.id, next);
    return next;
  }

  /// Generates overdue occurrences for all recurring tasks that have
  /// been completed but whose next occurrence was never created (e.g.
  /// app was closed before markDone ran the generation). Should be
  /// called on app startup.
  Future<List<Task>> generateOverdueOccurrences() async {
    final created = <Task>[];
    final recurring = _box.values
        .where((t) =>
            t.isRecurring &&
            t.recurringPattern.isNotEmpty &&
            t.status == TaskStatus.done &&
            !t.archived)
        .toList();

    for (final task in recurring) {
      // Check if the next occurrence already exists
      final baseDate = task.dueDate ?? task.completedAt ?? task.createdAt;
      DateTime? expectedNext;
      switch (task.recurringPattern.toLowerCase()) {
        case 'daily':
          expectedNext = baseDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          expectedNext = baseDate.add(const Duration(days: 7));
          break;
        case 'monthly':
          final nm = baseDate.month == 12
              ? DateTime(baseDate.year + 1, 1, 1)
              : DateTime(baseDate.year, baseDate.month + 1, 1);
          final lastDay = DateTime(nm.year, nm.month + 1, 0).day;
          expectedNext =
              DateTime(nm.year, nm.month, baseDate.day.clamp(1, lastDay));
          break;
        default:
          continue;
      }
      expectedNext =
          DateTime(expectedNext.year, expectedNext.month, expectedNext.day);

      // Skip if expected next date is still in the future (not overdue)
      final today = DateTime.now();
      final todayNorm = DateTime(today.year, today.month, today.day);
      if (expectedNext.isAfter(todayNorm)) continue;

      // Check ALL tasks (regardless of status or archived state) for
      // same title + dueDate to prevent duplicates.
      final exists = _box.values.any((t) =>
          t.title == task.title &&
          t.dueDate != null &&
          t.dueDate!.year == expectedNext!.year &&
          t.dueDate!.month == expectedNext.month &&
          t.dueDate!.day == expectedNext.day);
      if (exists) continue;

      final next = Task(
        id: _uuid.v4(),
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: TaskStatus.todo,
        category: task.category,
        dueDate: expectedNext,
        dueTime: task.dueTime,
        tags: List.from(task.tags),
        subtaskTitles: List.from(task.subtaskTitles),
        subtaskDone: List.filled(task.subtaskTitles.length, false),
        isRecurring: true,
        recurringPattern: task.recurringPattern,
        goalId: task.goalId,
        habitId: task.habitId,
      );
      await _box.put(next.id, next);
      created.add(next);
    }
    return created;
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

  Future<void> restore(Task task) async {
    task.archived = false;
    task.touch();
    await _box.put(task.id, task);
  }
}
