import 'package:hive/hive.dart';

enum FocusType { pomodoro, shortBreak, longBreak, stopwatch, countdown }

extension FocusTypeExt on FocusType {
  String get label {
    switch (this) {
      case FocusType.pomodoro: return 'Pomodoro';
      case FocusType.shortBreak: return 'Short Break';
      case FocusType.longBreak: return 'Long Break';
      case FocusType.stopwatch: return 'Stopwatch';
      case FocusType.countdown: return 'Countdown';
    }
  }

  int get defaultSeconds {
    switch (this) {
      case FocusType.pomodoro: return 25 * 60;
      case FocusType.shortBreak: return 5 * 60;
      case FocusType.longBreak: return 15 * 60;
      case FocusType.stopwatch: return 0;
      case FocusType.countdown: return 60 * 60;
    }
  }
}

class FocusSession extends HiveObject {
  String id;
  int typeIndex;
  int durationSeconds; // planned
  int completedSeconds; // actually focused
  bool completed;
  DateTime startedAt;
  String? taskTitle;

  FocusSession({
    required this.id,
    required this.typeIndex,
    required this.durationSeconds,
    this.completedSeconds = 0,
    this.completed = false,
    required this.startedAt,
    this.taskTitle,
  });

  FocusType get type =>
      FocusType.values[typeIndex.clamp(0, FocusType.values.length - 1)];
}

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 10;

  @override
  FocusSession read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return FocusSession(
      id: fields[0] as String,
      typeIndex: fields[1] as int,
      durationSeconds: fields[2] as int,
      completedSeconds: fields[3] as int? ?? 0,
      completed: fields[4] as bool? ?? false,
      startedAt: fields[5] as DateTime,
      taskTitle: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.typeIndex)
      ..writeByte(2)..write(obj.durationSeconds)
      ..writeByte(3)..write(obj.completedSeconds)
      ..writeByte(4)..write(obj.completed)
      ..writeByte(5)..write(obj.startedAt)
      ..writeByte(6)..write(obj.taskTitle);
  }
}
