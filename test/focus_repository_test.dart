import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/focus_session.dart';
import 'package:flutter_app/data/repositories/focus_repository.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_focus_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(FocusSessionAdapter().typeId)) {
      Hive.registerAdapter(FocusSessionAdapter());
    }
    await Hive.openBox<FocusSession>('focus_box');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('stopwatch is completed when it has positive elapsed time', () async {
    final repo = FocusRepository();
    final session = await repo.startSession(
      typeIndex: FocusType.stopwatch.index,
      durationSeconds: 0,
    );
    await repo.completeSession(session, 42);
    expect(repo.getCompleted(), hasLength(1));
    expect(repo.getCompleted().single.type, FocusType.stopwatch);
  });

  test('countdown requires the existing 80 percent completion threshold', () async {
    final repo = FocusRepository();
    final session = await repo.startSession(
      typeIndex: FocusType.countdown.index,
      durationSeconds: 600,
    );
    await repo.completeSession(session, 479);
    expect(repo.getCompleted(), isEmpty);
    await repo.completeSession(session, 480);
    expect(repo.getCompleted(), hasLength(1));
  });
}
