import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum TaskPriority { low, medium, high, urgent }
enum TaskStatus { todo, inProgress, done, archived }
enum TaskCategory {
  work, personal, health, finance, education, home, social, other
}

extension TaskPriorityExt on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low', TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High', TaskPriority.urgent => 'Urgent',
  };
  Color get color => switch (this) {
    TaskPriority.low => const Color(0xFF6B9080),
    TaskPriority.medium => const Color(0xFFE8C56F),
    TaskPriority.high => const Color(0xFFE8946F),
    TaskPriority.urgent => const Color(0xFFD4675A),
  };
  IconData get icon => switch (this) {
    TaskPriority.low => Icons.arrow_downward,
    TaskPriority.medium => Icons.remove,
    TaskPriority.high => Icons.arrow_upward,
    TaskPriority.urgent => Icons.priority_high,
  };
}

extension TaskCategoryExt on TaskCategory {
  String get label => switch (this) {
    TaskCategory.work => 'Work', TaskCategory.personal => 'Personal',
    TaskCategory.health => 'Health', TaskCategory.finance => 'Finance',
    TaskCategory.education => 'Education', TaskCategory.home => 'Home',
    TaskCategory.social => 'Social', TaskCategory.other => 'Other',
  };
  IconData get icon => switch (this) {
    TaskCategory.work => Icons.work_outline,
    TaskCategory.personal => Icons.person_outline,
    TaskCategory.health => Icons.favorite_outline,
    TaskCategory.finance => Icons.account_balance_wallet_outlined,
    TaskCategory.education => Icons.school_outlined,
    TaskCategory.home => Icons.home_outlined,
    TaskCategory.social => Icons.people_outline,
    TaskCategory.other => Icons.category_outlined,
  };
}

/// v2.0.0 Task: [linkedGoalId], [linkedHabitId], [recurring], [recurrenceRule].
/// [recurrenceRule] = 'daily','weekly','monthly','weekdays' etc.
class Task extends HiveObject {
  String id;
  String title;
  String description;
  TaskPriority priority;
  TaskStatus status;
  TaskCategory category;
  DateTime? dueDate;
  DateTime? dueTime;
  List<String> tags;
  List<String> subtaskTitles;
  List<bool> subtaskDone;
  bool recurring;
  String recurrenceRule;
  String? linkedGoalId;
  String? linkedHabitId;
  DateTime createdAt;
  DateTime? completedAt;
  bool archived;
  DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.category = TaskCategory.personal,
    this.dueDate,
    this.dueTime,
    List<String>? tags,
    List<String>? subtaskTitles,
    List<bool>? subtaskDone,
    this.recurring = false,
    this.recurrenceRule = '',
    this.linkedGoalId,
    this.linkedHabitId,
    DateTime? createdAt,
    this.completedAt,
    this.archived = false,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        subtaskTitles = subtaskTitles ?? [],
        subtaskDone = subtaskDone ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  double get progress {
    if (subtaskTitles.isEmpty) return status == TaskStatus.done ? 1.0 : 0.0;
    final done = subtaskDone.where((d) => d).length;
    return done / subtaskTitles.length;
  }

  bool get isDue {
    if (dueDate == null) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final todayNorm = DateTime(today.year, today.month, today.day);
    return due.isBefore(todayNorm) || due.isAtSameMomentAs(todayNorm);
  }

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get isDone => status == TaskStatus.done;
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 5;

  @override
  Task read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      priority: TaskPriority.values[fields[3] as int? ?? 1],
      status: TaskStatus.values[fields[4] as int? ?? 0],
      category: TaskCategory.values[fields[5] as int? ?? 7],
      dueDate: fields[6] as DateTime?,
      dueTime: fields[7] as DateTime?,
      tags: (fields[8] as List?)?.cast<String>() ?? [],
      subtaskTitles: (fields[9] as List?)?.cast<String>() ?? [],
      subtaskDone: (fields[10] as List?)?.cast<bool>() ?? [],
      recurring: fields[17] as bool? ?? (fields[11] as bool? ?? false),
      recurrenceRule: fields[18] as String? ?? (fields[12] as String? ?? ''),
      linkedGoalId: fields[19] as String?,
      linkedHabitId: fields[20] as String?,
      createdAt: fields[13] as DateTime? ?? DateTime.now(),
      completedAt: fields[14] as DateTime?,
      archived: fields[15] as bool? ?? false,
      updatedAt: fields[16] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.priority.index)
      ..writeByte(4)
      ..write(obj.status.index)
      ..writeByte(5)
      ..write(obj.category.index)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.dueTime)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.subtaskTitles)
      ..writeByte(10)
      ..write(obj.subtaskDone)
      ..writeByte(17)
      ..write(obj.recurring)
      ..writeByte(18)
      ..write(obj.recurrenceRule)
      ..writeByte(19)
      ..write(obj.linkedGoalId)
      ..writeByte(20)
      ..write(obj.linkedHabitId)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.completedAt)
      ..writeByte(15)
      ..write(obj.archived)
      ..writeByte(16)
      ..write(obj.updatedAt);
  }
}
