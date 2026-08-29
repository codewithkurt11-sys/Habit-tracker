import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/task_category.dart';
import '../../logic/app_state.dart';

const _categoryIcons = <IconData>[
  Icons.category_outlined, Icons.work_outline, Icons.person_outline, Icons.favorite_outline,
  Icons.fitness_center, Icons.school_outlined, Icons.home_outlined, Icons.shopping_bag_outlined,
  Icons.build_outlined, Icons.book_outlined, Icons.music_note_outlined, Icons.flag_outlined,
  Icons.terminal_outlined, Icons.sports_basketball_outlined, Icons.travel_explore_outlined,
];

List<Color> get _categoryColors => AppColors.habitColorPalette;

Future<TaskCategoryModel?> showTaskCategoryEditor(
  BuildContext context, {
  TaskCategoryModel? category,
}) {
  return showDialog<TaskCategoryModel>(
    context: context,
    builder: (_) => _TaskCategoryEditor(category: category),
  );
}

class _TaskCategoryEditor extends StatefulWidget {
  final TaskCategoryModel? category;
  const _TaskCategoryEditor({this.category});
  @override
  State<_TaskCategoryEditor> createState() => _TaskCategoryEditorState();
}

class _TaskCategoryEditorState extends State<_TaskCategoryEditor> {
  late final TextEditingController _name;
  late IconData _icon;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _icon = widget.category?.icon ?? _categoryIcons.first;
    _color = widget.category?.color ?? _categoryColors.first;
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, TaskCategoryModel(
      id: widget.category?.id ?? '',
      name: name,
      colorValue: _color.toARGB32(),
      iconCodePoint: _icon.codePoint,
      iconFontFamily: _icon.fontFamily,
      iconFontPackage: _icon.fontPackage,
      createdAt: widget.category?.createdAt,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.category == null ? 'New category' : 'Edit category'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.label_outline))),
              const SizedBox(height: AppSpacing.md),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: _categoryIcons.map((icon) => ChoiceChip(
                    label: Icon(icon, size: 18), selected: icon.codePoint == _icon.codePoint,
                    onSelected: (_) => setState(() => _icon = icon),
                  )).toList()),
              const SizedBox(height: AppSpacing.md),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: _categoryColors.map((color) => GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                        border: _color.toARGB32() == color.toARGB32() ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null)),
                  )).toList()),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _save, child: Text(widget.category == null ? 'Create' : 'Save'))],
      );
}

Future<void> showTaskCategoryManager(BuildContext context) async {
  await showDialog<void>(context: context, builder: (_) => const _TaskCategoryManager());
}

class _TaskCategoryManager extends StatelessWidget {
  const _TaskCategoryManager();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.taskCategoriesRepo.getAll();
    return AlertDialog(
      title: const Text('Task categories'),
      content: SizedBox(
        width: 480,
        child: categories.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No custom categories yet.'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final category = categories[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: category.color.withValues(alpha: 0.15), child: Icon(category.icon, color: category.color)),
                    title: Text(category.name),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () async {
                        final updated = await showTaskCategoryEditor(context, category: category);
                        if (updated == null) return;
                        try {
                          await state.updateTaskCategory(category, name: updated.name, color: updated.color, icon: updated.icon);
                        } on ArgumentError catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message?.toString() ?? 'Unable to update category')));
                        }
                      }),
                      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete category?'),
                            content: Text('Tasks using “${category.name}” will be moved to Other.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) await state.deleteTaskCategory(category.id);
                      }),
                    ]),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        FilledButton.icon(
          onPressed: () async {
            final created = await showTaskCategoryEditor(context);
            if (created == null) return;
            try {
              await state.addTaskCategory(name: created.name, color: created.color, icon: created.icon);
            } on ArgumentError catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message?.toString() ?? 'Unable to create category')));
            }
          },
          icon: const Icon(Icons.add), label: const Text('New category'),
        ),
      ],
    );
  }
}
