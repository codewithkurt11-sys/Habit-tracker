import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum Mood { great, good, okay, low, rough }

extension MoodData on Mood {
  IconData get icon {
    switch (this) {
      case Mood.great:
        return Icons.sentiment_very_satisfied;
      case Mood.good:
        return Icons.sentiment_satisfied;
      case Mood.okay:
        return Icons.sentiment_neutral;
      case Mood.low:
        return Icons.sentiment_dissatisfied;
      case Mood.rough:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String get label {
    switch (this) {
      case Mood.great:
        return 'Great';
      case Mood.good:
        return 'Good';
      case Mood.okay:
        return 'Okay';
      case Mood.low:
        return 'Low';
      case Mood.rough:
        return 'Rough';
    }
  }
}

/// A free-form note. May optionally be linked to a habit and/or pinned
/// to a calendar date. [mood] is an optional emotional tag.
class Note extends HiveObject {
  String id;
  String title;
  String body;
  DateTime timestamp;
  String? habitId;
  DateTime? linkedDate;
  int moodIndex; // -1 means no mood set
  String folder;
  List<String> tags;
  List<String> attachmentPaths;
  String? linkedEntityType;
  String? linkedEntityId;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.habitId,
    this.linkedDate,
    this.moodIndex = -1,
    this.folder = 'Notes',
    List<String>? tags,
    List<String>? attachmentPaths,
    this.linkedEntityType,
    this.linkedEntityId,
  })  : tags = tags ?? [],
        attachmentPaths = attachmentPaths ?? [];

  Mood? get mood => moodIndex >= 0 && moodIndex < Mood.values.length
      ? Mood.values[moodIndex]
      : null;

  Note copyWith({
    String? title,
    String? body,
    DateTime? timestamp,
    String? habitId,
    bool clearHabitId = false,
    DateTime? linkedDate,
    bool clearLinkedDate = false,
    int? moodIndex,
    String? folder,
    List<String>? tags,
    List<String>? attachmentPaths,
    String? linkedEntityType,
    String? linkedEntityId,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      habitId: clearHabitId ? null : (habitId ?? this.habitId),
      linkedDate: clearLinkedDate ? null : (linkedDate ?? this.linkedDate),
      moodIndex: moodIndex ?? this.moodIndex,
      folder: folder ?? this.folder,
      tags: tags ?? List<String>.from(this.tags),
      attachmentPaths:
          attachmentPaths ?? List<String>.from(this.attachmentPaths),
      linkedEntityType: linkedEntityType ?? this.linkedEntityType,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
    );
  }
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      timestamp: fields[3] as DateTime,
      habitId: fields[4] as String?,
      linkedDate: fields[5] as DateTime?,
      moodIndex: fields[6] as int? ?? -1,
      folder: fields[7] as String? ?? 'Notes',
      tags: (fields[8] as List?)?.cast<String>() ?? [],
      attachmentPaths: (fields[9] as List?)?.cast<String>() ?? [],
      linkedEntityType: fields[10] as String?,
      linkedEntityId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.habitId)
      ..writeByte(5)
      ..write(obj.linkedDate)
      ..writeByte(6)
      ..write(obj.moodIndex)
      ..writeByte(7)
      ..write(obj.folder)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.attachmentPaths)
      ..writeByte(10)
      ..write(obj.linkedEntityType)
      ..writeByte(11)
      ..write(obj.linkedEntityId);
  }
}
