import 'package:hive/hive.dart';

enum RecurrenceType {
  daily,
  weeklyDays,
  monthlyDates,
  yearlyDate,
  interval,
  timesPerPeriod,
  alternate,
}

enum RecurrenceIntervalUnit { days, weeks, months }

enum RecurrencePeriod { week, month, year }

/// A structured recurrence definition used by recurring tasks.
///
/// Legacy tasks still use [Task.recurringPattern]. A rule is optional so
/// existing Hive data remains fully readable and can continue to behave as
/// before until the task is edited.
class RecurrenceRule {
  final RecurrenceType type;
  final int interval;
  final RecurrenceIntervalUnit intervalUnit;
  final List<int> weekdays; // ISO: 1 = Monday ... 7 = Sunday.
  final List<int> monthDays; // 1 ... 31.
  final int? month; // 1 ... 12, used by yearlyDate.
  final int? dayOfMonth; // used by yearlyDate.
  final int? nthWeekday; // 1 ... 5, -1 = last; used by monthlyDates.
  final int? nthWeekdayDay; // ISO weekday, used by monthlyDates.
  final RecurrencePeriod? period;
  final int? occurrencesPerPeriod;
  final int activeDays;
  final int restDays;
  final bool flexible;
  final DateTime? startDate;
  final DateTime? endDate;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.intervalUnit = RecurrenceIntervalUnit.days,
    this.weekdays = const [],
    this.monthDays = const [],
    this.month,
    this.dayOfMonth,
    this.nthWeekday,
    this.nthWeekdayDay,
    this.period,
    this.occurrencesPerPeriod,
    this.activeDays = 1,
    this.restDays = 1,
    this.flexible = false,
    this.startDate,
    this.endDate,
  }) : assert(interval > 0),
       assert(activeDays > 0),
       assert(restDays >= 0),
       assert(occurrencesPerPeriod == null || occurrencesPerPeriod > 0);

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    RecurrenceIntervalUnit? intervalUnit,
    List<int>? weekdays,
    List<int>? monthDays,
    int? month,
    int? dayOfMonth,
    int? nthWeekday,
    int? nthWeekdayDay,
    RecurrencePeriod? period,
    int? occurrencesPerPeriod,
    int? activeDays,
    int? restDays,
    bool? flexible,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      weekdays: List<int>.from(weekdays ?? this.weekdays),
      monthDays: List<int>.from(monthDays ?? this.monthDays),
      month: month ?? this.month,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nthWeekday: nthWeekday ?? this.nthWeekday,
      nthWeekdayDay: nthWeekdayDay ?? this.nthWeekdayDay,
      period: period ?? this.period,
      occurrencesPerPeriod: occurrencesPerPeriod ?? this.occurrencesPerPeriod,
      activeDays: activeDays ?? this.activeDays,
      restDays: restDays ?? this.restDays,
      flexible: flexible ?? this.flexible,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  String get summary {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case RecurrenceType.weeklyDays:
        final names = weekdays.map(_weekdayName).join(', ');
        return interval == 1
            ? 'Weekly: $names'
            : 'Every $interval weeks: $names';
      case RecurrenceType.monthlyDates:
        if (monthDays.isNotEmpty) {
          return 'Monthly: ${monthDays.join(', ')}';
        }
        if (nthWeekday != null && nthWeekdayDay != null) {
          final ordinal = nthWeekday == -1 ? 'last' : _ordinal(nthWeekday!);
          return 'Monthly: $ordinal ${_weekdayName(nthWeekdayDay!)}';
        }
        return 'Monthly';
      case RecurrenceType.yearlyDate:
        return 'Yearly: ${month ?? 1}/${dayOfMonth ?? 1}';
      case RecurrenceType.interval:
        final unit = intervalUnit.name;
        return 'Every $interval $unit';
      case RecurrenceType.timesPerPeriod:
        final p = period?.name ?? RecurrencePeriod.week.name;
        return '${occurrencesPerPeriod ?? 1} time(s) per $p${flexible ? ' (flexible)' : ''}';
      case RecurrenceType.alternate:
        return '$activeDays active day(s), $restDays rest day(s)';
    }
  }

  /// Returns the next date strictly after [base].
  /// [completedDates] is used for flexible "N times per period" schedules.
  DateTime? nextOccurrenceAfter(
    DateTime base, {
    List<DateTime> completedDates = const [],
  }) {
    final normalizedBase = _dateOnly(base);
    final start = startDate == null ? null : _dateOnly(startDate!);
    final end = endDate == null ? null : _dateOnly(endDate!);
    if (start != null && normalizedBase.isBefore(start)) {
      return _firstOnOrAfter(start, end: end);
    }

    DateTime? candidate;
    switch (type) {
      case RecurrenceType.daily:
        candidate = _datePlus(normalizedBase, interval);
        break;

      case RecurrenceType.weeklyDays:
        candidate = _nextWeeklyDay(normalizedBase, start ?? normalizedBase);
        break;

      case RecurrenceType.monthlyDates:
        candidate = _nextMonthlyDate(normalizedBase);
        break;

      case RecurrenceType.yearlyDate:
        candidate = _nextYearlyDate(normalizedBase);
        break;

      case RecurrenceType.interval:
        candidate = _addInterval(normalizedBase);
        break;

      case RecurrenceType.timesPerPeriod:
        candidate = _nextTimesPerPeriod(
          normalizedBase,
          completedDates,
        );
        break;

      case RecurrenceType.alternate:
        candidate = _nextAlternate(normalizedBase, start ?? normalizedBase);
        break;
    }

    if (candidate == null) return null;
    candidate = _dateOnly(candidate);
    if (start != null && candidate.isBefore(start)) {
      candidate = _firstOnOrAfter(start, end: end);
    }
    if (end != null && candidate.isAfter(end)) return null;
    return candidate;
  }

  DateTime? _firstOnOrAfter(DateTime start, {DateTime? end}) {
    var cursor = _dateOnly(start);
    for (var i = 0; i < 3660; i++) {
      if (end != null && cursor.isAfter(end)) return null;
      if (_matches(cursor, start)) return cursor;
      cursor = _datePlus(cursor, 1);
    }
    return null;
  }

  bool _matches(DateTime date, DateTime anchor) {
    switch (type) {
      case RecurrenceType.daily:
        final diff = date.difference(anchor).inDays;
        return diff >= 0 && diff % interval == 0;
      case RecurrenceType.weeklyDays:
        if (!weekdays.contains(date.weekday)) return false;
        final diffWeeks = date.difference(_startOfWeek(anchor)).inDays ~/ 7;
        return diffWeeks >= 0 && diffWeeks % interval == 0;
      case RecurrenceType.monthlyDates:
        if (monthDays.isNotEmpty && !monthDays.contains(date.day)) return false;
        if (nthWeekday != null && nthWeekdayDay != null &&
            !_isNthWeekdayOfMonth(date, nthWeekdayDay!, nthWeekday!)) {
          return false;
        }
        return date.year > anchor.year ||
            (date.year == anchor.year && date.month >= anchor.month);
      case RecurrenceType.yearlyDate:
        return date.month == (month ?? 1) && date.day == (dayOfMonth ?? 1);
      case RecurrenceType.interval:
        return false;
      case RecurrenceType.timesPerPeriod:
        return true;
      case RecurrenceType.alternate:
        return _isActiveDay(date, anchor);
    }
  }

  DateTime? _nextWeeklyDay(DateTime base, DateTime anchor) {
    final selected = weekdays.isEmpty ? <int>[base.weekday] : (weekdays.toSet().toList()..sort());
    for (var offset = 1; offset <= 3700; offset++) {
      final candidate = _datePlus(base, offset);
      if (!selected.contains(candidate.weekday)) continue;
      final weekDiff = candidate.difference(_startOfWeek(anchor)).inDays ~/ 7;
      if (weekDiff >= 0 && weekDiff % interval == 0) return candidate;
    }
    return null;
  }

  DateTime? _nextMonthlyDate(DateTime base) {
    var cursor = DateTime(base.year, base.month + 1, 1);
    for (var m = 0; m < 121; m++) {
      if (monthDays.isNotEmpty) {
        final sorted = monthDays.where((d) => d >= 1 && d <= 31).toSet().toList()..sort();
        for (final day in sorted) {
          final last = DateTime(cursor.year, cursor.month + 1, 0).day;
          if (day <= last) return DateTime(cursor.year, cursor.month, day);
        }
      }
      if (nthWeekday != null && nthWeekdayDay != null) {
        final date = _nthWeekdayInMonth(cursor.year, cursor.month, nthWeekdayDay!, nthWeekday!);
        if (date != null) return date;
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return null;
  }

  DateTime? _nextYearlyDate(DateTime base) {
    final targetMonth = (month ?? 1).clamp(1, 12).toInt();
    final rawDay = (dayOfMonth ?? 1).clamp(1, 31).toInt();
    DateTime safeCandidate(int year) {
      final maxDay = DateTime(year, targetMonth + 1, 0).day;
      return DateTime(year, targetMonth, rawDay.clamp(1, maxDay).toInt());
    }
    var candidate = safeCandidate(base.year);
    if (!candidate.isAfter(base)) candidate = safeCandidate(base.year + 1);
    return candidate;
  }

  DateTime _addInterval(DateTime base) {
    switch (intervalUnit) {
      case RecurrenceIntervalUnit.days:
        return _datePlus(base, interval);
      case RecurrenceIntervalUnit.weeks:
        return _datePlus(base, interval * 7);
      case RecurrenceIntervalUnit.months:
        final target = DateTime(base.year, base.month + interval, 1);
        final last = DateTime(target.year, target.month + 1, 0).day;
        return DateTime(target.year, target.month, base.day.clamp(1, last).toInt());
    }
  }

  DateTime? _nextTimesPerPeriod(
    DateTime base,
    List<DateTime> completedDates,
  ) {
    final target = (occurrencesPerPeriod ?? 1).clamp(1, 366).toInt();
    final currentPeriod = period ?? RecurrencePeriod.week;
    final currentPeriodStart = _periodStart(base, currentPeriod);
    final count = completedDates
        .map(_dateOnly)
        .where((d) => _samePeriod(d, currentPeriodStart, currentPeriod))
        .toSet()
        .length;

    if (count >= target) {
      return _nextPeriodStart(currentPeriodStart, currentPeriod);
    }

    if (!flexible && weekdays.isNotEmpty) {
      for (var offset = 1; offset <= 366; offset++) {
        final candidate = _datePlus(base, offset);
        if (!_samePeriod(candidate, currentPeriodStart, currentPeriod)) {
          return _nextPeriodStart(currentPeriodStart, currentPeriod);
        }
        if (weekdays.contains(candidate.weekday)) return candidate;
      }
      return _nextPeriodStart(currentPeriodStart, currentPeriod);
    }

    // Flexible mode intentionally places the next generated occurrence on the
    // next day; the user can choose any completion day inside the period.
    return _datePlus(base, 1);
  }

  DateTime? _nextAlternate(DateTime base, DateTime anchor) {
    final cycle = activeDays + restDays;
    if (cycle <= 0) return null;
    final daysSinceAnchor = base.difference(_dateOnly(anchor)).inDays;
    final position = ((daysSinceAnchor % cycle) + cycle) % cycle;
    if (position < activeDays - 1) return _datePlus(base, 1);
    return _datePlus(base, restDays + 1);
  }

  bool _isActiveDay(DateTime date, DateTime anchor) {
    final cycle = activeDays + restDays;
    if (cycle <= 0) return false;
    final position = ((date.difference(_dateOnly(anchor)).inDays % cycle) + cycle) % cycle;
    return position < activeDays;
  }

  static DateTime _periodStart(DateTime date, RecurrencePeriod period) {
    switch (period) {
      case RecurrencePeriod.week:
        return _startOfWeek(date);
      case RecurrencePeriod.month:
        return DateTime(date.year, date.month, 1);
      case RecurrencePeriod.year:
        return DateTime(date.year, 1, 1);
    }
  }

  static DateTime _nextPeriodStart(DateTime start, RecurrencePeriod period) {
    switch (period) {
      case RecurrencePeriod.week:
        return _datePlus(start, 7);
      case RecurrencePeriod.month:
        return DateTime(start.year, start.month + 1, 1);
      case RecurrencePeriod.year:
        return DateTime(start.year + 1, 1, 1);
    }
  }

  static bool _samePeriod(DateTime a, DateTime start, RecurrencePeriod period) {
    final normalized = _periodStart(a, period);
    return normalized == start;
  }

  static DateTime _startOfWeek(DateTime date) {
    final d = _dateOnly(date);
    return _datePlus(d, -(d.weekday - 1));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _datePlus(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime? _nthWeekdayInMonth(
      int year, int month, int weekday, int ordinal) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (ordinal == -1) {
      var d = DateTime(year, month, lastDay);
      while (d.weekday != weekday) d = _datePlus(d, -1);
      return d;
    }
    if (ordinal < 1 || ordinal > 5) return null;
    var d = DateTime(year, month, 1);
    while (d.weekday != weekday) d = _datePlus(d, 1);
    d = _datePlus(d, (ordinal - 1) * 7);
    return d.month == month ? d : null;
  }

  static bool _isNthWeekdayOfMonth(DateTime date, int weekday, int ordinal) {
    final expected = _nthWeekdayInMonth(date.year, date.month, weekday, ordinal);
    return expected != null && expected.year == date.year && expected.month == date.month && expected.day == date.day;
  }

  static String _weekdayName(int day) => const {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      }[day.clamp(1, 7).toInt()]!;

  static String _ordinal(int n) => const {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', 5: '5th'}[n] ?? '$n';

  static RecurrenceRule fromLegacy(
    String pattern, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    switch (pattern.toLowerCase()) {
      case 'weekly':
        return RecurrenceRule(
          type: RecurrenceType.weeklyDays,
          weekdays: [startDate?.weekday ?? DateTime.monday],
          startDate: startDate,
          endDate: endDate,
        );
      case 'monthly':
        return RecurrenceRule(
          type: RecurrenceType.monthlyDates,
          monthDays: [startDate?.day ?? 1],
          startDate: startDate,
          endDate: endDate,
        );
      case 'daily':
      default:
        return RecurrenceRule(
          type: RecurrenceType.daily,
          startDate: startDate,
          endDate: endDate,
        );
    }
  }
}

class RecurrenceRuleAdapter extends TypeAdapter<RecurrenceRule> {
  @override
  final int typeId = 12;

  @override
  RecurrenceRule read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return RecurrenceRule(
      type: RecurrenceType.values[((fields[0] as int?) ?? 0)
          .clamp(0, RecurrenceType.values.length - 1)
          .toInt()],
      interval: ((fields[1] as int?) ?? 1).clamp(1, 3660).toInt(),
      intervalUnit: RecurrenceIntervalUnit.values[((fields[2] as int?) ?? 0)
          .clamp(0, RecurrenceIntervalUnit.values.length - 1)
          .toInt()],
      weekdays: (fields[3] as List?)?.cast<int>() ?? const [],
      monthDays: (fields[4] as List?)?.cast<int>() ?? const [],
      month: fields[5] as int?,
      dayOfMonth: fields[6] as int?,
      nthWeekday: fields[7] as int?,
      nthWeekdayDay: fields[8] as int?,
      period: fields[9] == null
          ? null
          : RecurrencePeriod.values[(fields[9] as int)
              .clamp(0, RecurrencePeriod.values.length - 1)
              .toInt()],
      occurrencesPerPeriod: fields[10] as int?,
      activeDays: ((fields[11] as int?) ?? 1).clamp(1, 366).toInt(),
      restDays: ((fields[12] as int?) ?? 1).clamp(0, 366).toInt(),
      flexible: fields[13] as bool? ?? false,
      startDate: fields[14] as DateTime?,
      endDate: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurrenceRule obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.type.index)
      ..writeByte(1)
      ..write(obj.interval)
      ..writeByte(2)
      ..write(obj.intervalUnit.index)
      ..writeByte(3)
      ..write(obj.weekdays)
      ..writeByte(4)
      ..write(obj.monthDays)
      ..writeByte(5)
      ..write(obj.month)
      ..writeByte(6)
      ..write(obj.dayOfMonth)
      ..writeByte(7)
      ..write(obj.nthWeekday)
      ..writeByte(8)
      ..write(obj.nthWeekdayDay)
      ..writeByte(9)
      ..write(obj.period?.index)
      ..writeByte(10)
      ..write(obj.occurrencesPerPeriod)
      ..writeByte(11)
      ..write(obj.activeDays)
      ..writeByte(12)
      ..write(obj.restDays)
      ..writeByte(13)
      ..write(obj.flexible)
      ..writeByte(14)
      ..write(obj.startDate)
      ..writeByte(15)
      ..write(obj.endDate);
  }
}
