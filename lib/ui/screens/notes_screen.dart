import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/note.dart';
import '../widgets/shared_widgets.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _searchQuery = '';
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allTags = state.allTags;
    List<Note> notes;
    if (_searchQuery.isNotEmpty) {
      notes = state.notesRepo.search(_searchQuery);
    } else if (_selectedTag != null) {
      notes = state.notesRepo.getForTag(_selectedTag!);
    } else {
      notes = state.notes;
    }

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showNoteEditor(context),
          child: const Icon(Icons.add),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ScreenTitleBar(title: 'Notes', subtitle: '${state.notes.length} total'),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  // Tag filters
                  if (allTags.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: _selectedTag == null,
                              onSelected: (_) => setState(() => _selectedTag = null),
                            ),
                          ),
                          ...allTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: FilterChip(
                              label: Text(tag),
                              selected: _selectedTag == tag,
                              onSelected: (_) => setState(() => _selectedTag = tag),
                            ),
                          )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (notes.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'No notes',
                  subtitle: 'Create your first note',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _NoteCard(note: notes[index]),
                  childCount: notes.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showNoteEditor(BuildContext context, {Note? note}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NoteEditorSheet(note: note),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: SoftCard(
        onTap: () => _showEditor(context, note),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(note.title, style: theme.textTheme.titleSmall,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (note.linkedEntityType != 'none')
                  PillChip(label: note.linkedEntityType, color: theme.colorScheme.primary, icon: Icons.link),
              ],
            ),
            const SizedBox(height: 4),
            Text(note.body, style: theme.textTheme.bodyMedium,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: note.tags.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditor(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NoteEditorSheet(note: note),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  final Note? note;
  const _NoteEditorSheet({this.note});

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _tagCtrl;
  List<String> _tags = [];
  String _linkType = 'none';
  String? _linkId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.body ?? '');
    _tagCtrl = TextEditingController();
    _tags = List.from(widget.note?.tags ?? []);
    _linkType = widget.note?.linkedEntityType ?? 'none';
    _linkId = widget.note?.linkedEntityId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.note != null ? 'Edit Note' : 'New Note', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(labelText: 'Body'),
              maxLines: 6,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(labelText: 'Add tag', isDense: true),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setState(() => _tags.add(v.trim()));
                        _tagCtrl.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_tagCtrl.text.trim().isNotEmpty) {
                      setState(() => _tags.add(_tagCtrl.text.trim()));
                      _tagCtrl.clear();
                    }
                  },
                ),
              ],
            ),
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: _tags.map((t) => Chip(
                  label: Text(t),
                  onDeleted: () => setState(() => _tags.remove(t)),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            const SizedBox(height: AppSpacing.md),
            // Link to entity
            Text('Link to', style: theme.textTheme.titleSmall),
            DropdownButton<String>(
              value: _linkType,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'habit', child: Text('Habit')),
                DropdownMenuItem(value: 'goal', child: Text('Goal')),
                DropdownMenuItem(value: 'task', child: Text('Task')),
                DropdownMenuItem(value: 'finance', child: Text('Finance')),
              ],
              onChanged: (v) => setState(() {
                _linkType = v ?? 'none';
                _linkId = null;
              }),
            ),
            if (_linkType != 'none') ...[
              const SizedBox(height: AppSpacing.xs),
              _EntityDropdown(
                type: _linkType,
                selectedId: _linkId,
                onChanged: (id) => setState(() => _linkId = id),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  final body = _bodyCtrl.text.trim();
                  if (title.isEmpty && body.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  if (widget.note != null) {
                    final n = widget.note!;
                    n.title = title.isEmpty ? 'Untitled' : title;
                    n.body = body;
                    n.tags = _tags;
                    n.linkedEntityType = _linkType;
                    n.linkedEntityId = _linkId;
                    state.updateNote(n);
                  } else {
                    state.addNote(
                      title: title.isEmpty ? 'Untitled' : title,
                      body: body,
                      tags: _tags,
                      linkedEntityType: _linkType,
                      linkedEntityId: _linkId,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(widget.note != null ? 'Save' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntityDropdown extends StatelessWidget {
  final String type;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _EntityDropdown({required this.type, this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    List<DropdownMenuItem<String>> items = [];
    switch (type) {
      case 'habit':
        items = state.habits.map((h) => DropdownMenuItem(value: h.id, child: Text(h.title))).toList();
        break;
      case 'goal':
        items = state.goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))).toList();
        break;
      case 'task':
        items = state.tasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))).toList();
        break;
      case 'finance':
        items = state.finances.map((f) => DropdownMenuItem(value: f.id, child: Text(f.title))).toList();
        break;
    }
    if (items.isEmpty) {
      return Text('No ${type}s available', style: Theme.of(context).textTheme.bodySmall);
    }
    return DropdownButton<String>(
      value: selectedId,
      hint: Text('Select $type'),
      items: items,
      onChanged: onChanged,
    );
  }
}
