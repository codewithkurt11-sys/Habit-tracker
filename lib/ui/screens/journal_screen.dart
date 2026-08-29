import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/journal_entry.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _search = TextEditingController();
  bool _favoritesOnly = false;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _search.text.trim().toLowerCase();
    final entries = state.journalRepo.getAll().where((e) {
      final matches = q.isEmpty || e.title.toLowerCase().contains(q) || e.body.toLowerCase().contains(q) || e.tags.any((t) => t.toLowerCase().contains(q));
      return matches && (!_favoritesOnly || e.isFavorite);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Journal',
              subtitle: '${entries.length} entries',
              onMenuTap: null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: _favoritesOnly ? 'Show all' : 'Favorites only', icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border), onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly)),
                IconButton(tooltip: 'New entry', icon: const Icon(Icons.add_circle_outline), onPressed: () => showAddJournalDialog(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Search journal', prefixIcon: Icon(Icons.search))),
              ),
            Expanded(
              child: entries.isEmpty
                  ? EmptyState(
                      icon: Icons.book_outlined,
                      title: 'No journal entries',
                      subtitle: 'Start writing to reflect on your day',
                      actionLabel: 'Write Entry',
                      onAction: () => showAddJournalDialog(context),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _JournalTile(entry: entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  final JournalEntry entry;
  const _JournalTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDeleteConfirmation(
        context,
        itemName: 'journal entry',
        message: 'Delete "${entry.title}"? This cannot be undone.',
      ),
      onDismissed: (_) => state.deleteJournal(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () => showEditJournalDialog(context, entry),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.title,
                            style: theme.textTheme.titleMedium),
                      ),
                      if (entry.mood != null)
                        Text(entry.mood!.emoji,
                            style: const TextStyle(fontSize: 20)),
                      IconButton(
                        tooltip: entry.isFavorite ? 'Unfavorite' : 'Favorite',
                        icon: Icon(
                          entry.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 20,
                          color:
                              entry.isFavorite ? const Color(0xFFE8C56F) : null,
                        ),
                        onPressed: () => state.toggleJournalFavorite(entry.id),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(entry.body,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: entry.tags.take(5).map((tag) => Chip(
                        label: Text('#$tag'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${entry.date.month}/${entry.date.day}/${entry.date.year}',
                    style: theme.textTheme.bodySmall,
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

void showAddJournalDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _JournalEditorDialog());
}

void showEditJournalDialog(BuildContext context, JournalEntry entry) {
  showDialog(
    context: context,
    builder: (_) => _JournalEditorDialog(entry: entry),
  );
}

class _JournalEditorDialog extends StatefulWidget {
  final JournalEntry? entry;
  const _JournalEditorDialog({this.entry});

  @override
  State<_JournalEditorDialog> createState() => _JournalEditorDialogState();
}

class _JournalEditorDialogState extends State<_JournalEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  late int _moodIndex;
  late DateTime _date;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _bodyController = TextEditingController(text: e?.body ?? '');
    _tagsController = TextEditingController(text: e?.tags.join(', ') ?? '');
    _moodIndex = e?.moodIndex ?? -1;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _tags() => _tagsController.text
      .split(',')
      .map((e) => e.trim().replaceFirst(RegExp(r'^#'), ''))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty) return;

    final state = context.read<AppState>();
    final tags = _tags();
    if (_editing) {
      final updated = widget.entry!.copyWith(
        title: title,
        body: body,
        moodIndex: _moodIndex,
        date: _date,
        tags: tags,
      );
      await state.updateJournal(updated);
    } else {
      await state.addJournal(
        title: title,
        body: body,
        moodIndex: _moodIndex,
        date: _date,
        tags: tags,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_editing ? 'Edit Journal Entry' : 'New Journal Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Give your entry a title',
              ),
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'What happened today?',
                alignLabelWithHint: true,
              ),
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'school, reflection, goals',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Entry date'),
              subtitle: Text('${_date.month}/${_date.day}/${_date.year}'),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Mood', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: _moodIndex == -1,
                  onSelected: (_) => setState(() => _moodIndex = -1),
                ),
                ...List.generate(JournalMood.values.length, (i) {
                  final m = JournalMood.values[i];
                  return ChoiceChip(
                    label: Text(m.emoji),
                    tooltip: m.label,
                    selected: _moodIndex == i,
                    onSelected: (_) => setState(() => _moodIndex = i),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: Text(_editing ? 'Save Changes' : 'Save')),
      ],
    );
  }
}
