import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/journal_entry.dart';

class JournalRepository {
  Box<JournalEntry> get _box => Hive.box<JournalEntry>(HiveBoxes.journal);
  final _uuid = const Uuid();

  List<JournalEntry> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<JournalEntry> getFavorites() => getAll().where((e) => e.isFavorite).toList();

  JournalEntry? getForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    try {
      return _box.values.firstWhere((e) {
        final ed = DateTime(e.date.year, e.date.month, e.date.day);
        return ed.isAtSameMomentAs(d);
      });
    } catch (_) {
      return null;
    }
  }

  List<JournalEntry> search(String query) {
    final q = query.toLowerCase();
    return getAll().where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.body.toLowerCase().contains(q) ||
      e.tags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }

  Map<int, int> getMoodDistribution() {
    final map = <int, int>{};
    for (final e in getAll()) {
      if (e.moodIndex >= 0) {
        map[e.moodIndex] = (map[e.moodIndex] ?? 0) + 1;
      }
    }
    return map;
  }

  Future<JournalEntry> create({
    required String title,
    required String body,
    int moodIndex = -1,
    required DateTime date,
    List<String> tags = const [],
  }) async {
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: title,
      body: body,
      moodIndex: moodIndex,
      date: date,
      tags: List.from(tags),
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  Future<void> update(JournalEntry entry) async => _box.put(entry.id, entry);

  Future<void> delete(String id) async => _box.delete(id);

  Future<void> toggleFavorite(JournalEntry entry) async {
    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await _box.put(updated.id, updated);
  }
}
