import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum GoalCategory {
  health,
  career,
  finance,
  education,
  personal,
  fitness,
  other
}

extension GoalCategoryExt on GoalCategory {
  String get label {
    switch (this) {
      case GoalCategory.health: return 'Health';
      case GoalCategory.career: return 'Career';
      case GoalCategory.finance: return 'Finance';
      case GoalCategory.education: return 'Education';
      case GoalCategory.personal: return 'Personal';
      case GoalCategory.fitness: return 'Fitness';
      case GoalCategory.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalCategory.health: return Icons.favorite_outline;
      case GoalCategory.career: return Icons.work_outline;
      case GoalCategory.finance: return Icons.account_balance_wallet_outlined;
      case GoalCategory.education: return Icons.school_outlined;
      case GoalCategory.personal: return Icons.person_outline;
      case GoalCategory.fitness: return Icons.fitness_center;
      case GoalCategory.other: return Icons.flag_outlined;
    }
  }

  Color get color {
    switch (this) {
      case GoalCategory.health: return const Color(0xFFD4675A);
      case GoalCategory.career: return const Color(0xFF7B93B5);
      case GoalCategory.finance: return const Color(0xFF6B9080);
      case GoalCategory.education: return const Color(0xFFE8C56F);
      case GoalCategory.personal: return const Color(0xFFB58BB5);
      case GoalCategory.fitness: return const Color(0xFFE8946F);
      case GoalCategory.other: return const Color(0xFFC4A895);
    }
  }
}

/// v2.0.0 Goal: progress is auto-calculated from linked items.
/// [linkedHabitIds], [linkedTaskIds], [linkedFinanceId] connect entities.
/// [progressPercent] is computed from linked items' completion ratio.
class Goal extends HiveObject {
  String id;
  String title;
  String description;
  int categoryIndex;
  DateTime? targetDate;
  List<String> linkedHabitIds;
  List<String> linkedTaskIds;
  String? linkedFinanceId;
  int colorValue;
  bool completed;
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryIndex = 6,
    this.targetDate,
    List<String>? linkedHabitIds,
    List<String>? linkedTaskIds,
    this.linkedFinanceId,
    this.colorValue = 0xFF6B9080,
    this.completed = false,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : linkedHabitIds = linkedHabitIds ?? [],
        linkedTaskIds = linkedTaskIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  GoalCategory get category =>
      GoalCategory.values[categoryIndex.clamp(0, GoalCategory.values.length - 1)];

  Color get color => Color(colorValue);

  int get daysLeft {
    if (targetDate == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return dueDay.difference(today).inDays;
  }

  /// Auto-calculated progress from linked items.
  /// Habits: avg completion rate over last 30 days
  /// Tasks: fraction completed
  /// Finance: fraction of target saved
  double progressPercent(List<double> habitRates, double taskFraction, double financeFraction) {
    final parts = <double>[];
    if (habitRates.isNotEmpty) {
      parts.add(habitRates.reduce((a, b) => a + b) / habitRates.length);
    }
    if (linkedTaskIds.isNotEmpty) {
      parts.add(taskFraction);
    }
    if (linkedFinanceId != null) {
      parts.add(financeFraction);
    }
    if (parts.isEmpty) return completed ? 100.0 : 0.0;
    return (parts.reduce((a, b) => a + b) / parts.length * 100).clamp(0, 100);
  }
}

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 9;

  @override
  Goal read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      categoryIndex: fields[3] as int? ?? 6,
      targetDate: fields[4] as DateTime?,
      linkedHabitIds: (fields[14] as List?)?.cast<String>() ?? [],
      linkedTaskIds: (fields[15] as List?)?.cast<String>() ?? [],
      linkedFinanceId: fields[16] as String?,
      colorValue: fields[13] as int? ?? 0xFF6B9080,
      completed: fields[11] as bool? ?? false,
      archived: fields[12] as bool? ?? false,
      createdAt: fields[17] as DateTime? ?? DateTime.now(),
      updatedAt: fields[18] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryIndex)
      ..writeByte(4)
      ..write(obj.targetDate)
      ..writeByte(11)
      ..write(obj.completed)
      ..writeByte(12)
      ..write(obj.archived)
      ..writeByte(13)
      ..write(obj.colorValue)
      ..writeByte(14)
      ..write(obj.linkedHabitIds)
      ..writeByte(15)
      ..write(obj.linkedTaskIds)
      ..writeByte(16)
      ..write(obj.linkedFinanceId)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt);
  }
}
