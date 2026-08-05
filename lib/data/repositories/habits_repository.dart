import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/habit.dart';

class HabitsRepository {
  Box<Habit> get _box => Hive.box<Habit>(HiveBoxes.habits);
  final _uuid = const Uuid();

  List<Habit> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  List<Habit> getDueToday() {
    final today = DateTime.now();
    return getAll().where((h) => h.isDueOn(today)).toList();
  }

  List<Habit> getDueOn(DateTime date) {
    return getAll().where((h) => h.isDueOn(date)).toList();
  }

  Habit? getById(String id) {
    try {
      return _box.values.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Habit> create({
    required String title,
    String description = '',
    String? linkedGoalId,
    required HabitFrequency frequency,
    List<int>? customDays,
    DateTime? reminderTime,
    int iconIndex = 0,
    int? colorValue,
    int targetStreak = 0,
  }) async {
    final habit = Habit(
      id: _uuid.v4(),
      title: title,
      description: description,
      linkedGoalId: linkedGoalId,
      frequency: frequency,
      customDays: customDays,
      reminderTime: reminderTime,
      iconIndex: iconIndex,
      colorValue: colorValue,
      targetStreak: targetStreak,
    );
    await _box.put(habit.id, habit);
    return habit;
  }

  Future<void> update(Habit habit) async {
    habit.touch();
    await _box.put(habit.id, habit);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> toggleCompletion(Habit habit, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    final normalized = DateTime(target.year, target.month, target.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (normalized.isAfter(today) || !habit.isDueOn(normalized)) return;
    final alreadyDone = habit.isCompletedOn(normalized);

    if (alreadyDone) {
      habit.completionLog.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    } else {
      habit.completionLog.add(normalized);
      // Remove skip if it was skipped
      habit.skipLog.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    }
    habit.touch();
    await _box.put(habit.id, habit);
  }

  Future<void> skipDay(Habit habit, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    final normalized = DateTime(target.year, target.month, target.day);
    if (!habit.isDueOn(normalized)) return;

    if (!habit.isSkippedOn(normalized)) {
      habit.skipLog.add(normalized);
    }
    // Remove completion if it was completed
    habit.completionLog.removeWhere(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
    habit.touch();
    await _box.put(habit.id, habit);
  }
}
