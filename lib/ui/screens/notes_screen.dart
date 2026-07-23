import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../data/models/note.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notes = state.notesRepo.getAll()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('${notes.length} notes',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'No notes yet',
                  subtitle: 'Jot down quick thoughts and ideas',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _NoteTile(note: notes[i]),
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteNote(note.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                          Text(note.title, style: theme.textTheme.titleSmall),
                    ),
                    if (note.mood != null)
                      Icon(note.mood!.icon,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                  ],
                ),
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note.body,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${note.timestamp.month}/${note.timestamp.day} '
                  '${note.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${note.timestamp.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _moodIndex = -1;

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
      title: const Text('New Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Quick title',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Write your thoughts...',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Mood (optional)', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: List.generate(Mood.values.length, (i) {
                final sel = i == _moodIndex;
                return GestureDetector(
                  onTap: () => setState(() => _moodIndex = sel ? -1 : i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : null,
                      border: Border.all(
                        color: sel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.15),
                        width: sel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Mood.values[i].icon,
                        size: 20,
                        color: sel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface),
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
            context.read<AppState>().addNote(
                  title: title,
                  body: _bodyController.text.trim(),
                  moodIndex: _moodIndex,
                );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Global FAB action — call from the parent Scaffold.
void showAddNoteDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _AddNoteDialog(),
  );
}
