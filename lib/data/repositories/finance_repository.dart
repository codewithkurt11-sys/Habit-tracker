import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/finance_entry.dart';

class FinanceRepository {
  Box<FinanceEntry> get _box => Hive.box<FinanceEntry>(HiveBoxes.finance);
  final _uuid = const Uuid();

  List<FinanceEntry> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  FinanceEntry? getById(String id) {
    try {
      return _box.values.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get finance targets due today (not yet confirmed today).
  List<FinanceEntry> getDueToday() {
    final now = DateTime.now();
    return getAll().where((f) {
      final created = DateTime(f.createdAt.year, f.createdAt.month, f.createdAt.day);
      final today = DateTime(now.year, now.month, now.day);
      final elapsed = today.difference(created).inDays + 1;
      return elapsed <= f.targetDays && !f.isConfirmedOn(today);
    }).toList();
  }

  Future<FinanceEntry> create({
    required String title,
    String description = '',
    required double targetAmount,
    required int targetDays,
    String? linkedGoalId,
  }) async {
    final entry = FinanceEntry(
      id: _uuid.v4(),
      title: title,
      description: description,
      targetAmount: targetAmount,
      targetDays: targetDays,
      linkedGoalId: linkedGoalId,
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  Future<void> update(FinanceEntry entry) async {
    entry.touch();
    await _box.put(entry.id, entry);
  }

  Future<void> delete(String id) async => _box.delete(id);

  /// Confirm today's contribution (tap-to-confirm pattern).
  Future<void> confirmToday(FinanceEntry entry) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Check if already confirmed today
    final existing = entry.contributionLog.any((c) =>
        c.confirmed &&
        c.date.year == today.year &&
        c.date.month == today.month &&
        c.date.day == today.day);
    if (!existing) {
      entry.contributionLog.add(ContributionEntry(
        date: today,
        amount: entry.dailyAmount,
        confirmed: true,
      ));
      entry.touch();
      await _box.put(entry.id, entry);
    }
  }

  /// Unconfirm today's contribution (undo).
  Future<void> unconfirmToday(FinanceEntry entry) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    entry.contributionLog.removeWhere((c) =>
        c.confirmed &&
        c.date.year == today.year &&
        c.date.month == today.month &&
        c.date.day == today.day);
    entry.touch();
    await _box.put(entry.id, entry);
  }

  /// Recalculate remaining days after missed day.
  Future<void> recalculate(FinanceEntry entry) async {
    // No-op on the model itself — remaining days are computed dynamically
    // This is here for future extension (e.g., extending targetDays)
    entry.touch();
    await _box.put(entry.id, entry);
  }
}
