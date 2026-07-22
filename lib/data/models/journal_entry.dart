import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum JournalMood { amazing, good, okay, bad, terrible }

extension JournalMoodExt on JournalMood {
  String get label {
    switch (this) {
      case JournalMood.amazing: return 'Amazing';
      case JournalMood.good: return 'Good';
      case JournalMood.okay: return 'Okay';
      case JournalMood.bad: return 'Bad';
      case JournalMood.terrible: return 'Terrible';
    }
  }

  String get emoji {
    switch (this) {
      case JournalMood.amazing: return '🤩';
      case JournalMood.good: return '😊';
      case JournalMood.okay: return '😐';
      case JournalMood.bad: return '😔';
      case JournalMood.terrible: return '😢';
    }
  }

  Color get color {
    switch (this) {
      case JournalMood.amazing: return const Color(0xFF6B9080);
      case JournalMood.good: return const Color(0xFFA8C09A);
      case JournalMood.okay: return const Color(0xFFE8C56F);
      case JournalMood.bad: return const Color(0xFFE8946F);
      case JournalMood.terrible: return const Color(0xFFD4675A);
    }
  }

  IconData get icon {
    switch (this) {
      case JournalMood.amazing: return Icons.sentiment_very_satisfied;
      case JournalMood.good: return Icons.sentiment_satisfied;
      case JournalMood.okay: return Icons.sentiment_neutral;
      case JournalMood.bad: return Icons.sentiment_dissatisfied;
      case JournalMood.terrible: return Icons.sentiment_very_dissatisfied;
    }
  }
}

class JournalEntry extends HiveObject {
  String id;
  String title;
  String body;
  int moodIndex; // -1 = no mood
  DateTime date;
  List<String> tags;
  bool isFavorite;
  DateTime createdAt;
  DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.title,
    required this.body,
    this.moodIndex = -1,
    required this.date,
    List<String>? tags,
    this.isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  JournalMood? get mood => moodIndex >= 0 && moodIndex < JournalMood.values.length
      ? JournalMood.values[moodIndex]
      : null;

  JournalEntry copyWith({
    String? title,
    String? body,
    int? moodIndex,
    DateTime? date,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      moodIndex: moodIndex ?? this.moodIndex,
      date: date ?? this.date,
      tags: tags ?? List.from(this.tags),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 6;

  @override
  JournalEntry read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      moodIndex: fields[3] as int? ?? -1,
      date: fields[4] as DateTime,
      tags: (fields[5] as List?)?.cast<String>() ?? [],
      isFavorite: fields[6] as bool? ?? false,
      createdAt: fields[7] as DateTime? ?? DateTime.now(),
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.body)
      ..writeByte(3)..write(obj.moodIndex)
      ..writeByte(4)..write(obj.date)
      ..writeByte(5)..write(obj.tags)
      ..writeByte(6)..write(obj.isFavorite)
      ..writeByte(7)..write(obj.createdAt)
      ..writeByte(8)..write(obj.updatedAt);
  }
}
