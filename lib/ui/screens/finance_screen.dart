import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../logic/app_state.dart';
import '../../data/models/finance_entry.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final entries = state.financeRepo.getForMonth(now.year, now.month)
      ..sort((a, b) => b.date.compareTo(a.date));

    final income = state.financeRepo.getTotalIncome(year: now.year, month: now.month);
    final expenses = state.financeRepo.getTotalExpenses(year: now.year, month: now.month);
    final balance = income - expenses;
    final monthName = DateFormat.MMMM().format(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Finance',
              subtitle: '$monthName ${now.year}',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            _SummaryCard(
              income: income,
              expenses: expenses,
              balance: balance,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No transactions yet',
                      subtitle: 'Track your income and expenses',
                      actionLabel: 'Add Transaction',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _FinanceTile(entry: entries[i]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _AddFinanceDialog(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double income;
  final double expenses;
  final double balance;

  const _SummaryCard({
    required this.income,
    required this.expenses,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text('Balance', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                fmt.format(balance),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: balance >= 0 ? ext.success : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Income',
                      value: fmt.format(income),
                      icon: Icons.arrow_downward,
                      color: ext.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MiniStat(
                      label: 'Expenses',
                      value: fmt.format(expenses),
                      icon: Icons.arrow_upward,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  final FinanceEntry entry;
  const _FinanceTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isIncome = entry.isIncome;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteFinance(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: entry.categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Icon(entry.categoryIcon, color: entry.categoryColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          PillChip(label: entry.categoryLabel, color: entry.categoryColor),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.date.month}/${entry.date.day}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${fmt.format(entry.amount)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isIncome
                        ? Theme.of(context).extension<AppThemeExtension>()!.success
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFinanceDialog extends StatefulWidget {
  const _AddFinanceDialog();

  @override
  State<_AddFinanceDialog> createState() => _AddFinanceDialogState();
}

class _AddFinanceDialogState extends State<_AddFinanceDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int _typeIndex = 1; // 0 = income, 1 = expense
  int _categoryIndex = 0;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categoryLabels {
    if (_typeIndex == 0) {
      return IncomeCategory.values.map((c) => c.label).toList();
    } else {
      return ExpenseCategory.values.map((c) => c.label).toList();
    }
  }

  List<IconData> get _categoryIcons {
    if (_typeIndex == 0) {
      return IncomeCategory.values.map((c) => c.icon).toList();
    } else {
      return ExpenseCategory.values.map((c) => c.icon).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    return AlertDialog(
      title: const Text('New Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Income/Expense toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _typeIndex = 0; _categoryIndex = 0; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeIndex == 0 ? ext.success : ext.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Center(
                        child: Text('Income',
                            style: TextStyle(
                              color: _typeIndex == 0 ? Colors.white : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _typeIndex = 1; _categoryIndex = 0; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeIndex == 1 ? theme.colorScheme.error : ext.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Center(
                        child: Text('Expense',
                            style: TextStyle(
                              color: _typeIndex == 1 ? Colors.white : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Grocery shopping',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            // Category
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Category', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(_categoryLabels.length, (i) {
                final sel = i == _categoryIndex;
                return GestureDetector(
                  onTap: () => setState(() => _categoryIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? theme.colorScheme.primary : ext.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcons[i], size: 14,
                            color: sel ? Colors.white : theme.colorScheme.onSurface),
                        const SizedBox(width: 4),
                        Text(_categoryLabels[i],
                            style: TextStyle(
                              color: sel ? Colors.white : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600, fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Date: ', style: theme.textTheme.labelLarge),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: Text('${_date.month}/${_date.day}/${_date.year}'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final amount = double.tryParse(_amountController.text.trim());
            if (title.isEmpty || amount == null || amount <= 0) return;
            context.read<AppState>().addFinance(
                  title: title,
                  amount: amount,
                  typeIndex: _typeIndex,
                  categoryIndex: _categoryIndex,
                  date: _date,
                );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
