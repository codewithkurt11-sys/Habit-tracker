import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/recurrence_rule.dart';

class RecurrenceEditorDialog extends StatefulWidget {
  final RecurrenceRule? initial;
  const RecurrenceEditorDialog({super.key, this.initial});

  @override
  State<RecurrenceEditorDialog> createState() => _RecurrenceEditorDialogState();
}

class _RecurrenceEditorDialogState extends State<RecurrenceEditorDialog> {
  late RecurrenceType _type;
  late int _interval;
  late RecurrenceIntervalUnit _intervalUnit;
  late List<int> _weekdays;
  late String _monthDaysText;
  int _yearMonth = 1;
  int _yearDay = 1;
  int _nthWeekday = 1;
  int _nthWeekdayDay = 1;
  late RecurrencePeriod _period;
  late int _times;
  late bool _flexible;
  late int _activeDays;
  late int _restDays;
  DateTime? _startDate;
  DateTime? _endDate;
  late TextEditingController _intervalController;
  late TextEditingController _timesController;
  late TextEditingController _activeController;
  late TextEditingController _restController;
  late TextEditingController _monthDaysController;

  @override
  void initState() {
    super.initState();
    final r = widget.initial ??
        RecurrenceRule(type: RecurrenceType.daily, startDate: DateTime.now());
    _type = r.type;
    _interval = r.interval;
    _intervalUnit = r.intervalUnit;
    _weekdays = r.weekdays.isEmpty ? [DateTime.monday] : List.from(r.weekdays);
    _monthDaysText = r.monthDays.join(', ');
    _yearMonth = r.month ?? 1;
    _yearDay = r.dayOfMonth ?? 1;
    _nthWeekday = r.nthWeekday ?? 1;
    _nthWeekdayDay = r.nthWeekdayDay ?? 1;
    _period = r.period ?? RecurrencePeriod.week;
    _times = r.occurrencesPerPeriod ?? 1;
    _flexible = r.flexible;
    _activeDays = r.activeDays;
    _restDays = r.restDays;
    _startDate = r.startDate == null ? null : DateTime(r.startDate!.year, r.startDate!.month, r.startDate!.day);
    _endDate = r.endDate == null ? null : DateTime(r.endDate!.year, r.endDate!.month, r.endDate!.day);
    _intervalController = TextEditingController(text: '$_interval');
    _timesController = TextEditingController(text: '$_times');
    _activeController = TextEditingController(text: '$_activeDays');
    _restController = TextEditingController(text: '$_restDays');
    _monthDaysController = TextEditingController(text: _monthDaysText);
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _timesController.dispose();
    _activeController.dispose();
    _restController.dispose();
    _monthDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final current = end ? _endDate : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        if (_startDate != null && picked.isBefore(_startDate!)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot be before the start date.')));
          return;
        }
        _endDate = picked;
      } else {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      }
    });
  }

  void _save() {
    if (_type == RecurrenceType.weeklyDays && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one weekday.')));
      return;
    }
    if (_type == RecurrenceType.timesPerPeriod && !_flexible && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one allowed weekday, or enable flexible days.')));
      return;
    }
    final interval = int.tryParse(_intervalController.text.trim()) ?? 1;
    final times = int.tryParse(_timesController.text.trim()) ?? 1;
    final active = int.tryParse(_activeController.text.trim()) ?? 1;
    final rest = int.tryParse(_restController.text.trim()) ?? 1;
    if (interval < 1 || times < 1 || active < 1 || rest < 0) {
      _error('Values must be positive (rest days may be 0).');
      return;
    }

    final rawMonthTokens = _monthDaysText
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final parsedMonthValues = rawMonthTokens.map(int.tryParse).toList();
    if (_type == RecurrenceType.monthlyDates && rawMonthTokens.isNotEmpty &&
        parsedMonthValues.any((v) => v == null || v < 1 || v > 31)) {
      _error('Monthly dates must be whole numbers from 1 to 31.');
      return;
    }
    final monthDays = parsedMonthValues.whereType<int>().toSet().toList()..sort();
    if (_type == RecurrenceType.weeklyDays && _weekdays.isEmpty) {
      _error('Select at least one weekday.');
      return;
    }
    if (_type == RecurrenceType.monthlyDates && monthDays.isEmpty && _nthWeekdayDay == 0) {
      _error('Choose at least one monthly date or weekday rule.');
      return;
    }
    if (_type == RecurrenceType.monthlyDates && monthDays.isEmpty && _nthWeekdayDay != 0 && (_nthWeekday < -1 || _nthWeekday > 5)) {
      _error('Choose a valid monthly weekday occurrence.');
      return;
    }

    final rule = RecurrenceRule(
      type: _type,
      interval: interval,
      intervalUnit: _intervalUnit,
      weekdays: List.from(_weekdays)..sort(),
      monthDays: monthDays,
      month: _yearMonth,
      dayOfMonth: _yearDay,
      nthWeekday: monthDays.isEmpty && _type == RecurrenceType.monthlyDates ? _nthWeekday : null,
      nthWeekdayDay: monthDays.isEmpty && _type == RecurrenceType.monthlyDates ? _nthWeekdayDay : null,
      period: _period,
      occurrencesPerPeriod: times,
      activeDays: active,
      restDays: rest,
      flexible: _flexible,
      startDate: _startDate,
      endDate: _endDate,
    );
    Navigator.of(context).pop(rule);
  }

  RecurrenceRule _buildRule() {
    final interval = int.tryParse(_intervalController.text.trim()) ?? _interval;
    final times = int.tryParse(_timesController.text.trim()) ?? _times;
    final active = int.tryParse(_activeController.text.trim()) ?? _activeDays;
    final rest = int.tryParse(_restController.text.trim()) ?? _restDays;
    final monthDays = _monthDaysController.text
        .split(',')
        .map((v) => int.tryParse(v.trim()))
        .whereType<int>()
        .where((v) => v >= 1 && v <= 31)
        .toSet()
        .toList()..sort();
    return RecurrenceRule(
      type: _type,
      interval: interval < 1 ? 1 : interval,
      intervalUnit: _intervalUnit,
      weekdays: List<int>.from(_weekdays)..sort(),
      monthDays: monthDays,
      month: _yearMonth,
      dayOfMonth: _yearDay,
      nthWeekday: monthDays.isEmpty && _type == RecurrenceType.monthlyDates ? _nthWeekday : null,
      nthWeekdayDay: monthDays.isEmpty && _type == RecurrenceType.monthlyDates ? _nthWeekdayDay : null,
      period: _period,
      occurrencesPerPeriod: times < 1 ? 1 : times,
      activeDays: active < 1 ? 1 : active,
      restDays: rest < 0 ? 0 : rest,
      flexible: _flexible,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return AlertDialog(
      title: const Text('Recurrence schedule'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Repeat type'),
                items: const [
                  DropdownMenuItem(value: RecurrenceType.daily, child: Text('Every day')),
                  DropdownMenuItem(value: RecurrenceType.weeklyDays, child: Text('Specific days of the week')),
                  DropdownMenuItem(value: RecurrenceType.monthlyDates, child: Text('Specific days of the month')),
                  DropdownMenuItem(value: RecurrenceType.yearlyDate, child: Text('Specific day of the year')),
                  DropdownMenuItem(value: RecurrenceType.interval, child: Text('Every X days / weeks / months')),
                  DropdownMenuItem(value: RecurrenceType.timesPerPeriod, child: Text('X times per period')),
                  DropdownMenuItem(value: RecurrenceType.alternate, child: Text('Alternate active/rest days')),
                ],
                onChanged: (v) => setState(() => _type = v ?? RecurrenceType.daily),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_type == RecurrenceType.daily || _type == RecurrenceType.weeklyDays) ...[
                _numberField('Repeat interval', _intervalController, suffix: _type == RecurrenceType.daily ? 'day(s)' : 'week(s)'),
              ],
              if (_type == RecurrenceType.weeklyDays) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Weekdays', style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) => FilterChip(
                        label: Text(dayNames[i]),
                        selected: _weekdays.contains(i + 1),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _weekdays.add(i + 1);
                          } else {
                            _weekdays.remove(i + 1);
                          }
                        }),
                      )),
                ),
              ],
              if (_type == RecurrenceType.monthlyDates) ...[
                TextField(
                  controller: _monthDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Day number(s)', hintText: '1, 15, 30'),
                  onChanged: (v) => _monthDaysText = v,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Or a specific weekday occurrence', style: theme.textTheme.labelLarge),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _nthWeekday,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1st')), DropdownMenuItem(value: 2, child: Text('2nd')),
                      DropdownMenuItem(value: 3, child: Text('3rd')), DropdownMenuItem(value: 4, child: Text('4th')),
                      DropdownMenuItem(value: 5, child: Text('5th')), DropdownMenuItem(value: -1, child: Text('Last')),
                    ],
                    onChanged: (v) => setState(() => _nthWeekday = v ?? 1),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _nthWeekdayDay,
                    items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(dayNames[i]))),
                    onChanged: (v) => setState(() => _nthWeekdayDay = v ?? 1),
                  )),
                ]),
              ],
              if (_type == RecurrenceType.yearlyDate) ...[
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _yearMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (v) => setState(() => _yearMonth = v ?? 1),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _yearDay,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (v) => setState(() => _yearDay = v ?? 1),
                  )),
                ]),
              ],
              if (_type == RecurrenceType.interval) ...[
                _numberField('Repeat every', _intervalController),
                DropdownButtonFormField<RecurrenceIntervalUnit>(
                  initialValue: _intervalUnit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: RecurrenceIntervalUnit.days, child: Text('Days')),
                    DropdownMenuItem(value: RecurrenceIntervalUnit.weeks, child: Text('Weeks')),
                    DropdownMenuItem(value: RecurrenceIntervalUnit.months, child: Text('Months')),
                  ],
                  onChanged: (v) => setState(() => _intervalUnit = v ?? RecurrenceIntervalUnit.days),
                ),
              ],
              if (_type == RecurrenceType.timesPerPeriod) ...[
                _numberField('Occurrences', _timesController, suffix: 'time(s)'),
                DropdownButtonFormField<RecurrencePeriod>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: RecurrencePeriod.week, child: Text('Week')),
                    DropdownMenuItem(value: RecurrencePeriod.month, child: Text('Month')),
                    DropdownMenuItem(value: RecurrencePeriod.year, child: Text('Year')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? RecurrencePeriod.week),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Flexible days'),
                  subtitle: Text(_flexible ? 'The task can be completed on any days inside the period.' : 'Use selected weekdays inside the period.'),
                  value: _flexible,
                  onChanged: (v) => setState(() => _flexible = v),
                ),
                if (!_flexible) ...[
                  const SizedBox(height: 4),
                  Text('Allowed weekdays', style: theme.textTheme.labelLarge),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) => FilterChip(
                      label: Text(dayNames[i]),
                      selected: _weekdays.contains(i + 1),
                      onSelected: (selected) => setState(() {
                        if (selected) { _weekdays.add(i + 1); } else { _weekdays.remove(i + 1); }
                      }),
                    )),
                  ),
                ],
              ],
              if (_type == RecurrenceType.alternate) ...[
                Row(children: [
                  Expanded(child: _numberField('Active', _activeController, suffix: 'day(s)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField('Rest', _restController, suffix: 'day(s)')),
                ]),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: const Text('Start'),
                  subtitle: Text(_startDate == null ? 'Task due date / today' : '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'),
                  onTap: () => _pickDate(end: false),
                )),
                Expanded(child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop_outlined),
                  title: const Text('End'),
                  subtitle: Text(_endDate == null ? 'No end date' : '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'),
                  onTap: () => _pickDate(end: true),
                )),
              ]),
              Text('Schedule: ${_buildRule().summary}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save schedule')),
      ],
    );
  }

  Widget _numberField(String label, TextEditingController controller, {String? suffix}) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onChanged: (_) => setState(() {}),
      );
}
