import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum FinanceType { income, expense }

enum IncomeCategory { salary, allowance, freelance, investment, gift, other }

enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  education,
  entertainment,
  health,
  rent,
  savings,
  other,
}

extension IncomeCategoryExt on IncomeCategory {
  String get label {
    switch (this) {
      case IncomeCategory.salary:
        return 'Salary';
      case IncomeCategory.allowance:
        return 'Allowance';
      case IncomeCategory.freelance:
        return 'Freelance';
      case IncomeCategory.investment:
        return 'Investment';
      case IncomeCategory.gift:
        return 'Gift';
      case IncomeCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case IncomeCategory.salary:
        return Icons.work;
      case IncomeCategory.allowance:
        return Icons.card_giftcard;
      case IncomeCategory.freelance:
        return Icons.laptop;
      case IncomeCategory.investment:
        return Icons.trending_up;
      case IncomeCategory.gift:
        return Icons.redeem;
      case IncomeCategory.other:
        return Icons.attach_money;
    }
  }

  Color get color => const Color(0xFF6B9080);
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.savings:
        return 'Savings';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_bus;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.bills:
        return Icons.receipt_long;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.health:
        return Icons.medical_services;
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.savings:
        return Icons.savings;
      case ExpenseCategory.other:
        return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFE8946F);
      case ExpenseCategory.transport:
        return const Color(0xFF7B93B5);
      case ExpenseCategory.shopping:
        return const Color(0xFFB58BB5);
      case ExpenseCategory.bills:
        return const Color(0xFFD4675A);
      case ExpenseCategory.education:
        return const Color(0xFF6B9080);
      case ExpenseCategory.entertainment:
        return const Color(0xFFE8C56F);
      case ExpenseCategory.health:
        return const Color(0xFF8FC0A0);
      case ExpenseCategory.rent:
        return const Color(0xFFC4A895);
      case ExpenseCategory.savings:
        return const Color(0xFF6B9080);
      case ExpenseCategory.other:
        return const Color(0xFFB8AEA4);
    }
  }
}

class FinanceEntry extends HiveObject {
  String id;
  String title;
  double amount;
  int typeIndex; // FinanceType index
  int categoryIndex; // income or expense category index
  DateTime date;
  String note;
  String? goalId;
  double plannedAmount;
  DateTime createdAt;
  DateTime updatedAt;
  // Savings-goal contribution history fields retained for backup compatibility
  double targetAmount;
  int targetDays;
  double dailyAmount;
  List<DateTime> contributionLogDates;
  List<double> contributionLogAmounts;
  List<bool> contributionLogConfirmed;
  String? linkedGoalId;

  FinanceEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.typeIndex,
    required this.categoryIndex,
    required this.date,
    this.note = '',
    this.goalId,
    this.plannedAmount = 0,
    DateTime? createdAt,
    this.targetAmount = 0,
    this.targetDays = 0,
    this.dailyAmount = 0,
    List<DateTime>? contributionLogDates,
    List<double>? contributionLogAmounts,
    List<bool>? contributionLogConfirmed,
    this.linkedGoalId,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        contributionLogDates = contributionLogDates ?? [],
        contributionLogAmounts = contributionLogAmounts ?? [],
        contributionLogConfirmed = contributionLogConfirmed ?? [];

  FinanceEntry copyWith({
    String? id,
    String? title,
    double? amount,
    int? typeIndex,
    int? categoryIndex,
    DateTime? date,
    String? note,
    String? goalId,
    bool clearGoalId = false,
    double? plannedAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? targetAmount,
    int? targetDays,
    double? dailyAmount,
    List<DateTime>? contributionLogDates,
    List<double>? contributionLogAmounts,
    List<bool>? contributionLogConfirmed,
    String? linkedGoalId,
  }) {
    return FinanceEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      typeIndex: typeIndex ?? this.typeIndex,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      date: date ?? this.date,
      note: note ?? this.note,
      goalId: clearGoalId ? null : (goalId ?? this.goalId),
      plannedAmount: plannedAmount ?? this.plannedAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      targetAmount: targetAmount ?? this.targetAmount,
      targetDays: targetDays ?? this.targetDays,
      dailyAmount: dailyAmount ?? this.dailyAmount,
      contributionLogDates: contributionLogDates ?? List<DateTime>.from(this.contributionLogDates),
      contributionLogAmounts: contributionLogAmounts ?? List<double>.from(this.contributionLogAmounts),
      contributionLogConfirmed: contributionLogConfirmed ?? List<bool>.from(this.contributionLogConfirmed),
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
    );
  }

  void touch() => updatedAt = DateTime.now();

  FinanceType get type => FinanceType.values[typeIndex];

  bool get isIncome => type == FinanceType.income;

  IncomeCategory get incomeCategory => IncomeCategory
      .values[categoryIndex.clamp(0, IncomeCategory.values.length - 1)];

  ExpenseCategory get expenseCategory => ExpenseCategory
      .values[categoryIndex.clamp(0, ExpenseCategory.values.length - 1)];

  String get categoryLabel =>
      isIncome ? incomeCategory.label : expenseCategory.label;

  IconData get categoryIcon =>
      isIncome ? incomeCategory.icon : expenseCategory.icon;

  Color get categoryColor =>
      isIncome ? const Color(0xFF6B9080) : expenseCategory.color;
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
    return FinanceEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      typeIndex: fields[3] as int,
      categoryIndex: fields[4] as int,
      date: fields[5] as DateTime,
      note: fields[6] as String? ?? '',
      createdAt: fields[7] as DateTime? ?? DateTime.now(),
      goalId: fields[8] as String?,
      plannedAmount: (fields[9] as num?)?.toDouble() ?? 0,
      targetAmount: (fields[10] as num?)?.toDouble() ?? 0,
      targetDays: fields[11] as int? ?? 0,
      dailyAmount: (fields[12] as num?)?.toDouble() ?? 0,
      contributionLogDates: (fields[13] as List?)?.cast<DateTime>() ?? [],
      contributionLogAmounts: (fields[14] as List?)?.cast<double>() ?? [],
      contributionLogConfirmed: (fields[15] as List?)?.cast<bool>() ?? [],
      linkedGoalId: fields[16] as String?,
      updatedAt: fields[17] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, FinanceEntry obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.typeIndex)
      ..writeByte(4)
      ..write(obj.categoryIndex)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.goalId)
      ..writeByte(9)
      ..write(obj.plannedAmount)
      ..writeByte(10)
      ..write(obj.targetAmount)
      ..writeByte(11)
      ..write(obj.targetDays)
      ..writeByte(12)
      ..write(obj.dailyAmount)
      ..writeByte(13)
      ..write(obj.contributionLogDates)
      ..writeByte(14)
      ..write(obj.contributionLogAmounts)
      ..writeByte(15)
      ..write(obj.contributionLogConfirmed)
      ..writeByte(16)
      ..write(obj.linkedGoalId)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }
}

/// Monthly budget settings stored as a single record.
class FinanceBudget extends HiveObject {
  double monthlyBudget;
  double savingsGoal;
  Map<String, double> categoryLimits; // category label -> limit

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
