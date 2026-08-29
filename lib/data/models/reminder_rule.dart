import 'package:hive/hive.dart';

/// A reusable local reminder definition.
///
/// For tasks, [minutesBeforeDue] is used and [hour]/[minute] are ignored.
/// For habits, [minutesBeforeDue] should be 0 and [hour]/[minute] define the
/// time-of-day. [weekdays] uses ISO weekday numbers (1 = Monday..7 = Sunday).
class ReminderRule {
  final String id;
  final bool enabled;
  final int hour;
  final int minute;
  final int minutesBeforeDue;
  final List<int> weekdays;

  ReminderRule({
    required this.id,
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.minutesBeforeDue = 0,
    List<int>? weekdays,
  }) : weekdays = List.unmodifiable(
          (weekdays ?? const <int>[]).where((d) => d >= 1 && d <= 7).toSet().toList()..sort(),
        ),
        assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59),
        assert(minutesBeforeDue >= 0);

  ReminderRule copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? minutesBeforeDue,
    List<int>? weekdays,
  }) => ReminderRule(
        id: id,
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        minutesBeforeDue: minutesBeforeDue ?? this.minutesBeforeDue,
        weekdays: weekdays ?? this.weekdays,
      );

  String get summary {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    if (minutesBeforeDue > 0) return '$minutesBeforeDue min before due';
    return '$hh:$mm';
  }
}

class ReminderRuleAdapter extends TypeAdapter<ReminderRule> {
  @override
  final int typeId = 14;

  @override
  ReminderRule read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return ReminderRule(
      id: fields[0] as String,
      enabled: fields[1] as bool? ?? true,
      hour: (fields[2] as int? ?? 9).clamp(0, 23),
      minute: (fields[3] as int? ?? 0).clamp(0, 59),
      minutesBeforeDue: (fields[4] as int? ?? 0).clamp(0, 10080),
      weekdays: (fields[5] as List?)?.whereType<int>().toList() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, ReminderRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.enabled)
      ..writeByte(2)
      ..write(obj.hour)
      ..writeByte(3)
      ..write(obj.minute)
      ..writeByte(4)
      ..write(obj.minutesBeforeDue)
      ..writeByte(5)
      ..write(obj.weekdays);
  }
}
