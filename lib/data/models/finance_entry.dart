import 'package:hive/hive.dart';

/// v2.0.0 Finance: savings-goal-only (no general expense tracking).
/// Tracks daily contribution toward a target amount over target days.
/// [contributionLog] = [{date, amount, confirmed}]
/// [dailyAmount] = targetAmount / targetDays
class FinanceEntry extends HiveObject {
  String id;
  String title;
  String description;
  double targetAmount;
  int targetDays;
  String? linkedGoalId;
  List<ContributionEntry> contributionLog;
  DateTime createdAt;
  DateTime updatedAt;

  FinanceEntry({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetAmount,
    required this.targetDays,
    this.linkedGoalId,
    List<ContributionEntry>? contributionLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : contributionLog = contributionLog ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  double get dailyAmount =>
      targetDays > 0 ? targetAmount / targetDays : 0.0;

  double get totalContributed =>
      contributionLog.where((c) => c.confirmed).fold(0.0, (s, c) => s + c.amount);

  double get progressFraction =>
      targetAmount > 0 ? (totalContributed / targetAmount).clamp(0.0, 1.0) : 0.0;

  int get confirmedDays =>
      contributionLog.where((c) => c.confirmed).length;

  int get elapsedDays {
    if (contributionLog.isEmpty) return 0;
    final now = DateTime.now();
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(created).inDays + 1;
  }

  int get remainingDays => targetDays - confirmedDays;

  /// Variance indicator: ahead, on-track, or behind.
  String get varianceStatus {
    final expected = elapsedDays;
    final actual = confirmedDays;
    if (actual > expected) return 'ahead';
    if (actual == expected) return 'on-track';
    return 'behind';
  }

  bool isConfirmedOn(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return contributionLog.any((c) =>
        c.confirmed &&
        c.date.year == normalized.year &&
        c.date.month == normalized.month &&
        c.date.day == normalized.day);
  }

  /// Check for missed days (days where contribution was expected but not confirmed).
  List<DateTime> getMissedDays() {
    final missed = <DateTime>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    for (int i = 0; i < elapsedDays && i < targetDays; i++) {
      final day = DateTime(created.year, created.month, created.day + i);
      if (!day.isAfter(today) && !isConfirmedOn(day)) {
        missed.add(day);
      }
    }
    return missed;
  }

  /// Recalculate remaining days after a missed day.
  int get recalculatedRemainingDays {
    final missed = getMissedDays();
    return (targetDays - confirmedDays - missed.length).clamp(0, targetDays);
  }
}

class ContributionEntry {
  DateTime date;
  double amount;
  bool confirmed;

  ContributionEntry({
    required this.date,
    required this.amount,
    this.confirmed = false,
  });
}

class FinanceEntryAdapter extends TypeAdapter<FinanceEntry> {
  @override
  final int typeId = 7;

  @override
  FinanceEntry read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    final rawContributions = fields[6] as List?;
    return FinanceEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      targetAmount: (fields[3] as num?)?.toDouble() ?? 0,
      targetDays: fields[4] as int? ?? 30,
      linkedGoalId: fields[5] as String?,
      contributionLog: rawContributions
              ?.map((c) => ContributionEntry(
                    date: (c as List)[0] as DateTime,
                    amount: (c[1] as num).toDouble(),
                    confirmed: c[2] as bool? ?? false,
                  ))
              .toList() ??
          [],
      createdAt: fields[7] as DateTime? ?? DateTime.now(),
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, FinanceEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.targetDays)
      ..writeByte(5)
      ..write(obj.linkedGoalId)
      ..writeByte(6)
      ..write(obj.contributionLog
          .map((c) => [c.date, c.amount, c.confirmed])
          .toList())
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}

/// Kept for backward compat — old budget box won't crash.
class FinanceBudget extends HiveObject {
  double monthlyBudget;
  double savingsGoal;
  Map<String, double> categoryLimits;

  FinanceBudget({
    this.monthlyBudget = 0,
    this.savingsGoal = 0,
    Map<String, double>? categoryLimits,
  }) : categoryLimits = categoryLimits ?? {};
}

class FinanceBudgetAdapter extends TypeAdapter<FinanceBudget> {
  @override
  final int typeId = 8;

  @override
  FinanceBudget read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    final rawLimits = fields[2] as Map?;
    return FinanceBudget(
      monthlyBudget: fields[0] as double? ?? 0,
      savingsGoal: fields[1] as double? ?? 0,
      categoryLimits: rawLimits
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
          {},
    );
  }

  @override
  void write(BinaryWriter writer, FinanceBudget obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.monthlyBudget)
      ..writeByte(1)
      ..write(obj.savingsGoal)
      ..writeByte(2)
      ..write(obj.categoryLimits);
  }
}
