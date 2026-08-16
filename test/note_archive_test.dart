import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/note.dart';

void main() {
  group('Note archived field', () {
    test('default archived is false', () {
      final note = Note(
        id: 'n1',
        title: 'Test',
        body: 'Body',
        timestamp: DateTime.now(),
      );
      expect(note.archived, false);
    });

    test('archived can be set to true', () {
      final note = Note(
        id: 'n2',
        title: 'Test',
        body: 'Body',
        timestamp: DateTime.now(),
        archived: true,
      );
      expect(note.archived, true);
    });
  });

  group('Note copyWith', () {
    test('copyWith preserves timestamp (does not auto-update)', () {
      final originalTime = DateTime(2025, 1, 1);
      final note = Note(
        id: 'n3',
        title: 'Original',
        body: 'Body',
        timestamp: originalTime,
      );
      final copied = note.copyWith(title: 'Updated');
      // Timestamp should be preserved, not changed to now
      expect(copied.timestamp, originalTime);
      expect(copied.title, 'Updated');
    });

    test('copyWith can explicitly set timestamp', () {
      final originalTime = DateTime(2025, 1, 1);
      final newTime = DateTime(2025, 6, 15);
      final note = Note(
        id: 'n4',
        title: 'Original',
        body: 'Body',
        timestamp: originalTime,
      );
      final copied = note.copyWith(timestamp: newTime);
      expect(copied.timestamp, newTime);
    });

    test('copyWith can set archived', () {
      final note = Note(
        id: 'n5',
        title: 'Test',
        body: 'Body',
        timestamp: DateTime.now(),
      );
      final copied = note.copyWith(archived: true);
      expect(copied.archived, true);
    });

    test('copyWith preserves archived when not specified', () {
      final note = Note(
        id: 'n6',
        title: 'Test',
        body: 'Body',
        timestamp: DateTime.now(),
        archived: true,
      );
      final copied = note.copyWith(title: 'Updated');
      expect(copied.archived, true);
    });

    test('copyWith clears habitId when clearHabitId is true', () {
      final note = Note(
        id: 'n7',
        title: 'Test',
        body: 'Body',
        timestamp: DateTime.now(),
        habitId: 'habit123',
      );
      final copied = note.copyWith(clearHabitId: true);
      expect(copied.habitId, isNull);
    });
  });
}
