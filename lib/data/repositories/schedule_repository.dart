import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/schedule_item.dart';

class ScheduleRepository {
  Box<ScheduleItem> get _box => Hive.box<ScheduleItem>(HiveBoxes.schedule);
  final _uuid = const Uuid();

  List<ScheduleItem> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<ScheduleItem> getForToday() {
    final today = DateTime.now();
    return getAll().where((s) =>
      s.dateTime.year == today.year &&
      s.dateTime.month == today.month &&
      s.dateTime.day == today.day
    ).toList();
  }

  Future<ScheduleItem> create({
    required String title,
    required DateTime dateTime,
  }) async {
    final item = ScheduleItem(id: _uuid.v4(), title: title, dateTime: dateTime);
    await _box.put(item.id, item);
    return item;
  }

  Future<void> toggle(ScheduleItem item) async {
    final updated = item.copyWith(done: !item.done);
    await _box.put(item.id, updated);
  }

  Future<void> update(ScheduleItem item) async => _box.put(item.id, item);

  Future<void> delete(String id) async => _box.delete(id);
}
