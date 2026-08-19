import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/journal_entry.dart';

void main() {
  test('JournalEntry copyWith updates editable fields and preserves identity', () {
    final created = DateTime(2026, 8, 10);
    final entry = JournalEntry(
      id: 'journal-1',
      title: 'Original',
      body: 'Body',
      moodIndex: 1,
      date: created,
      tags: ['school'],
      isFavorite: true,
      createdAt: created,
      updatedAt: created,
    );

    final updated = entry.copyWith(
      title: 'Updated',
      body: 'New body',
      moodIndex: -1,
      tags: ['reflection', 'school'],
      isFavorite: false,
    );

    expect(updated.id, 'journal-1');
    expect(updated.title, 'Updated');
    expect(updated.body, 'New body');
    expect(updated.moodIndex, -1);
    expect(updated.tags, ['reflection', 'school']);
    expect(updated.isFavorite, isFalse);
    expect(updated.createdAt, created);
    expect(updated.updatedAt.isAfter(created), isTrue);
  });

  test('JournalEntry copyWith does not share the original tag list', () {
    final entry = JournalEntry(
      id: 'journal-2',
      title: 'Entry',
      body: 'Body',
      date: DateTime(2026, 8, 10),
      tags: ['one'],
    );

    final copy = entry.copyWith();
    copy.tags.add('two');

    expect(entry.tags, ['one']);
    expect(copy.tags, ['one', 'two']);
  });
}
