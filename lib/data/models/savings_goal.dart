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

  /// Total amount contributed so far.
  double get totalContributed => contributionAmounts.fold(0.0, (s, a) => s + a);

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
  int get confirmedCount => contributionDates.length;

  /// Progress fraction (0.0 – 1.0).
  double get progressFraction =>
      targetAmount <= 0 ? 0 : (totalContributed / targetAmount).clamp(0.0, 1.0);

  /// Expected contributions by today (one per elapsed day).
  int get expectedContributions => daysElapsed.clamp(0, targetDays);

  /// Whether today's contribution has already been confirmed.
  bool get isConfirmedToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return contributionDates.any(
      (d) =>
          d.year == today.year && d.month == today.month && d.day == today.day,
    );
  }

  /// Ahead / on-track / behind based on confirmed vs expected contributions.
  VarianceStatus get varianceStatus {
    final confirmed = confirmedCount;
    final expected = expectedContributions;
    if (confirmed > expected) return VarianceStatus.ahead;
    if (confirmed >= expected) return VarianceStatus.onTrack;
    return VarianceStatus.behind;
  }

  /// Returns true if a contribution can be logged for [date]
  /// (not already confirmed and date is within the window).
  bool canConfirm(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      return false;
    }
    return !contributionDates.any(
      (e) => e.year == d.year && e.month == d.month && e.day == d.day,
    );
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
    return SavingsGoal(
      id: fields[0] as String,
      title: fields[1] as String,
      targetAmount: (fields[2] as num).toDouble(),
      targetDays: fields[3] as int,
      startDate: fields[4] as DateTime? ?? DateTime.now(),
      contributionDates: (fields[5] as List?)?.cast<DateTime>() ?? [],
      contributionAmounts: (fields[6] as List?)?.cast<double>() ?? [],
      goalId: fields[7] as String?,
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
      updatedAt: fields[9] as DateTime? ?? DateTime.now(),
    );
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
