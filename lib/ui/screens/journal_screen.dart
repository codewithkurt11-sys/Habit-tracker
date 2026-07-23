import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/journal_entry.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.journalRepo.getAll()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: 'Journal',
              subtitle: '${entries.length} entries',
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.book_outlined,
                      title: 'No journal entries',
                      subtitle: 'Start writing to reflect on your day',
                      actionLabel: 'Write Entry',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _AddJournalDialog(),
        ),
        child: const Icon(Icons.add),
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
      onDismissed: (_) => state.deleteJournal(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: InkWell(
            onTap: () {},
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

class _AddJournalDialog extends StatefulWidget {
  const _AddJournalDialog();

  @override
  State<_AddJournalDialog> createState() => _AddJournalDialogState();
}

class _AddJournalDialogState extends State<_AddJournalDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _moodIndex = -1; // -1 = no mood

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New Journal Entry'),
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
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'What happened today?',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Mood', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: List.generate(JournalMood.values.length, (i) {
                final sel = i == _moodIndex;
                final m = JournalMood.values[i];
                return GestureDetector(
                  onTap: () => setState(() => _moodIndex = i),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: sel ? m.color.withValues(alpha: 0.2) : null,
                      border: Border.all(
                        color: sel
                            ? m.color
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.15),
                        width: sel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                        child: Text(m.emoji,
                            style: const TextStyle(fontSize: 22))),
                  ),
                );
              }),
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
            if (title.isEmpty) return;
            context.read<AppState>().addJournal(
                  title: title,
                  body: _bodyController.text.trim(),
                  moodIndex: _moodIndex,
                  date: DateTime.now(),
                );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
