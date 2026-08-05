import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../data/file_manager/file_manager_service.dart';
import '../../data/file_manager/file_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/shared_widgets.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _service = FileManagerService();
  bool _permissionGranted = false;
  bool _fullStorageAccess = false;
  bool _loading = true;
  String? _error;
  List<StorageRoot> _roots = [];
  String? _currentPath;
  List<FileSystemEntity> _entries = [];
  final List<String> _breadcrumb = [];
  FileSortBy _sortBy = FileSortBy.name;
  bool _ascending = true;
  bool _showHidden = false;
  bool _gridView = false;
  final _searchController = TextEditingController();

  List<FileSystemEntity> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries
        .where((entry) => p.basename(entry.path).toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initPermission() async {
    try {
      final granted = await _service.ensurePermission();
      if (!mounted) return;
      setState(() {
        _permissionGranted = granted;
        _fullStorageAccess = _service.hasBroadStorageAccess;
        _loading = false;
      });
      if (granted) {
        await _loadRoots();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRoots() async {
    try {
      final roots = await _service.storageRoots();
      if (!mounted) return;
      setState(() {
        _roots = roots;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.listDirectory(
        path,
        sortBy: _sortBy,
        ascending: _ascending,
        showHidden: _showHidden,
      );
      if (!mounted) return;
      setState(() {
        _currentPath = path;
        _entries = entries;
        _loading = false;
        _updateBreadcrumb(path);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot access: $e';
        _loading = false;
      });
    }
  }

  void _updateBreadcrumb(String path) {
    _breadcrumb.clear();
    final parts = p.split(path);
    String built = '';
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      built = built.isEmpty ? '/${parts[i]}' : p.join(built, parts[i]);
      _breadcrumb.add(parts[i]);
    }
  }

  void _goBack() {
    if (_currentPath == null) return;
    final parent = p.dirname(_currentPath!);
    if (parent == _currentPath) {
      // Reached root — go back to storage roots view
      setState(() {
        _currentPath = null;
        _entries = [];
        _breadcrumb.clear();
      });
    } else {
      _navigateTo(parent);
    }
  }

  Future<void> _refresh() async {
    if (_currentPath != null) {
      await _navigateTo(_currentPath!);
    } else {
      await _loadRoots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permissionGranted) {
      return _PermissionView(
        onRetry: _initPermission,
        onOpenSettings: _service.openPermissionSettings,
      );
    }

    if (_currentPath == null) {
      // Storage roots view
      return Column(
        children: [
          _buildHeader('File Manager', 'Browse and manage device files'),
          if (!_fullStorageAccess) _buildLimitedAccessBanner(),
          Expanded(
            child: _roots.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_off_outlined,
                    title: 'No storage found',
                    subtitle: 'No accessible storage locations detected',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _roots.length,
                    itemBuilder: (_, i) => _StorageRootTile(
                      root: _roots[i],
                      onTap: () => _navigateTo(_roots[i].path),
                    ),
                  ),
          ),
        ],
      );
    }

    // Directory listing view
    return Column(
      children: [
        _buildBreadcrumbBar(),
        if (!_fullStorageAccess) _buildLimitedAccessBanner(),
        _buildSearchBar(),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            child:
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        Expanded(
          child: _visibleEntries.isEmpty
              ? EmptyState(
                  icon: _searchController.text.isEmpty
                      ? Icons.folder_open
                      : Icons.search_off,
                  title: _searchController.text.isEmpty
                      ? 'Empty folder'
                      : 'No matching files',
                  subtitle: _searchController.text.isEmpty
                      ? 'This folder has no files'
                      : 'Try a different search term',
                )
              : _gridView
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _visibleEntries.length,
                      itemBuilder: (_, i) {
                        final entity = _visibleEntries[i];
                        return _FileEntityGridTile(
                          entity: entity,
                          onTap: () => _openEntity(entity),
                          onLongPress: () => _showEntityOptions(entity),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: _visibleEntries.length,
                      itemBuilder: (_, i) {
                        final entity = _visibleEntries[i];
                        return _FileEntityTile(
                          entity: entity,
                          onTap: () => _openEntity(entity),
                          onLongPress: () => _showEntityOptions(entity),
                        );
                      },
                    ),
        ),
        // Bottom action bar
        _buildActionBar(),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: _goBack,
            tooltip: 'Back',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(AppSpacing.sm),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _breadcrumb.length; i++) ...[
                    if (i > 0)
                      Icon(Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                    GestureDetector(
                      onTap: () {
                        // Navigate to this breadcrumb level
                        String path = '/';
                        for (int j = 0; j <= i; j++) {
                          path = p.join(path, _breadcrumb[j]);
                        }
                        _navigateTo(path);
                      },
                      child: Text(
                        _breadcrumb[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: i == _breadcrumb.length - 1
                              ? theme.colorScheme.primary
                              : null,
                          fontWeight: i == _breadcrumb.length - 1
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _gridView = !_gridView),
            tooltip: _gridView ? 'List view' : 'Grid view',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(AppSpacing.sm),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _refresh,
            tooltip: 'Refresh',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(AppSpacing.sm),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitedAccessBanner() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Limited access. Allow all files access to browse shared storage.',
            ),
          ),
          TextButton(
            onPressed: () async {
              await _service.openPermissionSettings();
              await _initPermission();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      await _navigateTo(entity.path);
      return;
    }
    final result = await OpenFilex.open(entity.path);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message.isEmpty
            ? 'No app can open this file type.'
            : result.message),
        action: SnackBarAction(
          label: 'Options',
          onPressed: () => _showEntityOptions(entity),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search this folder',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final theme = Theme.of(context);
    final hasClipboard = _service.clipboard != null;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed:
                _currentPath == null ? null : () => _showCreateFolderDialog(),
            tooltip: 'New Folder',
          ),
          IconButton(
            icon: Icon(Icons.content_paste,
                color: hasClipboard ? theme.colorScheme.primary : null),
            onPressed: hasClipboard && _currentPath != null
                ? () => _pasteItems()
                : null,
            tooltip: 'Paste',
          ),
          IconButton(
            icon: Icon(
              _showHidden ? Icons.visibility : Icons.visibility_off_outlined,
            ),
            onPressed: () {
              setState(() => _showHidden = !_showHidden);
              if (_currentPath != null) _navigateTo(_currentPath!);
            },
            tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
          ),
          IconButton(
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() => _ascending = !_ascending);
              if (_currentPath != null) _navigateTo(_currentPath!);
            },
            tooltip: 'Sort order',
          ),
          PopupMenuButton<FileSortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (v) {
              setState(() => _sortBy = v);
              if (_currentPath != null) _navigateTo(_currentPath!);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: FileSortBy.name, child: Text('Name')),
              PopupMenuItem(value: FileSortBy.size, child: Text('Size')),
              PopupMenuItem(value: FileSortBy.date, child: Text('Date')),
              PopupMenuItem(value: FileSortBy.type, child: Text('Type')),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. My Documents',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || _currentPath == null) return;
              Navigator.pop(context);
              try {
                await _service.createFolder(_currentPath!, name);
                await _refresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEntityOptions(FileSystemEntity entity) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showDetails(entity);
              },
            ),
            if (entity is File)
              ListTile(
                leading: Icon(Icons.share_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareFile(entity);
                },
              ),
            ListTile(
              leading: Icon(Icons.copy, color: theme.colorScheme.primary),
              title: const Text('Copy'),
              onTap: () {
                _service.clipboard =
                    FileClipboard(paths: [entity.path], isCut: false);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.content_cut, color: theme.colorScheme.primary),
              title: const Text('Cut'),
              onTap: () {
                _service.clipboard =
                    FileClipboard(paths: [entity.path], isCut: true);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cut to clipboard'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_rename_outline,
                  color: theme.colorScheme.primary),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(entity);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(entity);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: p.basename(file.path),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to share file: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showDetails(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    try {
      final stat = await entity.stat();
      var size = stat.size;
      var itemSummary = entity is Directory ? 'Folder' : 'File';
      if (entity is Directory) {
        final stats = await _service.folderStats(entity.path);
        size = stats.size;
        itemSummary = '${stats.files} files, ${stats.folders} folders';
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(name),
          content: SelectableText(
            'Type: $itemSummary\n'
            'Size: ${FileUtils.formatSize(size)}\n'
            'Modified: ${FileUtils.formatDate(stat.modified)}\n'
            'Path: ${entity.path}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to read details: $error')),
      );
    }
  }

  void _showRenameDialog(FileSystemEntity entity) {
    final controller = TextEditingController(text: p.basename(entity.path));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await _service.rename(entity, name);
                await _refresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Rename failed: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error),
                  );
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FileSystemEntity entity) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${p.basename(entity.path)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.delete([entity]);
                await _refresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Delete failed: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteItems() async {
    if (_currentPath == null) return;
    try {
      final result = await _service.paste(_currentPath!);
      await _refresh();
      if (!mounted) return;
      final message = result.hasErrors
          ? '${result.completed} completed. ${result.errors.join('; ')}'
          : result.skipped > 0
              ? '${result.completed} completed, ${result.skipped} skipped'
              : '${result.completed} item(s) pasted';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              result.hasErrors ? Theme.of(context).colorScheme.error : null,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Paste failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  const _PermissionView({
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.lg),
            const Text('Storage Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This app needs storage permission to browse files on your device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Grant Permission'),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageRootTile extends StatelessWidget {
  final StorageRoot root;
  final VoidCallback onTap;

  const _StorageRootTile({required this.root, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.fileFolder.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: AppColors.fileFolder,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(root.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(root.path,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileEntityGridTile extends StatelessWidget {
  final FileSystemEntity entity;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileEntityGridTile({
    required this.entity,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = FileUtils.kindOf(entity);
    final color = FileUtils.colorFor(kind);
    final name = p.basename(entity.path);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Icon(FileUtils.iconFor(kind), color: color, size: 28),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileEntityTile extends StatelessWidget {
  final FileSystemEntity entity;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileEntityTile({
    required this.entity,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = FileUtils.kindOf(entity);
    final name = p.basename(entity.path);
    final isDir = entity is Directory;

    String subtitle = '';
    try {
      if (isDir) {
        subtitle = 'Folder';
      } else if (entity is File) {
        final file = entity as File;
        final size = file.lengthSync();
        subtitle = FileUtils.formatSize(size);
      }
    } catch (_) {
      subtitle = isDir ? 'Folder' : 'File';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FileUtils.colorFor(kind).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Icon(FileUtils.iconFor(kind),
                      color: FileUtils.colorFor(kind), size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: theme.textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (isDir)
                  Icon(Icons.chevron_right,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
