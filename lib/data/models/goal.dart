import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum GoalCategory { health, career, finance, education, personal, fitness, other }

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

class Milestone {
  String id;
  String title;
  bool completed;
  DateTime? dueDate;

  Milestone({
    required this.id,
    required this.title,
    this.completed = false,
    this.dueDate,
  });
}

class Goal extends HiveObject {
  String id;
  String title;
  String description;
  int categoryIndex;
  DateTime? deadline;
  double targetValue;
  double currentValue;
  List<String> milestoneIds;
  List<String> milestoneTitles;
  List<bool> milestoneDone;
  List<DateTime?> milestoneDates;
  bool completed;
  bool archived;
  int colorValue;
  DateTime createdAt;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryIndex = 6,
    this.deadline,
    this.targetValue = 100,
    this.currentValue = 0,
    List<String>? milestoneIds,
    List<String>? milestoneTitles,
    List<bool>? milestoneDone,
    List<DateTime?>? milestoneDates,
    this.completed = false,
    this.archived = false,
    this.colorValue = 0xFF6B9080,
    DateTime? createdAt,
  })  : milestoneIds = milestoneIds ?? [],
        milestoneTitles = milestoneTitles ?? [],
        milestoneDone = milestoneDone ?? [],
        milestoneDates = milestoneDates ?? [],
        createdAt = createdAt ?? DateTime.now();

  GoalCategory get category =>
      GoalCategory.values[categoryIndex.clamp(0, GoalCategory.values.length - 1)];

  Color get color => Color(colorValue);

  double get progressFraction =>
      targetValue <= 0 ? 0 : (currentValue / targetValue).clamp(0, 1);

  List<Milestone> get milestones {
    final len = milestoneTitles.length;
    return List.generate(len, (i) => Milestone(
      id: i < milestoneIds.length ? milestoneIds[i] : i.toString(),
      title: milestoneTitles[i],
      completed: i < milestoneDone.length ? milestoneDone[i] : false,
      dueDate: i < milestoneDates.length ? milestoneDates[i] : null,
    ));
  }

  int get daysLeft {
    if (deadline == null) return -1;
    return deadline!.difference(DateTime.now()).inDays;
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
      deadline: fields[4] as DateTime?,
      targetValue: (fields[5] as num?)?.toDouble() ?? 100,
      currentValue: (fields[6] as num?)?.toDouble() ?? 0,
      milestoneIds: (fields[7] as List?)?.cast<String>() ?? [],
      milestoneTitles: (fields[8] as List?)?.cast<String>() ?? [],
      milestoneDone: (fields[9] as List?)?.cast<bool>() ?? [],
      milestoneDates: (fields[10] as List?)?.cast<DateTime?>() ?? [],
      completed: fields[11] as bool? ?? false,
      archived: fields[12] as bool? ?? false,
      colorValue: fields[13] as int? ?? 0xFF6B9080,
      createdAt: fields[14] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.description)
      ..writeByte(3)..write(obj.categoryIndex)
      ..writeByte(4)..write(obj.deadline)
      ..writeByte(5)..write(obj.targetValue)
      ..writeByte(6)..write(obj.currentValue)
      ..writeByte(7)..write(obj.milestoneIds)
      ..writeByte(8)..write(obj.milestoneTitles)
      ..writeByte(9)..write(obj.milestoneDone)
      ..writeByte(10)..write(obj.milestoneDates)
      ..writeByte(11)..write(obj.completed)
      ..writeByte(12)..write(obj.archived)
      ..writeByte(13)..write(obj.colorValue)
      ..writeByte(14)..write(obj.createdAt);
  }
}
