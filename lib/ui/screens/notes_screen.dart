import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/note.dart';
import '../../logic/app_state.dart';
import '../widgets/shared_widgets.dart';
import 'habit_detail_screen.dart';
import 'goal_detail_screen.dart';
import 'tasks_screen.dart';
import 'finance_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchController = TextEditingController();
  String _folder = 'All';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allNotes = state.notesRepo.getAll(includeArchived: _showArchived).where((note) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return note.title.toLowerCase().contains(q) || note.body.toLowerCase().contains(q) || note.tags.any((t) => t.toLowerCase().contains(q)) || note.folder.toLowerCase().contains(q);
    }).toList();
    final folders = <String>{'All', ...allNotes.map((note) => note.folder)};
    final notes = allNotes
        .where((note) => _folder == 'All' || note.folder == _folder)
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

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
              Row(children: [
                Expanded(child: Text('Notes', style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(tooltip: _showArchived ? 'Show active notes' : 'Show archived', icon: Icon(_showArchived ? Icons.inventory_2_outlined : Icons.archive_outlined), onPressed: () => setState(() => _showArchived = !_showArchived)),
                IconButton(tooltip: 'New note', icon: const Icon(Icons.add_circle_outline), onPressed: () => showAddNoteDialog(context)),
              ]),
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
      confirmDismiss: (_) => showDeleteConfirmation(
        context,
        itemName: 'note',
        message: 'Delete "${note.title}"? This cannot be undone.',
      ),
      onDismissed: (_) => state.deleteNote(note.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Card(
          child: InkWell(
            onTap: () => showEditNoteDialog(context, note),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
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
                    IconButton(
                      tooltip: note.isPinned ? 'Unpin' : 'Pin',
                      icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      onPressed: () => state.toggleNotePinned(note.id),
                    ),
                    IconButton(
                      tooltip: note.isArchived ? 'Restore' : 'Archive',
                      icon: Icon(note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      onPressed: () => state.archiveNote(note.id, archived: !note.isArchived),
                    ),
                    _MetaChip(icon: Icons.folder_outlined, label: note.folder),
                    if (linkLabel != null)
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 14),
                        label: Text(linkLabel),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openLink(context, state, note),
                      ),
                    ...note.tags.map(
                      (tag) => _MetaChip(icon: Icons.tag, label: tag),
                    ),
                    ...note.attachmentPaths.take(4).map((path) => ActionChip(
                      avatar: const Icon(Icons.attach_file, size: 14),
                      label: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => OpenFilex.open(path),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _openLink(BuildContext context, AppState state, Note note) {
    final id = note.linkedEntityId;
    if (id == null) return;
    switch (note.linkedEntityType) {
      case 'goal':
        if (state.goalsRepo.getAll(includeArchived: true).any((g) => g.id == id)) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: id)));
        }
        return;
      case 'habit':
        if (state.habitsRepo.getById(id) != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: id)),
          );
        }
        return;
      case 'task':
        final task = state.tasksRepo.getById(id);
        if (task != null) showEditTaskDialog(context, task);
        return;
      case 'finance':
        final entry = state.financeRepo.getAll().where((e) => e.id == id).firstOrNull;
        if (entry != null) showEditFinanceDialog(context, entry);
        return;
    }
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
        return 'Finance: ${state.financeRepo.getAll().where((e) => e.id == id).firstOrNull?.title ?? 'Unavailable'}';
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

class _NoteEditorDialog extends StatefulWidget {
  final Note? note;
  const _NoteEditorDialog({this.note});

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _folderController;
  late final TextEditingController _tagsController;
  late final TextEditingController _attachmentsController;
  late int _moodIndex;
  String _link = '';

  bool get _editing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _folderController = TextEditingController(text: note?.folder ?? 'Notes');
    _tagsController = TextEditingController(text: note?.tags.join(', ') ?? '');
    _attachmentsController = TextEditingController(
      text: note?.attachmentPaths.join(', ') ?? '',
    );
    _moodIndex = note?.moodIndex ?? -1;
    if (note?.linkedEntityType != null && note?.linkedEntityId != null) {
      _link = '${note!.linkedEntityType}:${note.linkedEntityId}';
    }
  }

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
    final start = value.selection.start < 0 ? value.text.length : value.selection.start;
    final end = value.selection.end < 0 ? value.text.length : value.selection.end;
    final selected = value.text.substring(start, end);
    final replacement = '$before$selected$after';
    _bodyController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  List<String> _splitValues(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  ({String? type, String? id}) _parseLink(String value) {
    if (value.isEmpty) return (type: null, id: null);
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) {
      return (type: null, id: null);
    }
    final type = value.substring(0, separator);
    final id = value.substring(separator + 1);
    const validTypes = {'goal', 'habit', 'task', 'finance'};
    if (!validTypes.contains(type) || id.isEmpty) {
      return (type: null, id: null);
    }
    return (type: type, id: id);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final state = context.read<AppState>();
    final link = _parseLink(_link);
    final tags = _splitValues(_tagsController.text);
    final attachments = _splitValues(_attachmentsController.text);
    final folder = _folderController.text.trim().isEmpty
        ? 'Notes'
        : _folderController.text.trim();

    if (_editing) {
      final updated = widget.note!.copyWith(
        title: title,
        body: _bodyController.text.trim(),
        moodIndex: _moodIndex,
        folder: folder,
        tags: tags,
        attachmentPaths: attachments,
        linkedEntityType: link.type,
        linkedEntityId: link.id,
        clearLinkedEntity: link.type == null,
      );
      await state.updateNote(updated);
    } else {
      await state.addNote(
        title: title,
        body: _bodyController.text.trim(),
        moodIndex: _moodIndex,
        folder: folder,
        tags: tags,
        attachmentPaths: attachments,
        linkedEntityType: link.type,
        linkedEntityId: link.id,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final links = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('No link')),
      ...state.goalsRepo.getActive().map((goal) => DropdownMenuItem(
            value: 'goal:${goal.id}',
            child: Text('Goal · ${goal.title}'),
          )),
      ...state.habitsRepo.getAll().map((habit) => DropdownMenuItem(
            value: 'habit:${habit.id}',
            child: Text('Habit · ${habit.name}'),
          )),
      ...state.tasksRepo.getAll(includeArchived: true).map((task) => DropdownMenuItem(
            value: 'task:${task.id}',
            child: Text('Task · ${task.title}'),
          )),
      ...state.financeRepo.getAll().map((entry) => DropdownMenuItem(
            value: 'finance:${entry.id}',
            child: Text('Finance · ${entry.title}'),
          )),
    ];

    return AlertDialog(
      title: Text(_editing ? 'Edit Note' : 'Quick Capture'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: !_editing,
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
                initialValue: links.any((item) => item.value == _link) ? _link : '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Link to progress'),
                items: links,
                onChanged: (value) => setState(() => _link = value ?? ''),
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
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Choose files'),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                  if (result == null) return;
                  final selected = result.files.map((f) => f.path).whereType<String>();
                  final merged = {..._splitValues(_attachmentsController.text), ...selected};
                  setState(() => _attachmentsController.text = merged.join(', '));
                },
              )),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('No mood'),
                    selected: _moodIndex == -1,
                    onSelected: (_) => setState(() => _moodIndex = -1),
                  ),
                  ...List.generate(Mood.values.length, (index) => ChoiceChip(
                        avatar: Icon(Mood.values[index].icon, size: 16),
                        label: Text(Mood.values[index].label),
                        selected: _moodIndex == index,
                        onSelected: (selected) => setState(
                          () => _moodIndex = selected ? index : -1,
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(_editing ? 'Save Changes' : 'Save')),
      ],
    );
  }
}

void showAddNoteDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _NoteEditorDialog());
}

void showEditNoteDialog(BuildContext context, Note note) {
  showDialog(context: context, builder: (_) => _NoteEditorDialog(note: note));
}
