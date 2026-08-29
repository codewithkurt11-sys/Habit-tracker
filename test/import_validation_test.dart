import 'dart:convert';

import 'package:flutter_app/logic/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _backup({
  int version = 5,
  Map<String, dynamic>? overrides,
}) {
  final data = <String, dynamic>{
    'format': 'yourself-backup',
    'version': version,
    'goals': <dynamic>[],
    'habits': <dynamic>[],
    'tasks': <dynamic>[],
    'notes': <dynamic>[],
    'finance': <dynamic>[],
  };
  if (overrides != null) data.addAll(overrides);
  return data;
}

void main() {
  group('AppState.validateBackup', () {
    test('accepts a valid current backup', () {
      expect(() => AppState.validateBackup(_backup()), returnsNormally);
    });

    test('accepts a valid older backup without optional collections', () {
      // v1-v3 backups predate savingsGoals/journal/schedule/quotes/focus.
      final old = _backup(version: 1);
      expect(old.containsKey('savingsGoals'), isFalse);
      expect(old.containsKey('journal'), isFalse);
      expect(() => AppState.validateBackup(old), returnsNormally);
    });

    test('rejects valid JSON that is not a Yourself backup', () {
      final notABackup =
          Map<String, dynamic>.from(jsonDecode('{"hello":"world"}') as Map);
      expect(
        () => AppState.validateBackup(notABackup),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a backup with the wrong format marker', () {
      final data = _backup()..['format'] = 'some-other-app';
      expect(
        () => AppState.validateBackup(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing or non-numeric version', () {
      expect(
        () => AppState.validateBackup(_backup()..remove('version')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppState.validateBackup(_backup()..['version'] = 'five'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unsupported future version', () {
      expect(
        () => AppState.validateBackup(_backup(version: 99)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing required collection', () {
      expect(
        () => AppState.validateBackup(_backup()..remove('habits')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a required collection that is not a list', () {
      expect(
        () => AppState.validateBackup(_backup()..['tasks'] = {'a': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed record inside a required collection', () {
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'habits': ['just a string']})),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a record missing its id', () {
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'goals': [{'title': 'No id'}]})),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed optional collection', () {
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'savingsGoals': 'not-a-list'})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'journal': [42]})),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed settings / financeBudget', () {
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'settings': 'nope'})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppState.validateBackup(
            _backup(overrides: {'financeBudget': <dynamic>[]})),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts a backup whose savings contribution arrays are malformed', () {
      // Structure-level validation passes; the parser normalizes the arrays.
      final data = _backup(overrides: {
        'savingsGoals': [
          {
            'id': 's1',
            'title': 'Savings',
            'targetAmount': 100,
            'targetDays': 10,
            'contributionDates': ['2026-01-01', '2026-01-02'],
            'contributionAmounts': [10],
          }
        ]
      });
      expect(() => AppState.validateBackup(data), returnsNormally);
    });
  });
}
