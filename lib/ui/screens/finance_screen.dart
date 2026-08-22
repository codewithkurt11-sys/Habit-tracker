import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../logic/app_state.dart';
import '../../logic/stats_engine.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/savings_goal.dart';
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

    final income =
        state.financeRepo.getTotalIncome(year: now.year, month: now.month);
    final expenses =
        state.financeRepo.getTotalExpenses(year: now.year, month: now.month);
    final balance = income - expenses;
    final monthName = DateFormat.MMMM().format(now);
    final budget = state.financeRepo.budget;
    final categoryBreakdown = StatsEngine.expenseByCategory(
        state.financeRepo.getAll(), now.year, now.month);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Finance',
              subtitle: '$monthName ${now.year}',
              onMenuTap: null,
              trailing: IconButton(
                tooltip: 'Add transaction',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () { context.read<AppState>().hideQuickCapture(); showAddFinanceDialog(context); },
              ),
            ),
            _SummaryCard(
              income: income,
              expenses: expenses,
              balance: balance,
              budget: budget.monthlyBudget,
              savingsGoal: budget.savingsGoal,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Budget + Category breakdown
            if (budget.monthlyBudget > 0 || categoryBreakdown.isNotEmpty)
              _BudgetOverviewCard(
                expenses: expenses,
                budget: budget.monthlyBudget,
                savingsGoal: budget.savingsGoal,
                income: income,
                categoryBreakdown: categoryBreakdown,
              ),
            if (budget.monthlyBudget > 0 || categoryBreakdown.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),
            // Savings goals section
            _SavingsGoalsSection(state: state),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: entries.isEmpty
                  ? EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No transactions yet',
                      subtitle: 'Track your income and expenses',
                      actionLabel: 'Add Transaction',
                      onAction: () => showAddFinanceDialog(context),
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double income;
  final double expenses;
  final double balance;
  final double budget;
  final double savingsGoal;

  const _SummaryCard({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.budget,
    required this.savingsGoal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

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

class _BudgetOverviewCard extends StatelessWidget {
  final double expenses;
  final double budget;
  final double savingsGoal;
  final double income;
  final Map<String, double> categoryBreakdown;
  const _BudgetOverviewCard({
    required this.expenses,
    required this.budget,
    required this.savingsGoal,
    required this.income,
    required this.categoryBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final budgetPct = budget > 0 ? (expenses / budget).clamp(0.0, 1.0) : 0.0;
    final savings = income - expenses;
    final savingsPct =
        savingsGoal > 0 ? (savings / savingsGoal).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && expenses > budget;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget
              if (budget > 0) ...[
                Row(
                  children: [
                    Icon(Icons.account_balance,
                        size: 18,
                        color:
                            overBudget ? theme.colorScheme.error : ext.success),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Monthly Budget',
                            style: theme.textTheme.titleSmall)),
                    Text(
                      '${fmt.format(expenses)} / ${fmt.format(budget)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overBudget ? theme.colorScheme.error : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: LinearProgressIndicator(
                    value: budgetPct,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        overBudget ? theme.colorScheme.error : ext.success),
                  ),
                ),
                if (overBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Over budget by ${fmt.format(expenses - budget)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              // Savings goal
              if (savingsGoal > 0) ...[
                Row(
                  children: [
                    Icon(Icons.savings,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Savings Goal',
                            style: theme.textTheme.titleSmall)),
                    Text('${fmt.format(savings)} / ${fmt.format(savingsGoal)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: LinearProgressIndicator(
                    value: savingsPct,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              // Category breakdown
              if (categoryBreakdown.isNotEmpty) ...[
                Text('Spending by Category',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                ...categoryBreakdown.entries.take(5).map((e) {
                  final pct = expenses > 0 ? (e.value / expenses * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 80,
                            child:
                                Text(e.key, style: theme.textTheme.bodySmall)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(theme
                                  .colorScheme.error
                                  .withValues(alpha: 0.6)),
                            ),
                          ),
                        ),
                        SizedBox(
                            width: 50,
                            child: Text('₱${e.value.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.right)),
                      ],
                    ),
                  );
                }),
              ],
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
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
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
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
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
      confirmDismiss: (_) => showDeleteConfirmation(context, itemName: 'transaction', message: 'Delete "${entry.title}"?'),
      onDismissed: (_) => state.deleteFinance(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () => showEditFinanceDialog(context, entry),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: entry.categoryColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Icon(entry.categoryIcon,
                        color: entry.categoryColor, size: 22),
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
                          PillChip(
                              label: entry.categoryLabel,
                              color: entry.categoryColor),
                          if (entry.goalId != null) ...[
                            const SizedBox(width: 6),
                            const PillChip(
                                label: 'Savings goal', icon: Icons.link),
                          ],
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
                        ? Theme.of(context)
                            .extension<AppThemeExtension>()!
                            .success
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Global dialog action — call from anywhere.
void showAddFinanceDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _FinanceEditorDialog());
}

void showEditFinanceDialog(BuildContext context, FinanceEntry entry) {
  showDialog(context: context, builder: (_) => _FinanceEditorDialog(entry: entry));
}

class _FinanceEditorDialog extends StatefulWidget {
  final FinanceEntry? entry;
  const _FinanceEditorDialog({this.entry});

  @override
  State<_FinanceEditorDialog> createState() => _FinanceEditorDialogState();
}

class _FinanceEditorDialogState extends State<_FinanceEditorDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _plannedController = TextEditingController();
  int _typeIndex = 1; // 0 = income, 1 = expense
  int _categoryIndex = 0;
  DateTime _date = DateTime.now();
  String? _goalId;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _noteController.text = e.note;
      _plannedController.text = e.plannedAmount == 0 ? '' : e.plannedAmount.toStringAsFixed(2);
      _typeIndex = e.typeIndex;
      _categoryIndex = e.categoryIndex;
      _date = e.date;
      _goalId = e.goalId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _plannedController.dispose();
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
      title: Text(widget.entry == null ? 'New Transaction' : 'Edit Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Income/Expense toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _typeIndex = 0;
                      _categoryIndex = 0;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeIndex == 0 ? ext.success : ext.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Center(
                        child: Text('Income',
                            style: TextStyle(
                              color: _typeIndex == 0
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _typeIndex = 1;
                      _categoryIndex = 0;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeIndex == 1
                            ? theme.colorScheme.error
                            : ext.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Center(
                        child: Text('Expense',
                            style: TextStyle(
                              color: _typeIndex == 1
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
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
                prefixText: '₱ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _goalId,
              decoration: const InputDecoration(
                labelText: 'Savings goal (optional)',
                prefixIcon: Icon(Icons.savings_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked'),
                ),
                ...context
                    .read<AppState>()
                    .goalsRepo
                    .getActive()
                    
                    .map(
                      (goal) => DropdownMenuItem<String?>(
                        value: goal.id,
                        child: Text(goal.title),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() {
                _goalId = value;
                if (value != null) _typeIndex = 0;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _plannedController,
              decoration: const InputDecoration(
                labelText: 'Planned contribution (optional)',
                prefixText: '₱ ',
                helperText: 'Used to show actual versus planned variance.',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? theme.colorScheme.primary : ext.surfaceMuted,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcons[i],
                            size: 14,
                            color: sel
                                ? Colors.white
                                : theme.colorScheme.onSurface),
                        const SizedBox(width: 4),
                        Text(_categoryLabels[i],
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
          onPressed: () async {
            final title = _titleController.text.trim();
            final amount = double.tryParse(_amountController.text.trim());
            if (title.isEmpty || amount == null || amount <= 0) return;
            final state = context.read<AppState>();
            final planned = double.tryParse(_plannedController.text.trim()) ?? 0;
            if (widget.entry == null) {
              await state.addFinance(title: title, amount: amount, typeIndex: _typeIndex, categoryIndex: _categoryIndex, date: _date, note: _noteController.text.trim(), goalId: _goalId, plannedAmount: planned);
            } else {
              final e = widget.entry!;
              e.title = title; e.amount = amount; e.typeIndex = _typeIndex; e.categoryIndex = _categoryIndex; e.date = _date; e.note = _noteController.text.trim(); e.goalId = _goalId; e.linkedGoalId = null; e.plannedAmount = planned;
              await state.updateFinance(e);
            }
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Savings Goals Section
// ─────────────────────────────────────────────────────────────────────

class _SavingsGoalsSection extends StatelessWidget {
  final AppState state;
  const _SavingsGoalsSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final goals = state.savingsGoalsRepo.getAll();
    if (goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Card(
          child: ListTile(
            leading: Icon(Icons.savings_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Savings Targets'),
            subtitle:
                const Text('Set a target amount and daily contribution plan'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddSavingsGoalDialog(context),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Savings Targets',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddSavingsGoalDialog(context),
              ),
            ],
          ),
          ...goals.map((sg) => _SavingsGoalCard(savingsGoal: sg)),
        ],
      ),
    );
  }

  void _showAddSavingsGoalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddSavingsGoalDialog(),
    );
  }
}

class _SavingsGoalCard extends StatelessWidget {
  final SavingsGoal savingsGoal;
  const _SavingsGoalCard({required this.savingsGoal});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final fmt0 = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    final progress = savingsGoal.progressFraction;
    final variance = savingsGoal.varianceStatus;
    final varianceColor = variance == VarianceStatus.ahead
        ? ext.success
        : variance == VarianceStatus.behind
            ? theme.colorScheme.error
            : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + delete
              Row(
                children: [
                  Icon(Icons.savings,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(savingsGoal.title,
                        style: theme.textTheme.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showDeleteConfirmation(context,
                              itemName: 'savings goal',
                              message: 'Delete "${savingsGoal.title}"?')
                          .then((confirmed) {
                        if (confirmed) state.deleteSavingsGoal(savingsGoal.id);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Target / daily / remaining
              Row(
                children: [
                  _SavingsStat(
                      label: 'Target',
                      value: fmt0.format(savingsGoal.targetAmount)),
                  const SizedBox(width: AppSpacing.md),
                  _SavingsStat(
                      label: 'Daily',
                      value: fmt0.format(savingsGoal.dailyAmount)),
                  const SizedBox(width: AppSpacing.md),
                  _SavingsStat(
                      label: 'Remaining',
                      value: '${savingsGoal.remainingDays}d'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${fmt0.format(savingsGoal.totalContributed)} / ${fmt0.format(savingsGoal.targetAmount)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Variance status
              Row(
                children: [
                  Icon(
                    variance == VarianceStatus.ahead
                        ? Icons.trending_up
                        : variance == VarianceStatus.behind
                            ? Icons.trending_down
                            : Icons.trending_flat,
                    size: 16,
                    color: varianceColor,
                  ),
                  const SizedBox(width: 4),
                  Text(variance.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: varianceColor, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '${savingsGoal.confirmedCount}/${savingsGoal.expectedContributions} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      // Disabled when today's contribution is already logged or
                      // today falls outside the savings window — contributions
                      // can only be recorded for valid, non-future days.
                      onPressed: savingsGoal.canConfirm(DateTime.now())
                          ? () async {
                              final ok = await state
                                  .confirmSavingsContribution(savingsGoal.id);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'This contribution could not be recorded for today.'),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(savingsGoal.isConfirmedToday
                          ? 'Confirmed today'
                          : savingsGoal.canConfirm(DateTime.now())
                              ? 'Confirm ₱${savingsGoal.dailyAmount.toStringAsFixed(0)}'
                              : 'Window closed'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () =>
                        state.recalculateSavingsGoal(savingsGoal.id),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Recalculate'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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

class _SavingsStat extends StatelessWidget {
  final String label;
  final String value;
  const _SavingsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 10)),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AddSavingsGoalDialog extends StatefulWidget {
  const _AddSavingsGoalDialog();

  @override
  State<_AddSavingsGoalDialog> createState() => _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends State<_AddSavingsGoalDialog> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _daysController = TextEditingController();
  String? _goalId;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Savings Target'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Emergency fund',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₱ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _daysController,
              decoration: const InputDecoration(
                labelText: 'Target days',
                hintText: 'e.g. 30',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _goalId,
              decoration: const InputDecoration(
                labelText: 'Link to goal (optional)',
                prefixIcon: Icon(Icons.link),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked'),
                ),
                ...context
                    .read<AppState>()
                    .goalsRepo
                    .getActive()
                    
                    .map(
                      (goal) => DropdownMenuItem<String?>(
                        value: goal.id,
                        child: Text(goal.title),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _goalId = value),
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
            final target = double.tryParse(_targetController.text.trim());
            final days = int.tryParse(_daysController.text.trim());
            if (title.isEmpty ||
                target == null ||
                target <= 0 ||
                days == null ||
                days <= 0) {
              return;
            }
            context.read<AppState>().addSavingsGoal(
                  title: title,
                  targetAmount: target,
                  targetDays: days,
                  goalId: _goalId,
                );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
