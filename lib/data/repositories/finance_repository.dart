import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/finance_entry.dart';

class FinanceRepository {
  Box<FinanceEntry> get _box => Hive.box<FinanceEntry>(HiveBoxes.finance);
  Box<FinanceBudget> get _budgetBox =>
      Hive.box<FinanceBudget>(HiveBoxes.financeBudget);
  static const _budgetKey = 'budget';
  final _uuid = const Uuid();

  List<FinanceEntry> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<FinanceEntry> getForMonth(int year, int month) => getAll()
      .where((e) => e.date.year == year && e.date.month == month)
      .toList();

  List<FinanceEntry> getIncome() => getAll().where((e) => e.isIncome).toList();

  List<FinanceEntry> getExpenses() =>
      getAll().where((e) => !e.isIncome).toList();

  double getTotalIncome({int? year, int? month}) {
    var entries = getIncome();
    if (year != null) {
      entries = entries.where((e) => e.date.year == year).toList();
    }
    if (month != null) {
      entries = entries.where((e) => e.date.month == month).toList();
    }
    return entries.fold(0, (sum, e) => sum + e.amount);
  }

  double getTotalExpenses({int? year, int? month}) {
    var entries = getExpenses();
    if (year != null) {
      entries = entries.where((e) => e.date.year == year).toList();
    }
    if (month != null) {
      entries = entries.where((e) => e.date.month == month).toList();
    }
    return entries.fold(0, (sum, e) => sum + e.amount);
  }

  double getBalance({int? year, int? month}) =>
      getTotalIncome(year: year, month: month) -
      getTotalExpenses(year: year, month: month);

  /// Expense breakdown by category for a given month
  Map<String, double> getCategoryBreakdown(int year, int month) {
    final map = <String, double>{};
    for (final e in getForMonth(year, month)) {
      if (!e.isIncome) {
        map[e.categoryLabel] = (map[e.categoryLabel] ?? 0) + e.amount;
      }
    }
    return map;
  }

  FinanceBudget get budget {
    return _budgetBox.get(_budgetKey) ?? FinanceBudget();
  }

  Future<void> saveBudget(FinanceBudget b) async {
    await _budgetBox.put(_budgetKey, b);
  }

  Future<FinanceEntry> create({
    required String title,
    required double amount,
    required int typeIndex,
    required int categoryIndex,
    required DateTime date,
    String note = '',
  }) async {
    final entry = FinanceEntry(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      typeIndex: typeIndex,
      categoryIndex: categoryIndex,
      date: date,
      note: note,
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  Future<void> update(FinanceEntry entry) async => _box.put(entry.id, entry);

  Future<void> delete(String id) async => _box.delete(id);
}
