import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/note.dart';

class NotesRepository {
  Box<Note> get _box => Hive.box<Note>(HiveBoxes.notes);
  final _uuid = const Uuid();

  List<Note> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<Note> getForEntity(String entityType, String entityId) {
    return getAll()
        .where((n) => n.linkedEntityType == entityType && n.linkedEntityId == entityId)
        .toList();
  }

  List<Note> getForTag(String tag) {
    return getAll().where((n) => n.tags.contains(tag)).toList();
  }

  List<Note> getRecent({int limit = 3}) {
    return getAll().take(limit).toList();
  }

  List<Note> search(String query) {
    if (query.isEmpty) return getAll();
    final lower = query.toLowerCase();
    return getAll().where((n) {
      return n.title.toLowerCase().contains(lower) ||
          n.body.toLowerCase().contains(lower) ||
          n.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }

  List<String> getAllTags() {
    final tags = <String>{};
    for (final n in getAll()) {
      tags.addAll(n.tags);
    }
    return tags.toList()..sort();
  }

  Future<Note> create({
    required String title,
    required String body,
    List<String>? attachments,
    String linkedEntityType = 'none',
    String? linkedEntityId,
    List<String>? tags,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      body: body,
      attachments: attachments,
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
      tags: tags,
    );
    await _box.put(note.id, note);
    return note;
  }

  Future<void> update(Note note) async {
    note.updatedAt = DateTime.now();
    await _box.put(note.id, note);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
