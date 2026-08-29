import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/task.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_rule.dart';

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
    RecurrenceRule? recurrenceRule,
    String? customCategoryId,
    List<ReminderRule> reminders = const [],
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
      recurrenceRule: isRecurring ? (recurrenceRule ?? RecurrenceRule.fromLegacy(recurringPattern, startDate: dueDate)) : null,
      customCategoryId: customCategoryId,
      reminders: List.of(reminders),
      goalId: goalId,
      habitId: habitId,
      recurrenceSeriesId: isRecurring ? _uuid.v4() : null,
    );
    await _box.put(task.id, task);
    return task;
  }

  Future<void> update(Task task) async {
    task.touch();
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async => _box.delete(id);

  Future<Task?> markDone(Task task) async {
    task.status = TaskStatus.done;
    task.completedAt = DateTime.now();
    task.touch();
    await _box.put(task.id, task);
    if (!task.isRecurring) return null;
    return _generateNextOccurrence(task);
  }

  Future<Task?> _generateNextOccurrence(Task original) async {
    final rule = original.recurrenceRule ??
        RecurrenceRule.fromLegacy(
          original.recurringPattern,
          startDate: original.dueDate ?? original.createdAt,
        );
    final baseDate = original.dueDate ?? original.completedAt ?? DateTime.now();
    final seriesId = original.recurrenceSeriesId ?? original.id;
    // Assign the fallback series ID before collecting history. Otherwise an
    // old task with a null series ID could accidentally count unrelated legacy
    // recurring tasks that also have null series IDs.
    original.recurrenceSeriesId ??= seriesId;
    final completedDates = _box.values
        .where((t) =>
            t.recurrenceSeriesId == seriesId &&
            t.status == TaskStatus.done)
        .map((t) => t.dueDate ?? t.completedAt ?? t.createdAt)
        .toList();
    final nextDue = rule.nextOccurrenceAfter(
      baseDate,
      completedDates: completedDates,
    );
    if (nextDue == null) return null;

    original.recurrenceRule ??= rule;
    original.recurringPattern = _legacyPatternFor(rule);
    await _box.put(original.id, original);

    final existing = _box.values.any((t) =>
        t.id != original.id &&
        !t.archived &&
        t.dueDate != null &&
        t.status != TaskStatus.done &&
        _sameDate(t.dueDate!, nextDue) &&
        ((t.recurrenceSeriesId != null && t.recurrenceSeriesId == seriesId) ||
            (t.recurrenceSeriesId == null && t.title == original.title)));
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
      recurringPattern: _legacyPatternFor(rule),
      recurrenceRule: rule.copyWith(startDate: rule.startDate ?? (original.dueDate ?? original.createdAt)),
      customCategoryId: original.customCategoryId,
      reminders: List.of(original.reminders),
      goalId: original.goalId,
      habitId: original.habitId,
      recurrenceSeriesId: seriesId,
    );
    await _box.put(next.id, next);
    return next;
  }

  String _legacyPatternFor(RecurrenceRule rule) {
    switch (rule.type) {
      case RecurrenceType.daily:
        return rule.interval == 1 ? 'daily' : 'advanced';
      case RecurrenceType.weeklyDays:
        return rule.interval == 1 && rule.weekdays.length == 1 ? 'weekly' : 'advanced';
      case RecurrenceType.monthlyDates:
        return rule.interval == 1 && rule.monthDays.length == 1 ? 'monthly' : 'advanced';
      case RecurrenceType.yearlyDate:
      case RecurrenceType.interval:
      case RecurrenceType.timesPerPeriod:
      case RecurrenceType.alternate:
        return 'advanced';
    }
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Generates missed occurrences for recurring tasks after an interrupted app
  /// session. It creates at most one next occurrence per completed task to
  /// avoid an unbounded catch-up storm and remains safe for all rule types.
  Future<List<Task>> generateOverdueOccurrences() async {
    final created = <Task>[];
    final recurring = _box.values
        .where((t) => t.isRecurring && t.status == TaskStatus.done && !t.archived)
        .toList();

    for (final task in recurring) {
      final rule = task.recurrenceRule ??
          RecurrenceRule.fromLegacy(
            task.recurringPattern,
            startDate: task.dueDate ?? task.createdAt,
          );
      task.recurrenceRule ??= rule;
      task.recurrenceSeriesId ??= task.id;
      await _box.put(task.id, task);

      final base = task.dueDate ?? task.completedAt ?? task.createdAt;
      final completedDates = _box.values
          .where((t) =>
              t.recurrenceSeriesId == task.recurrenceSeriesId &&
              t.status == TaskStatus.done)
          .map((t) => t.dueDate ?? t.completedAt ?? t.createdAt)
          .toList();
      final expected = rule.nextOccurrenceAfter(base, completedDates: completedDates);
      if (expected == null || expected.isAfter(DateTime.now())) continue;
      final exists = _box.values.any((t) =>
          t.id != task.id &&
          t.dueDate != null &&
          _sameDate(t.dueDate!, expected) &&
          ((t.recurrenceSeriesId != null && t.recurrenceSeriesId == task.recurrenceSeriesId) ||
              (t.recurrenceSeriesId == null && t.title == task.title)));
      if (exists) continue;

      final next = Task(
        id: _uuid.v4(),
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: TaskStatus.todo,
        category: task.category,
        dueDate: expected,
        dueTime: task.dueTime,
        tags: List.from(task.tags),
        subtaskTitles: List.from(task.subtaskTitles),
        subtaskDone: List.filled(task.subtaskTitles.length, false),
        isRecurring: true,
        recurringPattern: _legacyPatternFor(rule),
        recurrenceRule: rule,
        customCategoryId: task.customCategoryId,
        reminders: List.of(task.reminders),
        goalId: task.goalId,
        habitId: task.habitId,
        recurrenceSeriesId: task.recurrenceSeriesId,
      );
      await _box.put(next.id, next);
      created.add(next);
    }
    return created;
  }

  Future<Task?> toggleSubtask(Task task, int index) async {
    if (index < 0 || index >= task.subtaskDone.length) return null;

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
    if (allDone && task.isRecurring) {
      return _generateNextOccurrence(task);
    }
    return null;
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
