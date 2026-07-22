import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum HabitCategory { workout, lifestyle, other }

enum HabitFrequency { daily, weekly, custom }

/// Available habit icons (codepoint-based so they serialize as ints).
enum HabitIcon {
  fitness,
  book,
  water,
  meditation,
  sleep,
  food,
  walk,
  study,
  music,
  art,
  code,
  health,
  money,
  social,
  nature,
  custom,
}

extension HabitIconData on HabitIcon {
  IconData get data {
    switch (this) {
      case HabitIcon.fitness:
        return Icons.fitness_center;
      case HabitIcon.book:
        return Icons.menu_book;
      case HabitIcon.water:
        return Icons.water_drop;
      case HabitIcon.meditation:
        return Icons.self_improvement;
      case HabitIcon.sleep:
        return Icons.bedtime;
      case HabitIcon.food:
        return Icons.restaurant;
      case HabitIcon.walk:
        return Icons.directions_walk;
      case HabitIcon.study:
        return Icons.school;
      case HabitIcon.music:
        return Icons.music_note;
      case HabitIcon.art:
        return Icons.palette;
      case HabitIcon.code:
        return Icons.code;
      case HabitIcon.health:
        return Icons.favorite;
      case HabitIcon.money:
        return Icons.savings;
      case HabitIcon.social:
        return Icons.people;
      case HabitIcon.nature:
        return Icons.park;
      case HabitIcon.custom:
        return Icons.star;
    }
  }
}

/// A recurring habit the user is tracking.
///
/// [completionLog] stores completed dates normalized to midnight.
/// [customDays] holds ISO weekday numbers (1 = Monday .. 7 = Sunday).
/// [colorValue] is a custom ARGB color; null falls back to category color.
/// [targetStreak] is an optional goal streak the user aims for.
class Habit extends HiveObject {
  String id;
  String name;
  HabitCategory category;
  HabitFrequency frequency;
  List<int> customDays;
  List<DateTime> completionLog;
  DateTime createdAt;
  int iconIndex;
  int? colorValue;
  int targetStreak;

  Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.frequency,
    List<int>? customDays,
    List<DateTime>? completionLog,
    DateTime? createdAt,
    this.iconIndex = 15, // HabitIcon.custom
    this.colorValue,
    this.targetStreak = 0,
  }) : customDays = customDays ?? [],
       completionLog = completionLog ?? [],
       createdAt = createdAt ?? DateTime.now();

  HabitIcon get icon =>
      HabitIcon.values[iconIndex.clamp(0, HabitIcon.values.length - 1)];

  Color? get customColor => colorValue == null ? null : Color(colorValue!);

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

  /// Current streak counted across scheduled days, ending at [asOf].
  int currentStreak({DateTime? asOf}) {
    final value = asOf ?? DateTime.now();
    var cursor = DateTime(value.year, value.month, value.day);
    final firstDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var streak = 0;

    // Today is still in progress, so an incomplete today does not break a streak.
    if (isDueOn(cursor) && !isCompletedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (!cursor.isBefore(firstDay)) {
      if (isDueOn(cursor)) {
        if (!isCompletedOn(cursor)) break;
        streak++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Best (longest) streak across scheduled days, ignoring duplicate logs.
  int bestStreak() {
    if (completionLog.isEmpty) return 0;
    final completedDays =
        completionLog
            .map((d) => DateTime(d.year, d.month, d.day))
            .where(isDueOn)
            .toSet()
            .toList()
          ..sort();
    if (completedDays.isEmpty) return 0;

    var best = 0;
    var current = 0;
    var cursor = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final last = completedDays.last;
    final completed = completedDays.toSet();
    while (!cursor.isAfter(last)) {
      if (isDueOn(cursor)) {
        if (completed.contains(cursor)) {
          current++;
          if (current > best) best = current;
        } else {
          current = 0;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return best;
  }

  /// Number of consecutive scheduled days missed before today.
  int currentMissStreak({DateTime? asOf}) {
    final value = asOf ?? DateTime.now();
    var cursor = DateTime(
      value.year,
      value.month,
      value.day,
    ).subtract(const Duration(days: 1));
    final firstDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var misses = 0;

    while (!cursor.isBefore(firstDay)) {
      if (isDueOn(cursor)) {
        if (isCompletedOn(cursor)) break;
        misses++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return misses;
  }

  /// Completion rate over the last [days] days (0.0 - 1.0).
  double completionRate({int days = 30, DateTime? asOf}) {
    if (days <= 0) return 0;
    final value = asOf ?? DateTime.now();
    final end = DateTime(value.year, value.month, value.day);
    final windowStart = end.subtract(Duration(days: days - 1));
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var cursor = windowStart.isAfter(createdDay) ? windowStart : createdDay;
    var dueDays = 0;
    var completedDays = 0;
    while (!cursor.isAfter(end)) {
      if (isDueOn(cursor)) {
        dueDays++;
        if (isCompletedOn(cursor)) completedDays++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return dueDays == 0 ? 0 : completedDays / dueDays;
  }

  /// Total unique, valid completions.
  int get totalCompletions => completionLog
      .map((d) => DateTime(d.year, d.month, d.day))
      .where(isDueOn)
      .toSet()
      .length;
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
      name: fields[1] as String,
      category: HabitCategory.values[fields[2] as int],
      frequency: HabitFrequency.values[fields[3] as int],
      customDays: (fields[4] as List).cast<int>(),
      completionLog: (fields[5] as List).cast<DateTime>(),
      createdAt: fields[6] as DateTime,
      iconIndex: fields[7] as int? ?? 15,
      colorValue: fields[8] as int?,
      targetStreak: fields[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category.index)
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
      ..write(obj.targetStreak);
  }
}
