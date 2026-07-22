import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum TaskPriority { low, medium, high, urgent }

enum TaskStatus { todo, inProgress, done, archived }

enum TaskCategory {
  work,
  personal,
  health,
  finance,
  education,
  home,
  social,
  other,
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low: return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high: return 'High';
      case TaskPriority.urgent: return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low: return const Color(0xFF6B9080);
      case TaskPriority.medium: return const Color(0xFFE8C56F);
      case TaskPriority.high: return const Color(0xFFE8946F);
      case TaskPriority.urgent: return const Color(0xFFD4675A);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.low: return Icons.arrow_downward;
      case TaskPriority.medium: return Icons.remove;
      case TaskPriority.high: return Icons.arrow_upward;
      case TaskPriority.urgent: return Icons.priority_high;
    }
  }
}

extension TaskCategoryExt on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.work: return 'Work';
      case TaskCategory.personal: return 'Personal';
      case TaskCategory.health: return 'Health';
      case TaskCategory.finance: return 'Finance';
      case TaskCategory.education: return 'Education';
      case TaskCategory.home: return 'Home';
      case TaskCategory.social: return 'Social';
      case TaskCategory.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.work: return Icons.work_outline;
      case TaskCategory.personal: return Icons.person_outline;
      case TaskCategory.health: return Icons.favorite_outline;
      case TaskCategory.finance: return Icons.account_balance_wallet_outlined;
      case TaskCategory.education: return Icons.school_outlined;
      case TaskCategory.home: return Icons.home_outlined;
      case TaskCategory.social: return Icons.people_outline;
      case TaskCategory.other: return Icons.category_outlined;
    }
  }
}

class SubTask {
  String id;
  String title;
  bool done;

  SubTask({required this.id, required this.title, this.done = false});
}

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
  bool isRecurring;
  String recurringPattern; // 'daily','weekly','monthly'
  DateTime createdAt;
  DateTime? completedAt;
  bool archived;

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
    this.isRecurring = false,
    this.recurringPattern = '',
    DateTime? createdAt,
    this.completedAt,
    this.archived = false,
  })  : tags = tags ?? [],
        subtaskTitles = subtaskTitles ?? [],
        subtaskDone = subtaskDone ?? [],
        createdAt = createdAt ?? DateTime.now();

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

  List<SubTask> get subtasks {
    final len = subtaskTitles.length;
    return List.generate(len, (i) => SubTask(
      id: i.toString(),
      title: subtaskTitles[i],
      done: i < subtaskDone.length ? subtaskDone[i] : false,
    ));
  }
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
      isRecurring: fields[11] as bool? ?? false,
      recurringPattern: fields[12] as String? ?? '',
      createdAt: fields[13] as DateTime? ?? DateTime.now(),
      completedAt: fields[14] as DateTime?,
      archived: fields[15] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.description)
      ..writeByte(3)..write(obj.priority.index)
      ..writeByte(4)..write(obj.status.index)
      ..writeByte(5)..write(obj.category.index)
      ..writeByte(6)..write(obj.dueDate)
      ..writeByte(7)..write(obj.dueTime)
      ..writeByte(8)..write(obj.tags)
      ..writeByte(9)..write(obj.subtaskTitles)
      ..writeByte(10)..write(obj.subtaskDone)
      ..writeByte(11)..write(obj.isRecurring)
      ..writeByte(12)..write(obj.recurringPattern)
      ..writeByte(13)..write(obj.createdAt)
      ..writeByte(14)..write(obj.completedAt)
      ..writeByte(15)..write(obj.archived);
  }
}
