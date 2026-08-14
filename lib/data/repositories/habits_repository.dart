import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/habit.dart';

class HabitsRepository {
  Box<Habit> get _box => Hive.box<Habit>(HiveBoxes.habits);
  final _uuid = const Uuid();

  List<Habit> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
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
    required String name,
    required HabitCategory category,
    required HabitFrequency frequency,
    List<int>? customDays,
    int iconIndex = 15,
    int? colorValue,
    int targetStreak = 0,
    String? goalId,
  }) async {
    // Validate: custom frequency requires at least one weekday
    if (frequency == HabitFrequency.custom &&
        (customDays == null || customDays.isEmpty)) {
      throw ArgumentError(
          'Custom frequency habits require at least one selected day');
    }
    final habit = Habit(
      id: _uuid.v4(),
      name: name,
      category: category,
      frequency: frequency,
      customDays: customDays,
      iconIndex: iconIndex,
      colorValue: colorValue,
      targetStreak: targetStreak,
      goalId: goalId,
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
      // Remove from skip log if it was skipped before
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

  /// Explicitly skip a habit for a given day.  Skipped days do not break
  /// streaks and are excluded from the completion-rate denominator.
  Future<void> skipDay(Habit habit, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    final normalized = DateTime(target.year, target.month, target.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (normalized.isAfter(today) || !habit.isDueOn(normalized)) return;
    final alreadySkipped = habit.isSkippedOn(normalized);

    if (alreadySkipped) {
      habit.skipLog.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    } else {
      habit.skipLog.add(normalized);
      // Remove from completion log if it was completed before
      habit.completionLog.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    }
    habit.touch();
    await _box.put(habit.id, habit);
  }
}
