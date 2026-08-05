import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/goal.dart';

class GoalsRepository {
  Box<Goal> get _box => Hive.box<Goal>(HiveBoxes.goals);
  final _uuid = const Uuid();

  List<Goal> getAll({bool includeArchived = false}) {
    final list =
        _box.values.where((g) => includeArchived || !g.archived).toList();
    list.sort((a, b) {
      if (a.completed && !b.completed) return 1;
      if (!a.completed && b.completed) return -1;
      if (a.targetDate != null && b.targetDate != null) {
        return a.targetDate!.compareTo(b.targetDate!);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Goal> getActive() => getAll().where((g) => !g.completed).toList();
  List<Goal> getCompleted() => getAll().where((g) => g.completed).toList();

  Goal? getById(String id) {
    try {
      return _box.values.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Goal> create({
    required String title,
    String description = '',
    int categoryIndex = 6,
    DateTime? targetDate,
    int colorValue = 0xFF6B9080,
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      title: title,
      description: description,
      categoryIndex: categoryIndex,
      targetDate: targetDate,
      colorValue: colorValue,
    );
    await _box.put(goal.id, goal);
    return goal;
  }

  Future<void> update(Goal goal) async {
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> delete(String id) async => _box.delete(id);

  Future<void> linkHabit(Goal goal, String habitId) async {
    if (!goal.linkedHabitIds.contains(habitId)) {
      goal.linkedHabitIds.add(habitId);
      goal.touch();
      await _box.put(goal.id, goal);
    }
  }

  Future<void> unlinkHabit(Goal goal, String habitId) async {
    goal.linkedHabitIds.remove(habitId);
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> linkTask(Goal goal, String taskId) async {
    if (!goal.linkedTaskIds.contains(taskId)) {
      goal.linkedTaskIds.add(taskId);
      goal.touch();
      await _box.put(goal.id, goal);
    }
  }

  Future<void> unlinkTask(Goal goal, String taskId) async {
    goal.linkedTaskIds.remove(taskId);
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> linkFinance(Goal goal, String financeId) async {
    goal.linkedFinanceId = financeId;
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> unlinkFinance(Goal goal) async {
    goal.linkedFinanceId = null;
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> archive(Goal goal) async {
    goal.archived = true;
    goal.touch();
    await _box.put(goal.id, goal);
  }
}
