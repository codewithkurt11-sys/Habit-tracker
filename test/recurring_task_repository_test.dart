import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/data/models/recurrence_rule.dart';
import 'package:flutter_app/data/models/reminder_rule.dart';
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
    if (!Hive.isAdapterRegistered(ReminderRuleAdapter().typeId)) {
      Hive.registerAdapter(ReminderRuleAdapter());
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
  test('selected weekdays recurrence advances to the next selected day',
      () async {
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
    const rule = RecurrenceRule(
      type: RecurrenceType.timesPerPeriod,
      occurrencesPerPeriod: 2,
      period: RecurrencePeriod.week,
      flexible: true,
    );
    final base = DateTime(2026, 8, 24); // Monday
    expect(rule.nextOccurrenceAfter(base, completedDates: [base]),
        DateTime(2026, 8, 25));
    expect(
      rule.nextOccurrenceAfter(base,
          completedDates: [base, DateTime(2026, 8, 25)]),
      DateTime(2026, 8, 31),
    );
  });

  test('monthly 31st skips February through repository completion', () async {
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
    expect(next!.dueDate, DateTime(2026, 3, 31));
  });

  final monthlyCases = <(String, int, DateTime, DateTime)>[
    (
      '31st skips normal February',
      31,
      DateTime(2026, 1, 31),
      DateTime(2026, 3, 31)
    ),
    (
      '31st skips leap February',
      31,
      DateTime(2024, 1, 31),
      DateTime(2024, 3, 31)
    ),
    (
      '30th skips normal February',
      30,
      DateTime(2026, 1, 30),
      DateTime(2026, 3, 30)
    ),
    (
      '30th skips leap February',
      30,
      DateTime(2024, 1, 30),
      DateTime(2024, 3, 30)
    ),
    (
      '29th includes leap February',
      29,
      DateTime(2024, 1, 29),
      DateTime(2024, 2, 29)
    ),
    (
      '29th skips normal February',
      29,
      DateTime(2026, 1, 29),
      DateTime(2026, 3, 29)
    ),
    (
      'leap February advances to March',
      29,
      DateTime(2024, 2, 29),
      DateTime(2024, 3, 29)
    ),
    (
      '28th includes normal February',
      28,
      DateTime(2026, 1, 28),
      DateTime(2026, 2, 28)
    ),
    ('31st skips April', 31, DateTime(2026, 3, 31), DateTime(2026, 5, 31)),
    ('30th includes April', 30, DateTime(2026, 3, 30), DateTime(2026, 4, 30)),
    ('April advances to May', 30, DateTime(2026, 4, 30), DateTime(2026, 5, 30)),
    (
      'December advances to January',
      31,
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 31)
    ),
  ];
  for (final (name, day, base, expected) in monthlyCases) {
    test('monthly date: $name', () {
      final rule =
          RecurrenceRule(type: RecurrenceType.monthlyDates, monthDays: [day]);
      expect(rule.nextOccurrenceAfter(base), expected);
    });
  }

  test('multiple monthly dates remain ordered within the same month', () {
    const rule = RecurrenceRule(
        type: RecurrenceType.monthlyDates, monthDays: [31, 15, 15, 1]);
    expect(rule.nextOccurrenceAfter(DateTime(2026, 1, 1, 23)),
        DateTime(2026, 1, 15));
    expect(
        rule.nextOccurrenceAfter(DateTime(2026, 1, 15)), DateTime(2026, 1, 31));
    expect(
        rule.nextOccurrenceAfter(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
    expect(
        rule.nextOccurrenceAfter(DateTime(2026, 2, 15)), DateTime(2026, 3, 1));
  });

  test('future monthly start skips invalid dates without clamping', () {
    for (final day in [29, 30, 31]) {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthlyDates,
        monthDays: [day],
        startDate: DateTime(2026, 2, 1),
      );
      expect(rule.nextOccurrenceAfter(DateTime(2026, 1, 1)),
          DateTime(2026, 3, day));
    }
    final leapRule = RecurrenceRule(
      type: RecurrenceType.monthlyDates,
      monthDays: [29],
      startDate: DateTime(2024, 2, 1),
    );
    expect(leapRule.nextOccurrenceAfter(DateTime(2024, 1, 1)),
        DateTime(2024, 2, 29));
  });

  test('monthly skipped dates respect an end date in February', () {
    final rule = RecurrenceRule(
      type: RecurrenceType.monthlyDates,
      monthDays: [31],
      endDate: DateTime(2026, 2, 28),
    );
    expect(rule.nextOccurrenceAfter(DateTime(2026, 1, 31)), isNull);
    expect(
        rule
            .copyWith(startDate: DateTime(2026, 2, 1))
            .nextOccurrenceAfter(DateTime(2026, 1, 31)),
        isNull);
  });

  test('nth and last weekday recurrence retain their existing behavior', () {
    const secondMonday = RecurrenceRule(
      type: RecurrenceType.monthlyDates,
      nthWeekday: 2,
      nthWeekdayDay: DateTime.monday,
    );
    const lastFriday = RecurrenceRule(
      type: RecurrenceType.monthlyDates,
      nthWeekday: -1,
      nthWeekdayDay: DateTime.friday,
    );
    const fifthMonday = RecurrenceRule(
      type: RecurrenceType.monthlyDates,
      nthWeekday: 5,
      nthWeekdayDay: DateTime.monday,
    );
    expect(secondMonday.nextOccurrenceAfter(DateTime(2026, 1, 12)),
        DateTime(2026, 2, 9));
    expect(lastFriday.nextOccurrenceAfter(DateTime(2026, 1, 30)),
        DateTime(2026, 2, 27));
    expect(fifthMonday.nextOccurrenceAfter(DateTime(2026, 1, 1)),
        DateTime(2026, 3, 30));
    expect(
        lastFriday
            .copyWith(startDate: DateTime(2026, 2, 1))
            .nextOccurrenceAfter(DateTime(2026, 1, 1)),
        DateTime(2026, 2, 27));
  });

  test(
      'completion and catch-up preserve category, reminders and monthly metadata',
      () async {
    final original = await repo.create(
      title: 'Monthly report',
      dueDate: DateTime(2024, 1, 31),
      dueTime: DateTime(2024, 1, 31, 16, 30),
      isRecurring: true,
      category: TaskCategory.work,
      customCategoryId: 'reports',
      recurrenceRule: RecurrenceRule(
        type: RecurrenceType.monthlyDates,
        monthDays: [31],
        startDate: DateTime(2024, 1, 31),
      ),
      reminders: [ReminderRule(id: 'before', minutesBeforeDue: 30)],
    );
    final next = (await repo.markDone(original))!;
    expect(next.dueDate, DateTime(2024, 3, 31));
    // Simulate a completed occurrence whose successor was not saved.
    next.status = TaskStatus.done;
    await repo.update(next);
    final caughtUp = await repo.generateOverdueOccurrences();
    expect(caughtUp, hasLength(1));
    expect(caughtUp.single.dueDate, DateTime(2024, 5, 31));
    expect(await repo.generateOverdueOccurrences(), isEmpty);

    await Hive.box<Task>('tasks_box').close();
    await Hive.openBox<Task>('tasks_box');
    for (final id in [next.id, caughtUp.single.id]) {
      final stored = repo.getById(id)!;
      expect(stored.recurrenceSeriesId, original.recurrenceSeriesId);
      expect(stored.isRecurring, isTrue);
      expect(stored.recurrenceRule!.monthDays, [31]);
      expect(stored.recurrenceRule!.startDate, DateTime(2024, 1, 31));
      expect(stored.customCategoryId, 'reports');
      expect(stored.category, TaskCategory.work);
      expect(stored.dueTime, original.dueTime);
      expect(stored.reminders.single.id, 'before');
      expect(stored.reminders.single.minutesBeforeDue, 30);
    }
  });

  test('recurrence end date prevents creating an occurrence after the end',
      () async {
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

  test(
      'interval recurrence (every X days/weeks/months) still advances when '
      'the completion date is before the rule start date', () async {
    // Regression test: RecurrenceRule._matches() for RecurrenceType.interval
    // always returned false, which made _firstOnOrAfter() scan up to 3660
    // days and return null whenever the base date was before startDate
    // (e.g. after editing the recurrence's start date, or restoring a
    // backup where the task's dueDate lags behind the rule's startDate).
    // This silently and permanently stopped "every X days/weeks/months"
    // recurring tasks from ever generating another occurrence.
    final task = await repo.create(
      title: 'Every 3 days',
      dueDate: DateTime(2026, 1, 1),
      isRecurring: true,
      recurrenceRule: RecurrenceRule(
        type: RecurrenceType.interval,
        interval: 3,
        intervalUnit: RecurrenceIntervalUnit.days,
        startDate: DateTime(2026, 1, 10),
      ),
      recurringPattern: 'advanced',
    );
    final next = await repo.markDone(task);
    expect(next, isNotNull);
    expect(next!.dueDate, DateTime(2026, 1, 10));
  });

  test(
      'interval recurrence in weeks advances correctly from a future start date',
      () async {
    const rule = RecurrenceRule(
      type: RecurrenceType.interval,
      interval: 2,
      intervalUnit: RecurrenceIntervalUnit.weeks,
      startDate: null,
    );
    final ruleWithStart = rule.copyWith(startDate: DateTime(2026, 1, 10));
    final next = ruleWithStart.nextOccurrenceAfter(DateTime(2026, 1, 1));
    expect(next, DateTime(2026, 1, 10));
  });

  test(
      'interval recurrence in months advances correctly from a future start date',
      () async {
    const rule = RecurrenceRule(
      type: RecurrenceType.interval,
      interval: 1,
      intervalUnit: RecurrenceIntervalUnit.months,
    );
    final ruleWithStart = rule.copyWith(startDate: DateTime(2026, 3, 15));
    final next = ruleWithStart.nextOccurrenceAfter(DateTime(2026, 1, 1));
    expect(next, DateTime(2026, 3, 15));
  });
}
