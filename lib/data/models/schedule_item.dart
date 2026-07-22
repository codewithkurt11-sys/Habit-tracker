import 'package:hive/hive.dart';

/// A one-off scheduled task, distinct from recurring [Habit]s.
class ScheduleItem extends HiveObject {
  String id;
  String title;
  DateTime dateTime;
  bool done;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.dateTime,
    this.done = false,
  });

  ScheduleItem copyWith({String? title, DateTime? dateTime, bool? done}) {
    return ScheduleItem(
      id: id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      done: done ?? this.done,
    );
  }
}

class ScheduleItemAdapter extends TypeAdapter<ScheduleItem> {
  @override
  final int typeId = 2;

  @override
  ScheduleItem read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleItem(
      id: fields[0] as String,
      title: fields[1] as String,
      dateTime: fields[2] as DateTime,
      done: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.dateTime)
      ..writeByte(3)
      ..write(obj.done);
  }
}
