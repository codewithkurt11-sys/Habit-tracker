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
  }

  Future<void> toggleSubtask(Task task, int index) async {
    if (index < task.subtaskDone.length) {
      task.subtaskDone[index] = !task.subtaskDone[index];
      if (task.subtaskDone.every((d) => d)) {
        task.status = TaskStatus.done;
        task.completedAt = DateTime.now();
      }
      task.touch();
      await _box.put(task.id, task);
    }
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
