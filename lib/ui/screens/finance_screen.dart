import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/finance_entry.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/heatmap_widget.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final finances = state.finances;
    final currency = state.settings.currencySymbol;

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddFinanceDialog(context),
          child: const Icon(Icons.add),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitleBar(
                title: 'Savings Goals',
                subtitle: '${finances.length} active • $currency${finances.fold(0.0, (s, f) => s + f.totalContributed).toStringAsFixed(0)} saved',
              ),
            ),
            if (finances.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.savings_outlined,
                  title: 'No savings goals',
                  subtitle: 'Set a daily savings target',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FinanceCard(finance: finances[index], currency: currency),
                  childCount: finances.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showAddFinanceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddFinanceSheet(),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final FinanceEntry finance;
  final String currency;
  const _FinanceCard({required this.finance, required this.currency});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final isConfirmedToday = finance.isConfirmedOn(DateTime.now());
    final progress = finance.progressFraction;
    final variance = finance.varianceStatus;
    final missedDays = finance.getMissedDays();

    var varianceColor = theme.colorScheme.primary;
    var varianceLabel = 'On track';
    if (variance == 'ahead') {
      varianceColor = const Color(0xFF6B9080);
      varianceLabel = 'Ahead';
    } else if (variance == 'behind') {
      varianceColor = const Color(0xFFD4675A);
      varianceLabel = 'Behind';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FinanceDetailScreen(financeId: finance.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircularFillIcon(progress: progress, icon: Icons.savings, color: const Color(0xFF6B9080)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(finance.title, style: theme.textTheme.titleMedium),
                      Text(
                        '$currency${finance.totalContributed.toStringAsFixed(0)} / $currency${finance.targetAmount.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PillChip(label: varianceLabel, color: varianceColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF6B9080).withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6B9080)),
              minHeight: 6,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text('${finance.confirmedDays}/${finance.targetDays} days',
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                if (!isConfirmedToday && finance.remainingDays > 0)
                  GestureDetector(
                    onTap: () async {
                      await state.confirmFinanceToday(finance.id);
                      showUndoToast(context, '$currency${finance.dailyAmount.toStringAsFixed(0)} saved!', null);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9080),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text('Save $currency${finance.dailyAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (isConfirmedToday)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF6B9080), size: 18),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          await state.unconfirmFinanceToday(finance.id);
                          showUndoToast(context, 'Contribution undone', null);
                        },
                        child: Text('Done today', style: TextStyle(color: const Color(0xFF6B9080), fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
            if (missedDays.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Missed ${missedDays.length} day(s)',
                  style: TextStyle(color: const Color(0xFFD4675A), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class FinanceDetailScreen extends StatelessWidget {
  final String financeId;
  const FinanceDetailScreen({super.key, required this.financeId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final f = state.financeRepo.getById(financeId);

    if (f == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));
    }

    final theme = Theme.of(context);
    final currency = state.settings.currencySymbol;
    final progress = f.progressFraction;
    final variance = f.varianceStatus;
    final missedDays = f.getMissedDays();

    return Scaffold(
      appBar: AppBar(
        title: Text(f.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await showDeleteConfirmation(context, itemName: 'savings goal')) {
                await state.deleteFinance(f.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Row(
              children: [
                CircularFillIcon(progress: progress, icon: Icons.savings, color: const Color(0xFF6B9080), size: 64),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${(progress * 100).round()}%', style: theme.textTheme.displayMedium?.copyWith(color: const Color(0xFF6B9080))),
                    Text('Saved', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Details
            _DetailRow(label: 'Target amount', value: '$currency${f.targetAmount.toStringAsFixed(2)}'),
            _DetailRow(label: 'Daily amount', value: '$currency${f.dailyAmount.toStringAsFixed(2)}'),
            _DetailRow(label: 'Total saved', value: '$currency${f.totalContributed.toStringAsFixed(2)}'),
            _DetailRow(label: 'Target days', value: '${f.targetDays}'),
            _DetailRow(label: 'Days confirmed', value: '${f.confirmedDays}'),
            _DetailRow(label: 'Days remaining', value: '${f.remainingDays}'),
            _DetailRow(label: 'Status', value: variance == 'ahead' ? 'Ahead of schedule' : variance == 'behind' ? 'Behind schedule' : 'On track'),
            const SizedBox(height: AppSpacing.lg),
            // Contribution heatmap
            Text('Contribution Calendar', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            FinanceHeatmap(
              confirmedDays: f.contributionLog.where((c) => c.confirmed).map((c) => c.date).toList(),
              startDate: f.createdAt,
              totalDays: f.targetDays,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Missed days banner
            if (missedDays.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4675A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD4675A)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Missed ${missedDays.length} day(s). Recalculate remaining days?',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        state.refresh();
                        showUndoToast(context, 'Remaining days recalculated', null);
                      },
                      child: const Text('Recalculate'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _AddFinanceSheet extends StatefulWidget {
  const _AddFinanceSheet();

  @override
  State<_AddFinanceSheet> createState() => _AddFinanceSheetState();
}

class _AddFinanceSheetState extends State<_AddFinanceSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController(text: '1000');
  final _daysController = TextEditingController(text: '30');
  String? _linkedGoalId;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final goals = state.activeGoals;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final days = int.tryParse(_daysController.text) ?? 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Savings Goal', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title (e.g. Emergency Fund)'),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Target amount', prefixText: '\u20B1 '),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _daysController,
                  decoration: const InputDecoration(labelText: 'Target days'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (days > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('${state.settings.currencySymbol}${(amount / days).toStringAsFixed(2)}/day',
                  style: theme.textTheme.bodySmall),
            ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Link to Goal', style: theme.textTheme.titleSmall),
            DropdownButton<String?>(
              value: _linkedGoalId,
              hint: const Text('None'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
              ],
              onChanged: (v) => setState(() => _linkedGoalId = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_titleController.text.trim().isEmpty) return;
                context.read<AppState>().addFinance(
                  title: _titleController.text.trim(),
                  description: _descController.text.trim(),
                  targetAmount: amount,
                  targetDays: days,
                  linkedGoalId: _linkedGoalId,
                );
                Navigator.pop(context);
              },
              child: const Text('Create Savings Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
