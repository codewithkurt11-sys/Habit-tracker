import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../logic/stats_engine.dart';
import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/goal.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'calendar_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    final habits = state.habitsRepo.getAll();
    final tasks = state.tasksRepo.getAll(includeArchived: true);
    final focusSessions = state.focusRepo.getAll();
    final financeEntries = state.financeRepo.getAll();
    final goals = state.goalsRepo.getAll(includeArchived: true);

    final insights = StatsEngine.generateInsights(
      habits: habits,
      tasks: tasks,
      focusSessions: focusSessions,
    );

    final weeklyData = StatsEngine.weeklyCompletionCounts(habits, 12);
    final dailyData = StatsEngine.dailyCompletionCounts(habits, 7);
    final focusDaily = StatsEngine.dailyFocusMinutes(focusSessions, 7);
    final expenseTrend = StatsEngine.monthlyExpenseTrend(financeEntries);
    final incomeTrend = StatsEngine.monthlyIncomeTrend(financeEntries);

    final now = DateTime.now();
    final monthIncome = StatsEngine.monthlyIncome(financeEntries, now.year, now.month);
    final monthExpense = StatsEngine.monthlyExpenses(financeEntries, now.year, now.month);
    final categoryBreakdown = StatsEngine.expenseByCategory(financeEntries, now.year, now.month);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Analytics',
              subtitle: 'Your productivity insights',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  // Key metrics row
                  _KeyMetricsRow(habits: habits, tasks: tasks, focusSessions: focusSessions),
                  const SizedBox(height: AppSpacing.md),

                  // Insights cards
                  if (insights.isNotEmpty) ...[
                    _SectionLabel('Insights'),
                    ...insights.map((ins) => _InsightCard(insight: ins)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Weekly habit completion chart
                  _SectionLabel('Habit Completion Trends'),
                  _BarChartCard(
                    title: 'Weekly Completions (12 weeks)',
                    data: weeklyData,
                    color: ext.categoryLifestyle,
                    unit: '',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Daily this week
                  _BarChartCard(
                    title: 'This Week (daily)',
                    data: dailyData,
                    color: ext.categoryWorkout,
                    unit: '',
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Focus chart
                  _SectionLabel('Focus Analytics'),
                  _BarChartCard(
                    title: 'Focus Minutes (this week)',
                    data: focusDaily,
                    color: ext.success,
                    unit: 'm',
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Finance overview
                  _SectionLabel('Finance Overview'),
                  _FinanceOverviewCard(
                    income: monthIncome,
                    expenses: monthExpense,
                    expenseTrend: expenseTrend,
                    incomeTrend: incomeTrend,
                    categoryBreakdown: categoryBreakdown,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Goals progress
                  _SectionLabel('Goals Progress'),
                  _GoalsProgressCard(goals: goals),
                  const SizedBox(height: AppSpacing.md),

                  // Heatmap link
                  _SectionLabel('Activity Calendar'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Card(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Calendar')),
                              body: const CalendarScreen(),
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('GitHub-style Heatmap', style: theme.textTheme.titleSmall),
                                    Text('View your activity calendar', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _KeyMetricsRow extends StatelessWidget {
  final List<Habit> habits;
  final List<Task> tasks;
  final List<FocusSession> focusSessions;
  const _KeyMetricsRow({required this.habits, required this.tasks, required this.focusSessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    final bestStreak = StatsEngine.bestStreakAcross(habits);
    final currentStreak = StatsEngine.currentStreakAcross(habits);
    final completionRate = StatsEngine.overallCompletionRate(habits);
    final totalFocus = StatsEngine.totalFocusMinutes(focusSessions);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: _MetricCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Best Streak',
            value: '$bestStreak',
            sub: 'days',
            color: const Color(0xFFE8946F),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _MetricCard(
            icon: Icons.bolt,
            label: 'Current',
            value: '$currentStreak',
            sub: 'days',
            color: const Color(0xFFE8C56F),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _MetricCard(
            icon: Icons.check_circle_outline,
            label: 'Completion',
            value: '${(completionRate * 100).round()}',
            sub: '%',
            color: ext.categoryLifestyle,
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _MetricCard(
            icon: Icons.timer_outlined,
            label: 'Focus',
            value: '${(totalFocus / 60).toStringAsFixed(1)}',
            sub: 'hrs',
            color: ext.success,
          )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: value),
                  TextSpan(text: ' $sub', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final HabitInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bgColor;
    switch (insight.type) {
      case InsightType.achievement:
        bgColor = const Color(0xFFE8946F);
      case InsightType.streak:
        bgColor = const Color(0xFFE8C56F);
      case InsightType.progress:
        bgColor = const Color(0xFF6B9080);
      case InsightType.focus:
        bgColor = const Color(0xFF7B93B5);
      case InsightType.warning:
        bgColor = const Color(0xFFD4675A);
      case InsightType.tip:
        bgColor = const Color(0xFFB58BB5);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.radiusSmall)),
                child: Center(child: Text(insight.icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.title, style: theme.textTheme.titleSmall?.copyWith(color: bgColor)),
                    const SizedBox(height: 2),
                    Text(insight.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final String title;
  final List<int> data;
  final Color color;
  final String unit;
  final List<String>? labels;
  const _BarChartCard({required this.title, required this.data, required this.color, required this.unit, this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = data.isEmpty ? 1 : (data.reduce((a, b) => a > b ? a : b).clamp(1, 999999));
    final showLabels = labels != null && labels!.length == data.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(data.length, (i) {
                    final h = maxVal == 0 ? 0.0 : (data[i] / maxVal) * 100;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < data.length - 1 ? 3 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (data[i] > 0)
                              Text('${data[i]}$unit', style: theme.textTheme.bodySmall?.copyWith(fontSize: 9)),
                            const SizedBox(height: 2),
                            Container(
                              height: h.clamp(2, 100),
                              decoration: BoxDecoration(
                                color: data[i] == 0 ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (showLabels) ...[
                              const SizedBox(height: 4),
                              Text(labels![i], style: theme.textTheme.bodySmall?.copyWith(fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceOverviewCard extends StatelessWidget {
  final double income;
  final double expenses;
  final List<double> expenseTrend;
  final List<double> incomeTrend;
  final Map<String, double> categoryBreakdown;
  const _FinanceOverviewCard({required this.income, required this.expenses, required this.expenseTrend, required this.incomeTrend, required this.categoryBreakdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final balance = income - expenses;
    var maxTrend = [...expenseTrend, ...incomeTrend].fold(0.0, (a, b) => a > b ? a : b);
    if (maxTrend == 0) maxTrend = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This Month', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _FinanceMiniStat(label: 'Income', value: '\$${income.toStringAsFixed(0)}', color: ext.success)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _FinanceMiniStat(label: 'Expenses', value: '\$${expenses.toStringAsFixed(0)}', color: theme.colorScheme.error)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _FinanceMiniStat(label: 'Balance', value: '\$${balance.toStringAsFixed(0)}', color: balance >= 0 ? ext.success : theme.colorScheme.error)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // 6-month trend
              Text('6-Month Trend', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(6, (i) {
                    final expH = (expenseTrend[i] / maxTrend) * 60;
                    final incH = (incomeTrend[i] / maxTrend) * 60;
                    final months = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 5 ? 4 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 8, height: incH.clamp(1, 60), decoration: BoxDecoration(color: ext.success.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 2),
                                Container(width: 8, height: expH.clamp(1, 60), decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(months[i], style: theme.textTheme.bodySmall?.copyWith(fontSize: 9)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (categoryBreakdown.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Top Categories', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                ...categoryBreakdown.entries.take(4).map((e) {
                  final pct = expenses > 0 ? (e.value / expenses * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 80, child: Text(e.key, style: theme.textTheme.bodySmall)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.error.withValues(alpha: 0.6)),
                            ),
                          ),
                        ),
                        SizedBox(width: 50, child: Text('\$${e.value.toStringAsFixed(0)}', style: theme.textTheme.bodySmall, textAlign: TextAlign.right)),
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

class _FinanceMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSpacing.radiusSmall)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _GoalsProgressCard extends StatelessWidget {
  final List<Goal> goals;
  const _GoalsProgressCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = goals.where((g) => !g.completed && !g.archived).toList();
    final avgProgress = StatsEngine.averageGoalProgress(goals);
    final completedCount = StatsEngine.completedGoals(goals);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Active Goals: ${active.length}', style: theme.textTheme.titleSmall)),
                  Text('Completed: $completedCount', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lightSuccess)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Average Progress', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: avgProgress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text('${(avgProgress * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              if (active.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ...active.take(3).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(g.category.icon, size: 16, color: g.color),
                      const SizedBox(width: 6),
                      Expanded(child: Text(g.title, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${(g.progressFraction * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall?.copyWith(color: g.color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
