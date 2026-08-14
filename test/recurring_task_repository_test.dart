import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/data/repositories/tasks_repository.dart';

void main() {
  late Directory dir;
  late TasksRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_tasks_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(TaskAdapter().typeId)) {
      Hive.registerAdapter(TaskAdapter());
    }
    await Hive.openBox<Task>('tasks_box');
    repo = TasksRepository();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('different recurring series with the same title can coexist', () async {
    final a = await repo.create(
      title: 'Push Ups',
      dueDate: DateTime(2026, 8, 17),
      isRecurring: true,
      recurringPattern: 'weekly',
    );
    final b = await repo.create(
      title: 'Push Ups',
      dueDate: DateTime(2026, 8, 17),
      isRecurring: true,
      recurringPattern: 'weekly',
    );

    expect(a.recurrenceSeriesId, isNotNull);
    expect(b.recurrenceSeriesId, isNotNull);
    expect(a.recurrenceSeriesId, isNot(b.recurrenceSeriesId));

    await repo.markDone(a);
    await repo.markDone(b);

    expect(repo.getForDate(DateTime(2026, 8, 24)).where((t) => t.title == 'Push Ups').length, 2);
  });

  test('same recurring series does not create a duplicate occurrence', () async {
    final task = await repo.create(
      title: 'Push Ups',
      dueDate: DateTime(2026, 8, 17),
      isRecurring: true,
      recurringPattern: 'weekly',
    );

    await repo.markDone(task);
    final countAfterFirst = repo.getForDate(DateTime(2026, 8, 24)).length;
    await repo.markDone(task);
    final countAfterSecond = repo.getForDate(DateTime(2026, 8, 24)).length;

    expect(countAfterFirst, 1);
    expect(countAfterSecond, 1);
  });

  test('completion generates the next occurrence through the repository path', () async {
    final task = await repo.create(
      title: 'Daily Push Ups',
      dueDate: DateTime(2026, 8, 14),
      isRecurring: true,
      recurringPattern: 'daily',
    );

    final next = await repo.markDone(task);

    expect(task.status, TaskStatus.done);
    expect(next, isNotNull);
    expect(next!.recurrenceSeriesId, task.recurrenceSeriesId);
    expect(next.dueDate, DateTime(2026, 8, 15));
  });

  test('overdue generation preserves the recurring series identity', () async {
    // Simulate: recurring task was completed but app crashed before
    // the next occurrence was generated. Use a past due date so the
    // next occurrence is actually overdue.
    final pastDate = DateTime.now().subtract(const Duration(days: 14));
    final task = await repo.create(
      title: 'Weekly Review',
      dueDate: pastDate,
      isRecurring: true,
      recurringPattern: 'weekly',
    );
    // Manually mark as done without generating next occurrence (simulates crash)
    task.status = TaskStatus.done;
    task.completedAt = DateTime.now();
    task.touch();
    await Hive.box<Task>('tasks_box').put(task.id, task);

    final created = await repo.generateOverdueOccurrences();
    expect(created, isNotEmpty);
    expect(created.first.recurrenceSeriesId, task.recurrenceSeriesId);
  });
}
