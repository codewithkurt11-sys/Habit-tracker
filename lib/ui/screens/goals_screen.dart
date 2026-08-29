import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/goal.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = _tab == 0 ? state.goalsRepo.getActive() : state.goalsRepo.getCompleted();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Goals', style: Theme.of(context).textTheme.headlineSmall),
            Text(_tab == 0 ? '${goals.length} ongoing goals' : '${goals.length} completed goals', style: Theme.of(context).textTheme.bodySmall),
          ])),
          IconButton(tooltip: 'Add goal', icon: const Icon(Icons.add_circle_outline), onPressed: () => showAddGoalDialog(context)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: SegmentedButton<int>(
          segments: const [ButtonSegment(value: 0, label: Text('Ongoing'), icon: Icon(Icons.timelapse)), ButtonSegment(value: 1, label: Text('Completed'), icon: Icon(Icons.check_circle_outline))],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
      ),
      Expanded(
        child: goals.isEmpty
            ? EmptyState(
                icon: _tab == 0 ? Icons.track_changes_outlined : Icons.emoji_events_outlined,
                title: _tab == 0 ? 'No ongoing goals' : 'No completed goals',
                subtitle: _tab == 0 ? 'Set a goal and connect the habits, tasks or finance that drive it.' : 'Completed goals will appear here.',
                actionLabel: _tab == 0 ? 'Add Goal' : null,
                onAction: _tab == 0 ? () => showAddGoalDialog(context) : null,
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                itemCount: goals.length,
                itemBuilder: (_, i) => _GoalTile(goal: goals[i]),
              ),
      ),
    ]);
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final progress = state.computeGoalProgress(goal.id);
    final linkedHabits = state.habitsForGoal(goal).length;
    final linkedTasks = state.tasksForGoal(goal).length;
    final linkedNotes = state.notesRepo.getForEntity('goal', goal.id).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Dismissible(
        key: ValueKey(goal.id),
        direction: DismissDirection.endToStart,
        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: AppSpacing.lg), color: theme.colorScheme.error, child: const Icon(Icons.delete, color: Colors.white)),
        confirmDismiss: (_) => showDeleteConfirmation(context, itemName: 'goal', message: 'Delete "${goal.title}" and its connections?'),
        onDismissed: (_) => state.deleteGoal(goal.id),
        child: Card(
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id))),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(goal.category.icon, color: goal.color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(goal.title, style: theme.textTheme.titleMedium)),
                  if (!goal.completed && goal.daysLeft >= 0) PillChip(label: goal.daysLeft == 0 ? 'Today' : '${goal.daysLeft}d', color: goal.daysLeft <= 3 ? theme.colorScheme.error : goal.color, icon: Icons.event_outlined),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Edit', onPressed: () => showEditGoalDialog(context, goal)),
                ]),
                if (goal.description.isNotEmpty) Text(goal.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08), valueColor: AlwaysStoppedAnimation(goal.color))),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${(progress * goal.targetValue).toStringAsFixed(0)} / ${goal.targetValue.toStringAsFixed(0)}'),
                  Text('${(progress * 100).round()}%', style: TextStyle(color: goal.color, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (linkedHabits > 0) PillChip(label: '$linkedHabits habits', icon: Icons.repeat, color: goal.color),
                  if (linkedTasks > 0) PillChip(label: '$linkedTasks tasks', icon: Icons.check_circle_outline, color: goal.color),
                  if (linkedNotes > 0) PillChip(label: '$linkedNotes notes', icon: Icons.sticky_note_2_outlined, color: goal.color),
                  if (goal.completed) const PillChip(label: 'Completed', icon: Icons.check_circle),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalEditorDialog extends StatefulWidget {
  final Goal? goal;
  const _GoalEditorDialog({this.goal});

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _target;
  late int _category;
  late DateTime _startDate;
  DateTime? _deadline;
  late GoalProgressMode _mode;
  late Set<String> _habitIds;
  late Set<String> _taskIds;
  String? _financeId;
  late Set<String> _savingsIds;

  bool get editing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _title = TextEditingController(text: g?.title ?? '');
    _description = TextEditingController(text: g?.description ?? '');
    _target = TextEditingController(text: (g?.targetValue ?? 100).toStringAsFixed(0));
    _category = g?.categoryIndex ?? GoalCategory.personal.index;
    _startDate = g?.startDate ?? DateTime.now();
    _deadline = g?.deadline;
    _mode = g?.progressMode ?? GoalProgressMode.auto;
    final state = context.read<AppState>();
    // Preselect from the canonical relationship (falling back to the legacy
    // reverse array only for entities that have no canonical owner).
    _habitIds = g == null
        ? <String>{}
        : state.habitsForGoal(g).map((h) => h.id).toSet();
    _taskIds = g == null
        ? <String>{}
        : state.tasksForGoal(g).where((t) => !t.isRecurring).map((t) => t.id).toSet();
    final linkedFinance = g == null
        ? null
        : state.financeRepo.getAll().where((e) => e.goalId == g.id || e.linkedGoalId == g.id).firstOrNull;
    _financeId = g?.linkedFinanceId ?? linkedFinance?.id;
    _savingsIds = {...state.savingsGoalsRepo.getForGoal(g?.id ?? '').map((s) => s.id)};
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); _target.dispose(); super.dispose(); }

  Future<void> _pickDate({required bool deadline}) async {
    final initial = deadline ? (_deadline ?? _startDate.add(const Duration(days: 30))) : _startDate;
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null) return;
    if (deadline && picked.isBefore(_startDate)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deadline cannot be before the start date.')));
      return;
    }
    if (!deadline && _deadline != null && _deadline!.isBefore(picked)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start date cannot be after the deadline.')));
      return;
    }
    setState(() { if (deadline) _deadline = picked; else _startDate = picked; });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final target = double.tryParse(_target.text.trim());
    if (title.isEmpty || target == null || target <= 0) return;
    final state = context.read<AppState>();
    if (editing) {
      final g = widget.goal!;
      g.title = title;
      g.description = _description.text.trim();
      g.categoryIndex = _category;
      g.targetValue = target;
      g.startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
      g.deadline = _deadline == null ? null : DateTime(_deadline!.year, _deadline!.month, _deadline!.day);
      g.progressMode = _mode;
      await state.updateGoal(g, habitIds: _habitIds.toList(), taskIds: _taskIds.toList(), financeId: _financeId, savingsIds: _savingsIds.toList(), clearFinance: _financeId == null);
    } else {
      final goal = await state.addGoal(title: title, description: _description.text.trim(), categoryIndex: _category, deadline: _deadline, targetValue: target, colorValue: GoalCategory.values[_category].color.toARGB32(), startDate: _startDate, progressMode: _mode);
      await state.updateGoal(goal, habitIds: _habitIds.toList(), taskIds: _taskIds.toList(), financeId: _financeId, savingsIds: _savingsIds.toList(), clearFinance: true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final state = context.watch<AppState>();
    final habits = state.habitsRepo.getAll();
    final tasks = state.tasksRepo.getAll(includeArchived: true);
    final finance = state.financeRepo.getAll().where((f) => f.isIncome).toList();
    return AlertDialog(
      title: Text(editing ? 'Edit Goal' : 'New Goal'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Goal name'), autofocus: !editing),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: AppSpacing.md),
          Align(alignment: Alignment.centerLeft, child: Text('Category', style: theme.textTheme.labelLarge)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: List.generate(GoalCategory.values.length, (i) { final c=GoalCategory.values[i]; final selected=i==_category; return ChoiceChip(label: Text(c.label), selected:selected, avatar:Icon(c.icon,size:16), onSelected:(_)=>setState(()=>_category=i)); })),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<GoalProgressMode>(initialValue: _mode, decoration: const InputDecoration(labelText: 'Progress tracking'), items: const [
            DropdownMenuItem(value: GoalProgressMode.auto, child: Text('Automatic (based on connections)')),
            DropdownMenuItem(value: GoalProgressMode.habitDays, child: Text('Habit days completed')),
            DropdownMenuItem(value: GoalProgressMode.taskCount, child: Text('Completed tasks')),
            DropdownMenuItem(value: GoalProgressMode.financeAmount, child: Text('Money / savings amount')),
            DropdownMenuItem(value: GoalProgressMode.manual, child: Text('Manual progress')),
            DropdownMenuItem(value: GoalProgressMode.mixed, child: Text('Mixed (average connected sources)')),
          ], onChanged:(v)=>setState(()=>_mode=v ?? GoalProgressMode.auto)),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _target, decoration: const InputDecoration(labelText: 'Target units'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [Expanded(child: ListTile(contentPadding:EdgeInsets.zero, title:const Text('Start'), subtitle:Text('${_startDate.month}/${_startDate.day}/${_startDate.year}'), onTap:()=>_pickDate(deadline:false))), Expanded(child: ListTile(contentPadding:EdgeInsets.zero, title:const Text('Deadline'), subtitle:Text(_deadline==null?'None':'${_deadline!.month}/${_deadline!.day}/${_deadline!.year}'), onTap:()=>_pickDate(deadline:true)))]),
          const Divider(),
          Align(alignment: Alignment.centerLeft, child: Text('Connected habits', style: theme.textTheme.titleSmall)),
          const SizedBox(height: 4),
          if (habits.isEmpty) Text('Create a habit first.', style: theme.textTheme.bodySmall) else ...habits.map((h) => CheckboxListTile(contentPadding:EdgeInsets.zero, dense:true, value:_habitIds.contains(h.id), title:Text(h.name), subtitle:Text(h.frequency.name), onChanged:(v)=>setState(()=>v==true?_habitIds.add(h.id):_habitIds.remove(h.id)))),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: Text('Connected tasks', style: theme.textTheme.titleSmall)),
          if (tasks.isEmpty) Text('Create a task first.', style: theme.textTheme.bodySmall) else ...tasks.take(30).map((t) => CheckboxListTile(contentPadding:EdgeInsets.zero, dense:true, value:_taskIds.contains(t.id), title:Text(t.title), subtitle:Text(t.status.name), onChanged:(v)=>setState(()=>v==true?_taskIds.add(t.id):_taskIds.remove(t.id)))),
          const SizedBox(height: 4),
          DropdownButtonFormField<String?>(initialValue:_financeId, decoration: const InputDecoration(labelText:'Connected finance income (optional)'), items:[const DropdownMenuItem<String?>(value:null,child:Text('None')), ...finance.map((f)=>DropdownMenuItem<String?>(value:f.id,child:Text('${f.title} — ₱${f.amount.toStringAsFixed(0)}')))], onChanged:(v)=>setState(()=>_financeId=v)),
          const SizedBox(height: AppSpacing.sm),
          Align(alignment: Alignment.centerLeft, child: Text('Connected savings goals', style: theme.textTheme.titleSmall)),
          ...state.savingsGoalsRepo.getAll().map((saving) => CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: _savingsIds.contains(saving.id), title: Text(saving.title), subtitle: Text('₱${saving.targetAmount.toStringAsFixed(0)} target'), onChanged: (v) => setState(() => v == true ? _savingsIds.add(saving.id) : _savingsIds.remove(saving.id)))),
        ])),
      ),
      actions: [TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')), FilledButton(onPressed:_save,child:Text(editing?'Save changes':'Create goal'))],
    );
  }
}

void showAddGoalDialog(BuildContext context) => showDialog(context: context, builder: (_) => const _GoalEditorDialog());
void showEditGoalDialog(BuildContext context, Goal goal) => showDialog(context: context, builder: (_) => _GoalEditorDialog(goal: goal));
