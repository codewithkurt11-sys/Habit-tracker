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
      if (a.deadline != null && b.deadline != null)
        return a.deadline!.compareTo(b.deadline!);
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Goal> getActive() => getAll().where((g) => !g.completed).toList();
  List<Goal> getCompleted() => getAll().where((g) => g.completed).toList();

  Future<Goal> create({
    required String title,
    String description = '',
    int categoryIndex = 6,
    DateTime? deadline,
    double targetValue = 100,
    int colorValue = 0xFF6B9080,
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      title: title,
      description: description,
      categoryIndex: categoryIndex,
      deadline: deadline,
      targetValue: targetValue,
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

  Future<void> addMilestone(Goal goal, String title,
      {DateTime? dueDate}) async {
    goal.milestoneIds.add(_uuid.v4());
    goal.milestoneTitles.add(title);
    goal.milestoneDone.add(false);
    goal.milestoneDates.add(dueDate);
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> toggleMilestone(Goal goal, int index) async {
    if (index < goal.milestoneDone.length) {
      goal.milestoneDone[index] = !goal.milestoneDone[index];
      // Check if all milestones done
      if (goal.milestoneTitles.isNotEmpty &&
          goal.milestoneDone.every((d) => d)) {
        goal.completed = true;
      }
      goal.touch();
      await _box.put(goal.id, goal);
    }
  }

  Future<void> updateProgress(Goal goal, double value) async {
    goal.currentValue = value.clamp(0, goal.targetValue);
    if (goal.currentValue >= goal.targetValue) goal.completed = true;
    goal.touch();
    await _box.put(goal.id, goal);
  }

  Future<void> archive(Goal goal) async {
    goal.archived = true;
    goal.touch();
    await _box.put(goal.id, goal);
  }
}
