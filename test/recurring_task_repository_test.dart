import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/data/models/recurrence_rule.dart';
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
    if (!Hive.isAdapterRegistered(RecurrenceRuleAdapter().typeId)) {
      Hive.registerAdapter(RecurrenceRuleAdapter());
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

    expect(
        repo
            .getForDate(DateTime(2026, 8, 24))
            .where((t) => t.title == 'Push Ups')
            .length,
        2);
  });

  test('same recurring series does not create a duplicate occurrence',
      () async {
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

  test('completion generates the next occurrence through the repository path',
      () async {
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

  test('legacy series identity is stable and prevents duplicate occurrences',
      () async {
    final firstSeriesId = Task.legacySeriesId(
      title: 'Legacy review',
      recurringPattern: 'weekly',
    );
    final sameSeriesId = Task.legacySeriesId(
      title: 'Legacy review',
      recurringPattern: 'weekly',
    );
    final differentSeriesId = Task.legacySeriesId(
      title: 'Different review',
      recurringPattern: 'weekly',
    );
    expect(sameSeriesId, firstSeriesId);
    expect(differentSeriesId, isNot(firstSeriesId));

    final first = Task(
      id: 'legacy-1',
      title: 'Legacy review',
      dueDate: DateTime(2026, 8, 17),
      isRecurring: true,
      recurringPattern: 'weekly',
      recurrenceSeriesId: firstSeriesId,
    );
    final existingNext = Task(
      id: 'legacy-2',
      title: 'Legacy review',
      dueDate: DateTime(2026, 8, 24),
      isRecurring: true,
      recurringPattern: 'weekly',
      recurrenceSeriesId: sameSeriesId,
    );
    await Hive.box<Task>('tasks_box').putAll({
      first.id: first,
      existingNext.id: existingNext,
    });

    expect(await repo.markDone(first), isNull);
    expect(
      repo
          .getForDate(DateTime(2026, 8, 24))
          .where((task) => task.recurrenceSeriesId == firstSeriesId),
      hasLength(1),
    );
  });
  test('selected weekdays recurrence advances to the next selected day', () async {
    final task = await repo.create(
      title: 'Study',
      dueDate: DateTime(2026, 8, 24), // Monday
      isRecurring: true,
      recurrenceRule: const RecurrenceRule(
        type: RecurrenceType.weeklyDays,
        weekdays: [1, 3, 5],
      ),
      recurringPattern: 'advanced',
    );
    final next = await repo.markDone(task);
    expect(next, isNotNull);
    expect(next!.dueDate, DateTime(2026, 8, 26));
  });


  test('times-per-period respects the period limit', () async {
    final rule = const RecurrenceRule(
      type: RecurrenceType.timesPerPeriod,
      occurrencesPerPeriod: 2,
      period: RecurrencePeriod.week,
      flexible: true,
    );
    final base = DateTime(2026, 8, 24); // Monday
    expect(rule.nextOccurrenceAfter(base, completedDates: [base]), DateTime(2026, 8, 25));
    expect(
      rule.nextOccurrenceAfter(base, completedDates: [base, DateTime(2026, 8, 25)]),
      DateTime(2026, 8, 31),
    );
  });

  test('monthly date recurrence handles short months', () async {
    final task = await repo.create(
      title: 'Monthly report',
      dueDate: DateTime(2026, 1, 31),
      isRecurring: true,
      recurrenceRule: const RecurrenceRule(
        type: RecurrenceType.monthlyDates,
        monthDays: [31],
      ),
      recurringPattern: 'advanced',
    );
    final next = await repo.markDone(task);
    expect(next, isNotNull);
    expect(next!.dueDate, DateTime(2026, 2, 28));
  });

  test('recurrence end date prevents creating an occurrence after the end', () async {
    final task = await repo.create(
      title: 'Limited run',
      dueDate: DateTime(2026, 8, 28),
      isRecurring: true,
      recurrenceRule: RecurrenceRule(
        type: RecurrenceType.daily,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 28),
      ),
      recurringPattern: 'advanced',
    );
    final next = await repo.markDone(task);
    expect(next, isNull);
  });

}
