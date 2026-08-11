import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/note.dart';
import '../../logic/app_state.dart';
import '../widgets/shared_widgets.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchController = TextEditingController();
  String _folder = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allNotes = state.notesRepo.search(_searchController.text);
    final folders = <String>{'All', ...allNotes.map((note) => note.folder)};
    final notes = allNotes
        .where((note) => _folder == 'All' || note.folder == _folder)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search notes, folders, and tags',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: folders
                      .map(
                        (folder) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(folder),
                            selected: _folder == folder,
                            onSelected: (_) => setState(() => _folder = folder),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: _searchController.text.isEmpty
                      ? 'No notes yet'
                      : 'No matching notes',
                  subtitle: _searchController.text.isEmpty
                      ? 'Capture a thought and link it to your progress.'
                      : 'Try another search term or folder.',
                  actionLabel: 'New Note',
                  onAction: () => showAddNoteDialog(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: notes.length,
                  itemBuilder: (_, index) => _NoteTile(note: notes[index]),
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
    final linkLabel = _linkedLabel(state, note);

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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
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
                    if (note.mood != null) Icon(note.mood!.icon, size: 18),
                  ],
                ),
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(icon: Icons.folder_outlined, label: note.folder),
                    if (linkLabel != null)
                      _MetaChip(icon: Icons.link, label: linkLabel),
                    ...note.tags.map(
                      (tag) => _MetaChip(icon: Icons.tag, label: tag),
                    ),
                    if (note.attachmentPaths.isNotEmpty)
                      _MetaChip(
                        icon: Icons.attach_file,
                        label: '${note.attachmentPaths.length} attachment(s)',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _linkedLabel(AppState state, Note note) {
    final id = note.linkedEntityId;
    if (id == null) return null;
    switch (note.linkedEntityType) {
      case 'goal':
        final matches = state.goalsRepo
            .getAll(includeArchived: true)
            .where((goal) => goal.id == id);
        return matches.isEmpty ? 'Goal' : 'Goal: ${matches.first.title}';
      case 'habit':
        return 'Habit: ${state.habitsRepo.getById(id)?.name ?? 'Unavailable'}';
      case 'task':
        return 'Task: ${state.tasksRepo.getById(id)?.title ?? 'Unavailable'}';
      case 'finance':
        return 'Savings: ${state.savingsGoalsRepo.getById(id)?.title ?? 'Unavailable'}';
      default:
        return null;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
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
  final _folderController = TextEditingController(text: 'Notes');
  final _tagsController = TextEditingController();
  final _attachmentsController = TextEditingController();
  int _moodIndex = -1;
  String? _link;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _folderController.dispose();
    _tagsController.dispose();
    _attachmentsController.dispose();
    super.dispose();
  }

  void _wrapSelection(String before, [String after = '']) {
    final value = _bodyController.value;
    final start =
        value.selection.start < 0 ? value.text.length : value.selection.start;
    final end =
        value.selection.end < 0 ? value.text.length : value.selection.end;
    final selected = value.text.substring(start, end);
    final replacement = '$before$selected$after';
    _bodyController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final links = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('No link')),
      ...state.goalsRepo.getActive().map(
            (goal) => DropdownMenuItem(
              value: 'goal:${goal.id}',
              child: Text('Goal · ${goal.title}'),
            ),
          ),
      ...state.habitsRepo.getAll().map(
            (habit) => DropdownMenuItem(
              value: 'habit:${habit.id}',
              child: Text('Habit · ${habit.name}'),
            ),
          ),
      ...state.tasksRepo.getAll().map(
            (task) => DropdownMenuItem(
              value: 'task:${task.id}',
              child: Text('Task · ${task.title}'),
            ),
          ),
      ...state.savingsGoalsRepo.getAll().map(
            (sg) => DropdownMenuItem(
              value: 'finance:${sg.id}',
              child: Text('Savings · ${sg.title}'),
            ),
          ),
    ];

    return AlertDialog(
      title: const Text('Quick Capture'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Bold',
                    onPressed: () => _wrapSelection('**', '**'),
                    icon: const Icon(Icons.format_bold),
                  ),
                  IconButton(
                    tooltip: 'Italic',
                    onPressed: () => _wrapSelection('_', '_'),
                    icon: const Icon(Icons.format_italic),
                  ),
                  IconButton(
                    tooltip: 'Bullet list',
                    onPressed: () => _wrapSelection('\n- '),
                    icon: const Icon(Icons.format_list_bulleted),
                  ),
                  IconButton(
                    tooltip: 'Checklist',
                    onPressed: () => _wrapSelection('\n- [ ] '),
                    icon: const Icon(Icons.check_box_outlined),
                  ),
                ],
              ),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Formatting is saved with lightweight Markdown.',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _folderController,
                      decoration: const InputDecoration(labelText: 'Folder'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'comma, separated',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _link ?? '',
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Link to progress'),
                items: links,
                onChanged: (value) => _link = value,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _attachmentsController,
                decoration: const InputDecoration(
                  labelText: 'Attachment paths or file links',
                  hintText: 'image.jpg, recording.m4a, document.pdf',
                  prefixIcon: Icon(Icons.attach_file),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: List.generate(Mood.values.length, (index) {
                  return ChoiceChip(
                    avatar: Icon(Mood.values[index].icon, size: 16),
                    label: Text(Mood.values[index].label),
                    selected: _moodIndex == index,
                    onSelected: (selected) => setState(
                      () => _moodIndex = selected ? index : -1,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            final linkParts = (_link ?? '').split(':');
            state.addNote(
              title: title,
              body: _bodyController.text.trim(),
              moodIndex: _moodIndex,
              folder: _folderController.text.trim().isEmpty
                  ? 'Notes'
                  : _folderController.text.trim(),
              tags: _splitValues(_tagsController.text),
              attachmentPaths: _splitValues(_attachmentsController.text),
              linkedEntityType: linkParts.length == 2 ? linkParts[0] : null,
              linkedEntityId: linkParts.length == 2 ? linkParts[1] : null,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<String> _splitValues(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

void showAddNoteDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _AddNoteDialog());
}
