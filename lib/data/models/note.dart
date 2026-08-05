import 'package:hive/hive.dart';

/// v2.0.0 Note: rich text body, entity linking, tags, attachments.
/// [linkedEntityType] can be 'habit', 'goal', 'finance', 'task', or 'none'.
/// [attachments] stores file paths (local).
class Note extends HiveObject {
  String id;
  String title;
  String body;
  List<String> attachments;
  String linkedEntityType; // 'habit','goal','finance','task','none'
  String? linkedEntityId;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    List<String>? attachments,
    this.linkedEntityType = 'none',
    this.linkedEntityId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : attachments = attachments ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({
    String? title,
    String? body,
    List<String>? attachments,
    String? linkedEntityType,
    String? linkedEntityId,
    bool clearLink = false,
    List<String>? tags,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      attachments: attachments ?? this.attachments,
      linkedEntityType: linkedEntityType ?? this.linkedEntityType,
      linkedEntityId: clearLink ? null : (linkedEntityId ?? this.linkedEntityId),
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
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
    // Backward compat: old fields 0-6, new fields 7+
    final oldHabitId = fields[4] as String?;
    final oldLinkedDate = fields[5] as DateTime?;
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      attachments: (fields[7] as List?)?.cast<String>() ?? [],
      linkedEntityType: oldHabitId != null ? 'habit' : (fields[8] as String? ?? 'none'),
      linkedEntityId: oldHabitId ?? fields[9] as String?,
      tags: (fields[10] as List?)?.cast<String>() ??
          (oldLinkedDate != null ? ['date:${oldLinkedDate.toIso8601String()}'] : []),
      createdAt: fields[11] as DateTime? ?? (fields[3] as DateTime?) ?? DateTime.now(),
      updatedAt: fields[12] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(7)
      ..write(obj.attachments)
      ..writeByte(8)
      ..write(obj.linkedEntityType)
      ..writeByte(9)
      ..write(obj.linkedEntityId)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }
}
