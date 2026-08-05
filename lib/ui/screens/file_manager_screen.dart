import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_spacing.dart';
import '../../data/file_manager/file_manager_service.dart';
import '../../data/file_manager/file_utils.dart';
import '../widgets/shared_widgets.dart';

/// v2.0.0 File Manager — Fixed scoped storage bug.
///
/// Bug fix: Previously listed /storage/emulated/ (parent, inaccessible).
/// Now resolves root via getExternalStorageDirectory() or SAF.
/// Raw exception text replaced with friendly "Folder unavailable" + retry.
/// Audited for Android 11+ Scoped Storage compliance — uses SAF for
/// arbitrary folder access instead of requesting MANAGE_EXTERNAL_STORAGE.
class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _service = FileManagerService();
  List<FileSystemEntity> _items = [];
  String? _currentPath;
  bool _loading = false;
  String? _error;
  FileSortBy _sortBy = FileSortBy.name;
  bool _ascending = true;
  bool _showHidden = false;
  Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _initRoots();
  }

  Future<void> _initRoots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasPermission = await _service.hasPermission();
      if (!hasPermission) {
        final granted = await _service.ensurePermission();
        if (!granted) {
          setState(() {
            _error = 'Folder unavailable. Tap retry to grant access.';
            _loading = false;
          });
          return;
        }
      }
      final roots = await _service.storageRoots();
      if (roots.isEmpty) {
        setState(() {
          _error = 'Folder unavailable. No accessible storage found.';
          _loading = false;
        });
        return;
      }
      // Default to primary root — always /storage/emulated/0, never the parent
      final primary = roots.firstWhere((r) => r.isPrimary, orElse: () => roots.first);
      await _navigateTo(primary.path);
    } catch (e) {
      // Replace raw exception text with friendly message
      setState(() {
        _error = 'Folder unavailable. Tap retry to try again.';
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('FileManager init error: $e');
      }
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPaths.clear();
    });
    try {
      final items = await _service.listDirectory(
        path,
        sortBy: _sortBy,
        ascending: _ascending,
        showHidden: _showHidden,
      );
      setState(() {
        _currentPath = path;
        _items = items;
        _loading = false;
      });
    } on FileSystemException catch (e) {
      // Friendly error instead of raw exception text
      setState(() {
        _error = 'Folder unavailable. ${e.message.contains('permission') ? "Permission denied." : "Tap retry to try again."}';
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('FileManager navigate error: $e');
      }
    } catch (e) {
      setState(() {
        _error = 'Folder unavailable. Tap retry to try again.';
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('FileManager navigate error: $e');
      }
    }
  }

  Future<void> _retry() async {
    if (_currentPath != null) {
      await _navigateTo(_currentPath!);
    } else {
      await _initRoots();
    }
  }

  void _toggleSort(FileSortBy sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _ascending = !_ascending;
      } else {
        _sortBy = sortBy;
        _ascending = true;
      }
    });
    if (_currentPath != null) _navigateTo(_currentPath!);
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Toolbar
          if (_currentPath != null) _buildToolbar(theme),
          // Breadcrumb
          if (_currentPath != null) _buildBreadcrumb(theme),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView(theme)
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.folder_off_outlined,
                            title: 'Empty folder',
                            subtitle: 'This folder has no files',
                            actionLabel: 'Go back',
                            onAction: () => _goUp(),
                          )
                        : _buildFileList(theme),
          ),
          // Selection bar
          if (_selectedPaths.isNotEmpty) _buildSelectionBar(theme),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goUp,
          ),
          const Spacer(),
          PopupMenuButton<FileSortBy>(
            icon: const Icon(Icons.sort),
            onSelected: _toggleSort,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: FileSortBy.name, child: Text('Sort by name')),
              const PopupMenuItem(value: FileSortBy.size, child: Text('Sort by size')),
              const PopupMenuItem(value: FileSortBy.date, child: Text('Sort by date')),
              const PopupMenuItem(value: FileSortBy.type, child: Text('Sort by type')),
            ],
          ),
          IconButton(
            icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => _showHidden = !_showHidden);
              if (_currentPath != null) _navigateTo(_currentPath!);
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'new_folder':
                  _showNewFolderDialog();
                  break;
                case 'paste':
                  if (_currentPath != null) {
                    final result = await _service.paste(_currentPath!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                          'Pasted ${result.completed} item(s)' +
                          (result.hasErrors ? ', ${result.errors.length} error(s)' : ''))),
                      );
                      _navigateTo(_currentPath!);
                    }
                  }
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'new_folder', child: Text('New folder')),
              if (_service.clipboard != null)
                const PopupMenuItem(value: 'paste', child: Text('Paste')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(ThemeData theme) {
    final parts = _currentPath!.split('/').where((s) => s.isNotEmpty).toList();
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
            GestureDetector(
              onTap: () {
                final path = '/${parts.take(i + 1).join('/')}';
                _navigateTo(path);
              },
              child: Center(child: Text(parts[i], style: theme.textTheme.bodySmall)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.lg),
            Text('Folder unavailable', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(_error ?? '', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final entity = _items[index];
        final name = p.basename(entity.path);
        final kind = FileUtils.kindOf(entity);
        final isSelected = _selectedPaths.contains(entity.path);
        final isDir = entity is Directory;

        return ListTile(
          leading: Icon(FileUtils.iconFor(kind), color: FileUtils.colorFor(kind)),
          title: Text(name),
          subtitle: isDir
              ? const Text('Folder')
              : Text(FileUtils.formatSize(_fileSize(entity))),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.green)
              : PopupMenuButton(
                  onSelected: (value) => _handleItemAction(value, entity),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                    const PopupMenuItem(value: 'cut', child: Text('Cut')),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
          selected: isSelected,
          onLongPress: () => _toggleSelection(entity.path),
          onTap: () {
            if (_selectedPaths.isNotEmpty) {
              _toggleSelection(entity.path);
            } else if (isDir) {
              _navigateTo(entity.path);
            }
          },
        );
      },
    );
  }

  Widget _buildSelectionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text('${_selectedPaths.length} selected', style: theme.textTheme.bodyMedium),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedPaths.clear()),
            child: const Text('Cancel'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final entities = _items.where((e) => _selectedPaths.contains(e.path)).toList();
              await _service.delete(entities);
              setState(() => _selectedPaths.clear());
              if (_currentPath != null) _navigateTo(_currentPath!);
            },
          ),
        ],
      ),
    );
  }

  void _goUp() {
    if (_currentPath == null) return;
    final parent = p.dirname(_currentPath!);
    if (parent == _currentPath) return;
    _navigateTo(parent);
  }

  int _fileSize(FileSystemEntity entity) {
    try {
      return entity is File ? entity.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  void _handleItemAction(String action, FileSystemEntity entity) {
    switch (action) {
      case 'copy':
        _service.clipboard = FileClipboard(paths: [entity.path], isCut: false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
        break;
      case 'cut':
        _service.clipboard = FileClipboard(paths: [entity.path], isCut: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cut to clipboard')),
        );
        break;
      case 'rename':
        _showRenameDialog(entity);
        break;
      case 'delete':
        _showDeleteDialog(entity);
        break;
    }
  }

  void _showNewFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Folder name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (_currentPath != null && ctrl.text.trim().isNotEmpty) {
                try {
                  await _service.createFolder(_currentPath!, ctrl.text.trim());
                  if (mounted) {
                    Navigator.pop(ctx);
                    _navigateTo(_currentPath!);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString().split(':').last.trim()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileSystemEntity entity) {
    final ctrl = TextEditingController(text: p.basename(entity.path));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                try {
                  await _service.rename(entity, ctrl.text.trim());
                  if (mounted) {
                    Navigator.pop(ctx);
                    if (_currentPath != null) _navigateTo(_currentPath!);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString().split(':').last.trim()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(FileSystemEntity entity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${p.basename(entity.path)}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              await _service.delete([entity]);
              if (mounted) {
                Navigator.pop(ctx);
                if (_currentPath != null) _navigateTo(_currentPath!);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
