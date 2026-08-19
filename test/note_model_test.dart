import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/note.dart';

void main() {
  test('Note copyWith can explicitly clear a link', () {
    final note = Note(
      id: 'note-1',
      title: 'Linked',
      body: 'Body',
      timestamp: DateTime(2026, 8, 11),
      linkedEntityType: 'goal',
      linkedEntityId: 'goal-1',
    );

    final cleared = note.copyWith(clearLinkedEntity: true);

    expect(cleared.id, note.id);
    expect(cleared.linkedEntityType, isNull);
    expect(cleared.linkedEntityId, isNull);
  });

  test('Note copyWith does not mutate the original collections', () {
    final note = Note(
      id: 'note-2',
      title: 'Note',
      body: 'Body',
      timestamp: DateTime(2026, 8, 11),
      tags: ['one'],
      attachmentPaths: ['a.pdf'],
    );

    final copy = note.copyWith();
    copy.tags.add('two');
    copy.attachmentPaths.add('b.pdf');

    expect(note.tags, ['one']);
    expect(note.attachmentPaths, ['a.pdf']);
  });
}
