import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum HabitFrequency { daily, weekly, custom }

/// A recurring habit the user is tracking.
///
/// v2.0.0: Added [description], [linkedGoalId], [reminderTime], [skipLog].
/// [completionLog] stores completed dates normalized to midnight.
/// [skipLog] stores excused/skipped dates (doesn't break streak).
/// [customDays] holds ISO weekday numbers (1 = Monday .. 7 = Sunday).
class Habit extends HiveObject {
  String id;
  String title;
  String description;
  String? linkedGoalId;
  HabitFrequency frequency;
  List<int> customDays;
  DateTime? reminderTime; // Time-of-day for reminders
  List<DateTime> completionLog;
  List<DateTime> skipLog; // excused days — don't break streak
  DateTime createdAt;
  int iconIndex;
  int? colorValue;
  int targetStreak;
  DateTime updatedAt;

  Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.linkedGoalId,
    required this.frequency,
    List<int>? customDays,
    this.reminderTime,
    List<DateTime>? completionLog,
    List<DateTime>? skipLog,
    DateTime? createdAt,
    this.iconIndex = 0,
    this.colorValue,
    this.targetStreak = 0,
    DateTime? updatedAt,
  })  : customDays = customDays ?? [],
        completionLog = completionLog ?? [],
        skipLog = skipLog ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  Color? get customColor => colorValue == null ? null : Color(colorValue!);

  IconData get icon {
    const icons = [
      Icons.fitness_center,
      Icons.menu_book,
      Icons.water_drop,
      Icons.self_improvement,
      Icons.bedtime,
      Icons.restaurant,
      Icons.directions_walk,
      Icons.school,
      Icons.music_note,
      Icons.palette,
      Icons.code,
      Icons.favorite,
      Icons.savings,
      Icons.people,
      Icons.park,
      Icons.star,
    ];
    return icons[iconIndex.clamp(0, icons.length - 1)];
  }

  bool isDueOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final firstDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (day.isBefore(firstDay)) return false;

    switch (frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.weekly:
        return date.weekday == createdAt.weekday;
      case HabitFrequency.custom:
        return customDays.contains(date.weekday);
    }
  }

  bool isCompletedOn(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return completionLog.any(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
  }

  bool isSkippedOn(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return skipLog.any(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
  }

  /// Current streak counted across scheduled days, ending at [asOf].
  /// Skipped days count as completed (excused).
  int currentStreak({DateTime? asOf}) {
    final value = asOf ?? DateTime.now();
    var cursor = DateTime(value.year, value.month, value.day);
    final firstDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var streak = 0;

    if (isDueOn(cursor) && !isCompletedOn(cursor) && !isSkippedOn(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    while (!cursor.isBefore(firstDay)) {
      if (isDueOn(cursor)) {
        if (!isCompletedOn(cursor) && !isSkippedOn(cursor)) break;
        streak++;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  int bestStreak() {
    if (completionLog.isEmpty && skipLog.isEmpty) return 0;
    final goodDays = <DateTime>{};
    for (final d in completionLog) {
      goodDays.add(DateTime(d.year, d.month, d.day));
    }
    for (final d in skipLog) {
      goodDays.add(DateTime(d.year, d.month, d.day));
    }
    final dueDays = goodDays.where(isDueOn).toList()..sort();
    if (dueDays.isEmpty) return 0;

    var best = 0;
    var current = 0;
    var cursor = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final last = dueDays.last;
    while (!cursor.isAfter(last)) {
      if (isDueOn(cursor)) {
        if (goodDays.contains(cursor)) {
          current++;
          if (current > best) best = current;
        } else {
          current = 0;
        }
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return best;
  }

  double completionRate({int days = 30, DateTime? asOf}) {
    if (days <= 0) return 0;
    final value = asOf ?? DateTime.now();
    final end = DateTime(value.year, value.month, value.day);
    final windowStart = DateTime(end.year, end.month, end.day - (days - 1));
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var cursor = windowStart.isAfter(createdDay) ? windowStart : createdDay;
    var dueDays = 0;
    var completedDays = 0;
    while (!cursor.isAfter(end)) {
      if (isDueOn(cursor)) {
        dueDays++;
        if (isCompletedOn(cursor) || isSkippedOn(cursor)) completedDays++;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return dueDays == 0 ? 0 : completedDays / dueDays;
  }

  int get totalCompletions => completionLog
      .map((d) => DateTime(d.year, d.month, d.day))
      .where(isDueOn)
      .toSet()
      .length;

  /// Consistency score: streak length + frequency + recency (0-100).
  int get consistencyScore {
    final streak = currentStreak();
    final rate = completionRate(days: 30);
    final recencyBoost = completionLog.isNotEmpty &&
            DateTime.now().difference(completionLog.last).inDays == 0
        ? 10
        : 0;
    final score = (streak * 2.0).clamp(0, 50) +
        (rate * 40) +
        recencyBoost;
    return score.round().clamp(0, 100);
  }

  /// Check if a milestone was just reached (7, 30, 100 days).
  int? checkMilestone() {
    final s = currentStreak();
    if (s == 7 || s == 30 || s == 100) return s;
    return null;
  }
}

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 1;

  @override
  Habit read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      linkedGoalId: fields[12] as String?,
      frequency: HabitFrequency.values[fields[3] as int],
      customDays: (fields[4] as List).cast<int>(),
      reminderTime: fields[11] as DateTime?,
      completionLog: (fields[5] as List).cast<DateTime>(),
      skipLog: (fields[13] as List?)?.cast<DateTime>() ?? [],
      createdAt: fields[6] as DateTime,
      iconIndex: fields[7] as int? ?? 0,
      colorValue: fields[8] as int?,
      targetStreak: fields[9] as int? ?? 0,
      updatedAt: fields[10] as DateTime? ?? fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.frequency.index)
      ..writeByte(4)
      ..write(obj.customDays)
      ..writeByte(5)
      ..write(obj.completionLog)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.iconIndex)
      ..writeByte(8)
      ..write(obj.colorValue)
      ..writeByte(9)
      ..write(obj.targetStreak)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.reminderTime)
      ..writeByte(12)
      ..write(obj.linkedGoalId)
      ..writeByte(13)
      ..write(obj.skipLog);
  }
}
