import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/note.dart';

class NotesRepository {
  Box<Note> get _box => Hive.box<Note>(HiveBoxes.notes);
  final _uuid = const Uuid();

  List<Note> getAll({bool includeArchived = false}) {
    final list = includeArchived
        ? _box.values.toList()
        : _box.values.where((n) => !n.archived).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<Note> getForHabit(String habitId) {
    return getAll().where((n) => n.habitId == habitId).toList();
  }

  List<Note> getForEntity(String type, String id) => getAll()
      .where(
          (note) => note.linkedEntityType == type && note.linkedEntityId == id)
      .toList();

  List<Note> getForDate(DateTime date) {
    return getAll().where((n) {
      if (n.linkedDate == null) return false;
      return n.linkedDate!.year == date.year &&
          n.linkedDate!.month == date.month &&
          n.linkedDate!.day == date.day;
    }).toList();
  }

  /// Search notes by title or body (case-insensitive).
  List<Note> search(String query) {
    if (query.isEmpty) return getAll();
    final lower = query.toLowerCase();
    return getAll().where((n) {
      return n.title.toLowerCase().contains(lower) ||
          n.body.toLowerCase().contains(lower) ||
          n.tags.any((tag) => tag.toLowerCase().contains(lower)) ||
          n.folder.toLowerCase().contains(lower);
    }).toList();
  }

  bool hasNoteToday() {
    final now = DateTime.now();
    return _box.values.any(
      (n) =>
          n.timestamp.year == now.year &&
          n.timestamp.month == now.month &&
          n.timestamp.day == now.day,
    );
  }

  Future<Note> create({
    required String title,
    required String body,
    String? habitId,
    DateTime? linkedDate,
    int moodIndex = -1,
    String folder = 'Notes',
    List<String> tags = const [],
    List<String> attachmentPaths = const [],
    String? linkedEntityType,
    String? linkedEntityId,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      habitId: habitId,
      linkedDate: linkedDate,
      moodIndex: moodIndex,
      folder: folder,
      tags: List<String>.from(tags),
      attachmentPaths: List<String>.from(attachmentPaths),
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
    );
    await _box.put(note.id, note);
    return note;
  }

  List<Note> getArchived() {
    final list = _box.values.where((n) => n.archived).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> archive(String id) async {
    final note = _box.get(id);
    if (note == null) return;
    note.archived = true;
    await _box.put(note.id, note);
  }

  Future<void> unarchive(String id) async {
    final note = _box.get(id);
    if (note == null) return;
    note.archived = false;
    await _box.put(note.id, note);
  }

  Future<void> update(Note note) async {
    await _box.put(note.id, note);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
