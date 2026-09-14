import 'dart:async';

import 'package:flutter_app/logic/app_state.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Overrides only the two startup operations; exercises the same orchestration
/// used by HabitTrackerApp rather than reproducing its try/catch in the test.
class _StartupState extends AppState {
  final Future<void> Function() process;
  final Future<void> Function() initialize;

  _StartupState({required this.process, required this.initialize});

  @override
  Future<void> processRecurringTasks() => process();

  @override
  Future<void> initNotifications() => initialize();
}

void main() {
  test('notification initialization waits for successful recurrence processing',
      () async {
    final recurrence = Completer<void>();
    final notifications = Completer<void>();
    final events = <String>[];
    final state = _StartupState(
      process: () async {
        events.add('recurrence started');
        await recurrence.future;
        events.add('recurrence completed');
      },
      initialize: () async {
        events.add('notifications started');
        await notifications.future;
        events.add('notifications completed');
      },
    );
    addTearDown(state.dispose);

    var startupCompleted = false;
    final startup =
        initializeStartup(state).then((_) => startupCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['recurrence started']);
    expect(startupCompleted, isFalse);

    recurrence.complete();
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      'recurrence started',
      'recurrence completed',
      'notifications started',
    ]);
    expect(startupCompleted, isFalse);

    notifications.complete();
    await startup;
    expect(events.last, 'notifications completed');
    expect(startupCompleted, isTrue);
  });

  test('a forced recurrence failure still initializes notifications afterward',
      () async {
    final recurrence = Completer<void>();
    final events = <String>[];
    final failure = StateError('forced recurring-processing failure');
    Object? recurringError;
    final state = _StartupState(
      process: () async {
        events.add('recurrence started');
        try {
          await recurrence.future;
        } catch (error) {
          recurringError = error;
          events.add('recurrence failed');
          rethrow;
        }
      },
      initialize: () async => events.add('notifications initialized'),
    );
    addTearDown(state.dispose);

    final startup = initializeStartup(state);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['recurrence started']);
    recurrence.completeError(failure, StackTrace.current);
    await startup;

    expect(recurringError, same(failure));
    expect(events, [
      'recurrence started',
      'recurrence failed',
      'notifications initialized',
    ]);
  });

  test('a synchronous recurrence throw cannot skip notification initialization',
      () async {
    final events = <String>[];
    final state = _StartupState(
      process: () {
        events.add('recurrence failed');
        throw StateError('synchronous failure');
      },
      initialize: () async => events.add('notifications initialized'),
    );
    addTearDown(state.dispose);

    await initializeStartup(state);
    expect(events, ['recurrence failed', 'notifications initialized']);
  });

  test('notification failure is handled independently of recurrence failure',
      () async {
    final events = <String>[];
    final state = _StartupState(
      process: () async {
        events.add('recurrence failed');
        throw StateError('recurrence failure');
      },
      initialize: () async {
        events.add('notifications failed');
        throw StateError('notification failure');
      },
    );
    addTearDown(state.dispose);

    await expectLater(initializeStartup(state), completes);
    expect(events, ['recurrence failed', 'notifications failed']);
  });
}
