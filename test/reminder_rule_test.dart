import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/reminder_rule.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_reminder_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(ReminderRuleAdapter().typeId)) {
      Hive.registerAdapter(ReminderRuleAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('normalizes invalid weekday values and removes duplicates', () {
    final rule = ReminderRule(
      id: 'r1',
      weekdays: [7, 2, 2, 0, 8],
    );
    expect(rule.weekdays, [2, 7]);
  });

  test('round-trips through Hive adapter', () async {
    final box = await Hive.openBox<ReminderRule>('reminders');
    final original = ReminderRule(
      id: 'r1',
      enabled: false,
      hour: 22,
      minute: 30,
      minutesBeforeDue: 15,
      weekdays: [1, 3, 5],
    );
    await box.put(original.id, original);
    final restored = box.get(original.id)!;
    expect(restored.id, original.id);
    expect(restored.enabled, false);
    expect(restored.hour, 22);
    expect(restored.minute, 30);
    expect(restored.minutesBeforeDue, 15);
    expect(restored.weekdays, [1, 3, 5]);
  });
}
