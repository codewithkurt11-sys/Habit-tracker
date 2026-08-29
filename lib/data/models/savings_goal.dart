import 'package:hive/hive.dart';

/// Variance status comparing actual savings pace vs the expected pace.
enum VarianceStatus { ahead, onTrack, behind }

extension VarianceStatusExt on VarianceStatus {
  String get label {
    switch (this) {
      case VarianceStatus.ahead:
        return 'Ahead';
      case VarianceStatus.onTrack:
        return 'On track';
      case VarianceStatus.behind:
        return 'Behind';
    }
  }
}

/// A dedicated savings goal with a daily-contribution mechanic.
///
/// [targetAmount] / [targetDays] defines the initial [dailyAmount].
/// Each day the user taps "Confirm" to log a contribution of the
/// current [dailyAmount].  The "Recalculate" action shrinks
/// [targetDays] to the remaining days and recomputes [dailyAmount]
/// so the user can still reach [targetAmount] in the time left.
///
/// **Test case**: target ₱100 / 5 days → dailyAmount ₱20.
/// Miss day 1 (no contribution).  Recalculate → remaining 4 days,
/// remaining ₱100 → new dailyAmount ₱25.
class SavingsGoal extends HiveObject {
  String id;
  String title;
  double targetAmount;
  int targetDays;
  DateTime startDate;
  List<DateTime> contributionDates;
  List<double> contributionAmounts;
  String? goalId;
  DateTime createdAt;
  DateTime updatedAt;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.targetDays,
    DateTime? startDate,
    List<DateTime>? contributionDates,
    List<double>? contributionAmounts,
    this.goalId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : startDate = startDate ?? DateTime.now(),
        contributionDates = contributionDates ?? [],
        contributionAmounts = contributionAmounts ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  /// Date-only helper so time-of-day never creates comparison edge cases.
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Start of the savings window (date-only).
  DateTime get startDay => dayOf(startDate);

  /// Last day of the savings window (inclusive, date-only).
  /// A `targetDays` of 5 starting on the 1st ends on the 5th.
  DateTime get endDay => DateTime(
        startDate.year,
        startDate.month,
        startDate.day + (targetDays > 0 ? targetDays - 1 : 0),
      );

  /// Number of valid (date, amount) contribution pairs.
  ///
  /// Legacy or imported records can have mismatched list lengths; every
  /// aggregate below is derived from this bound so `confirmedCount` and
  /// `totalContributed` can never disagree because of corrupted data.
  int get _pairCount => contributionDates.length < contributionAmounts.length
      ? contributionDates.length
      : contributionAmounts.length;

  /// Repairs mismatched/duplicated contribution lists in place.
  ///
  /// - truncates both lists to the shorter length
  /// - normalizes every stored date to date-only
  /// - drops duplicate dates (keeping the first occurrence)
  /// - drops negative/non-finite amounts
  ///
  /// Returns true when something had to be changed.
  bool normalizeContributions() {
    final pairs = _pairCount;
    final dates = <DateTime>[];
    final amounts = <double>[];
    final seen = <String>{};
    for (var i = 0; i < pairs; i++) {
      final d = dayOf(contributionDates[i]);
      final key = '${d.year}-${d.month}-${d.day}';
      if (!seen.add(key)) continue;
      final a = contributionAmounts[i];
      if (a.isNaN || a.isInfinite || a < 0) continue;
      dates.add(d);
      amounts.add(a);
    }
    final changed = dates.length != contributionDates.length ||
        amounts.length != contributionAmounts.length ||
        !List.generate(dates.length, (i) => contributionDates[i] == dates[i])
            .every((ok) => ok);
    if (changed) {
      contributionDates = dates;
      contributionAmounts = amounts;
    }
    return changed;
  }

  /// Total amount contributed so far.
  double get totalContributed {
    var sum = 0.0;
    for (var i = 0; i < _pairCount; i++) {
      final a = contributionAmounts[i];
      if (a.isNaN || a.isInfinite) continue;
      sum += a;
    }
    return sum;
  }

  /// Remaining amount to reach [targetAmount].
  double get remainingAmount =>
      (targetAmount - totalContributed).clamp(0.0, double.infinity);

  /// Calendar days elapsed since [startDate] (inclusive of today).
  int get daysElapsed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = today.difference(start).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Remaining days in the savings window.
  int get remainingDays => (targetDays - daysElapsed).clamp(0, targetDays);

  /// The current per-day contribution required to finish on time.
  /// Recalculated as remainingAmount / remainingDays.
  double get dailyAmount {
    if (remainingDays <= 0) return remainingAmount > 0 ? remainingAmount : 0;
    return remainingAmount / remainingDays;
  }

  /// Number of confirmed contributions logged.
  /// Derived from the same bound as [totalContributed] so the two can never
  /// disagree when a legacy record has mismatched list lengths.
  int get confirmedCount => _pairCount;

  /// Progress fraction (0.0 – 1.0).
  double get progressFraction =>
      targetAmount <= 0 ? 0 : (totalContributed / targetAmount).clamp(0.0, 1.0);

  /// Expected contributions by today (one per elapsed day).
  int get expectedContributions => daysElapsed.clamp(0, targetDays);

  /// Whether today's contribution has already been confirmed.
  bool get isConfirmedToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < _pairCount; i++) {
      final d = contributionDates[i];
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return true;
      }
    }
    return false;
  }

  /// Ahead / on-track / behind based on confirmed vs expected contributions.
  VarianceStatus get varianceStatus {
    final confirmed = confirmedCount;
    final expected = expectedContributions;
    if (confirmed > expected) return VarianceStatus.ahead;
    if (confirmed >= expected) return VarianceStatus.onTrack;
    return VarianceStatus.behind;
  }

  /// Returns true if a contribution can be logged for [date].
  ///
  /// Savings contributions record what actually happened, so scheduling ahead
  /// is not supported. A date is only valid when it is, using date-only
  /// comparisons:
  ///   * not before [startDate]
  ///   * not after today (no future contributions)
  ///   * inside the savings window (`startDate .. startDate + targetDays - 1`)
  ///   * not already confirmed (no duplicate contribution dates)
  bool canConfirm(DateTime date, {DateTime? today}) {
    final d = dayOf(date);
    final todayDay = dayOf(today ?? DateTime.now());
    if (d.isBefore(startDay)) return false;
    if (d.isAfter(todayDay)) return false;
    if (targetDays > 0 && d.isAfter(endDay)) return false;
    for (var i = 0; i < _pairCount; i++) {
      final e = contributionDates[i];
      if (e.year == d.year && e.month == d.month && e.day == d.day) {
        return false;
      }
    }
    return true;
  }
}

class SavingsGoalAdapter extends TypeAdapter<SavingsGoal> {
  @override
  final int typeId = 11;

  @override
  SavingsGoal read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    final goal = SavingsGoal(
      id: fields[0] as String,
      title: fields[1] as String,
      targetAmount: (fields[2] as num).toDouble(),
      targetDays: fields[3] as int,
      startDate: fields[4] as DateTime? ?? DateTime.now(),
      contributionDates: (fields[5] as List?)
              ?.whereType<DateTime>()
              .toList() ??
          [],
      contributionAmounts: (fields[6] as List?)
              ?.whereType<num>()
              .map((v) => v.toDouble())
              .toList() ??
          [],
      goalId: fields[7] as String?,
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
      updatedAt: fields[9] as DateTime? ?? DateTime.now(),
    );
    // Repair malformed legacy/imported records on read so the two contribution
    // lists can never be observed with different lengths.
    goal.normalizeContributions();
    return goal;
  }

  @override
  void write(BinaryWriter writer, SavingsGoal obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.targetDays)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.contributionDates)
      ..writeByte(6)
      ..write(obj.contributionAmounts)
      ..writeByte(7)
      ..write(obj.goalId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }
}
