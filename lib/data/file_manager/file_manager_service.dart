import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'file_utils.dart';

/// A storage location shown on the file manager home.
class StorageRoot {
  final String label;
  final String path;
  final bool isPrimary;

  const StorageRoot({
    required this.label,
    required this.path,
    this.isPrimary = false,
  });
}

/// Represents a pending copy or move operation.
class FileClipboard {
  final List<String> paths;
  final bool isCut;

  const FileClipboard({required this.paths, required this.isCut});
}

/// The real outcome of a paste operation.
class PasteResult {
  final int completed;
  final int skipped;
  final List<String> errors;

  const PasteResult({
    required this.completed,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Handles filesystem interaction for the file manager.
class FileManagerService {
  FileClipboard? clipboard;
  bool _hasBroadStorageAccess = !Platform.isAndroid;

  bool get hasBroadStorageAccess => _hasBroadStorageAccess;

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      _hasBroadStorageAccess = true;
      return true;
    }

    // Android 11+ file managers need "All files access" to browse shared
    // storage. On older Android versions, the legacy storage permission is
    // used instead. If both are unavailable, app-specific storage still works.
    final allFiles = await Permission.manageExternalStorage.request();
    if (allFiles.isGranted) {
      _hasBroadStorageAccess = true;
      return true;
    }

    final legacyStorage = await Permission.storage.request();
    _hasBroadStorageAccess = legacyStorage.isGranted;
    return _hasBroadStorageAccess ||
        await getExternalStorageDirectory() != null;
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    _hasBroadStorageAccess = await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
    return _hasBroadStorageAccess ||
        await getExternalStorageDirectory() != null;
  }

  Future<bool> openPermissionSettings() async {
    if (Platform.isAndroid) {
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) {
        _hasBroadStorageAccess = true;
        return true;
      }
    }
    return openAppSettings();
  }

  Future<List<StorageRoot>> storageRoots() async {
    final roots = <StorageRoot>[];
    if (Platform.isAndroid) {
      final canBrowseSharedStorage =
          await Permission.manageExternalStorage.isGranted ||
              await Permission.storage.isGranted;
      _hasBroadStorageAccess = canBrowseSharedStorage;
      if (canBrowseSharedStorage) {
        const primary = '/storage/emulated/0';
        if (await Directory(primary).exists()) {
          roots.add(const StorageRoot(
            label: 'Internal Storage',
            path: primary,
            isPrimary: true,
          ));
          for (final folder in const [
            'Download',
            'Documents',
            'DCIM',
            'Pictures',
            'Music',
            'Movies',
          ]) {
            final path = p.join(primary, folder);
            if (await Directory(path).exists()) {
              roots.add(StorageRoot(label: folder, path: path));
            }
          }
        }

        try {
          final storageDir = Directory('/storage');
          if (await storageDir.exists()) {
            await for (final entity in storageDir.list(followLinks: false)) {
              final name = p.basename(entity.path);
              if (entity is Directory &&
                  name != 'emulated' &&
                  name != 'self' &&
                  name.contains('-')) {
                roots.add(StorageRoot(
                  label: 'SD Card ($name)',
                  path: entity.path,
                ));
              }
            }
          }
        } on FileSystemException {
          // Some manufacturers block listing /storage.
        }
      }

      try {
        final appDir = await getExternalStorageDirectory();
        if (appDir != null &&
            !roots.any((root) => p.equals(root.path, appDir.path))) {
          roots.add(StorageRoot(label: 'App Storage', path: appDir.path));
        }
      } on FileSystemException {
        // The device may not expose an app-specific external directory.
      }
    } else {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      roots.add(StorageRoot(label: 'Home', path: home, isPrimary: true));
      try {
        final docs = await getApplicationDocumentsDirectory();
        if (!roots.any((root) => p.equals(root.path, docs.path))) {
          roots.add(StorageRoot(label: 'Documents', path: docs.path));
        }
      } on FileSystemException {
        // The home location is still available.
      }
    }
    return roots;
  }

  Future<List<FileSystemEntity>> listDirectory(
    String path, {
    FileSortBy sortBy = FileSortBy.name,
    bool ascending = true,
    bool showHidden = false,
  }) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw FileSystemException('Folder does not exist', path);
    }

    final entities = <FileSystemEntity>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!showHidden && name.startsWith('.')) continue;
      entities.add(entity);
    }
    _sort(entities, sortBy, ascending);
    return entities;
  }

  void _sort(List<FileSystemEntity> items, FileSortBy sortBy, bool ascending) {
    items.sort((a, b) {
      final folderOrder = (a is Directory ? 0 : 1).compareTo(
        b is Directory ? 0 : 1,
      );
      if (folderOrder != 0) return folderOrder;

      int comparison;
      switch (sortBy) {
        case FileSortBy.name:
          comparison = p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        case FileSortBy.size:
          comparison = _statSize(a).compareTo(_statSize(b));
        case FileSortBy.date:
          comparison = _statDate(a).compareTo(_statDate(b));
        case FileSortBy.type:
          comparison = FileUtils.extension(
            a.path,
          ).compareTo(FileUtils.extension(b.path));
      }
      return ascending ? comparison : -comparison;
    });
  }

  int _statSize(FileSystemEntity entity) {
    try {
      return entity is File ? entity.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  DateTime _statDate(FileSystemEntity entity) {
    try {
      return entity.statSync().modified;
    } on FileSystemException {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<({int files, int folders, int size})> folderStats(String path) async {
    var files = 0;
    var folders = 0;
    var size = 0;
    final directory = Directory(path);
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        files++;
        try {
          size += await entity.length();
        } on FileSystemException {
          // Keep counting readable files.
        }
      } else if (entity is Directory) {
        folders++;
      }
    }
    return (files: files, folders: folders, size: size);
  }

  Future<void> createFolder(String parent, String name) async {
    _validateName(name);
    final directory = Directory(p.join(parent, name));
    if (await _pathExists(directory.path)) {
      throw FileSystemException('An item with that name already exists', name);
    }
    await directory.create();
  }

  Future<void> rename(FileSystemEntity entity, String newName) async {
    _validateName(newName);
    final currentName = p.basename(entity.path);
    if (currentName == newName) return;

    final newPath = p.join(p.dirname(entity.path), newName);
    if (await _pathExists(newPath)) {
      throw FileSystemException(
          'An item with that name already exists', newPath);
    }
    await entity.rename(newPath);
  }

  void _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('\u0000')) {
      throw const FileSystemException(
          'Enter a valid name without path separators');
    }
  }

  Future<void> delete(List<FileSystemEntity> entities) async {
    for (final entity in entities) {
      if (entity is Directory) {
        await entity.delete(recursive: true);
      } else {
        await entity.delete();
      }
    }
  }

  Future<PasteResult> paste(String destination) async {
    final currentClipboard = clipboard;
    if (currentClipboard == null) {
      return const PasteResult(completed: 0, skipped: 0, errors: []);
    }

    final destinationDirectory = Directory(destination);
    if (!await destinationDirectory.exists()) {
      throw FileSystemException('Destination does not exist', destination);
    }

    final destinationPath = p.normalize(p.absolute(destination));
    var completed = 0;
    var skipped = 0;
    final errors = <String>[];
    final failedPaths = <String>[];

    for (final source in currentClipboard.paths.toSet()) {
      final sourcePath = p.normalize(p.absolute(source));
      final sourceName = p.basename(sourcePath);
      try {
        final sourceType = await FileSystemEntity.type(
          sourcePath,
          followLinks: false,
        );
        if (sourceType == FileSystemEntityType.notFound) {
          skipped++;
          errors.add('$sourceName no longer exists');
          continue;
        }

        if (currentClipboard.isCut &&
            p.equals(p.dirname(sourcePath), destinationPath)) {
          skipped++;
          continue;
        }

        if (sourceType == FileSystemEntityType.directory &&
            _isSameOrChild(destinationPath, sourcePath)) {
          throw const FileSystemException(
            'A folder cannot be pasted inside itself',
          );
        }

        final target = await _uniquePath(p.join(destinationPath, sourceName));
        if (currentClipboard.isCut) {
          try {
            if (sourceType == FileSystemEntityType.directory) {
              await Directory(sourcePath).rename(target);
            } else {
              await File(sourcePath).rename(target);
            }
          } on FileSystemException {
            await _copyEntity(sourcePath, target, sourceType);
            try {
              await _deletePath(sourcePath, sourceType);
            } on FileSystemException {
              await _deletePath(target, sourceType);
              rethrow;
            }
          }
        } else {
          await _copyEntity(sourcePath, target, sourceType);
        }
        completed++;
      } on FileSystemException catch (error) {
        failedPaths.add(source);
        errors.add('$sourceName: ${error.message}');
      }
    }

    clipboard = failedPaths.isEmpty
        ? null
        : FileClipboard(paths: failedPaths, isCut: currentClipboard.isCut);
    return PasteResult(completed: completed, skipped: skipped, errors: errors);
  }

  bool _isSameOrChild(String candidate, String parent) {
    return p.equals(candidate, parent) || p.isWithin(parent, candidate);
  }

  Future<void> _copyEntity(
    String source,
    String target,
    FileSystemEntityType type,
  ) async {
    if (type == FileSystemEntityType.directory) {
      try {
        await _copyDirectory(Directory(source), Directory(target));
      } catch (_) {
        final partial = Directory(target);
        if (await partial.exists()) await partial.delete(recursive: true);
        rethrow;
      }
    } else if (type == FileSystemEntityType.file) {
      await File(source).copy(target);
    } else {
      throw FileSystemException('Unsupported file type', source);
    }
  }

  Future<void> _deletePath(String path, FileSystemEntityType type) async {
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<bool> _pathExists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  Future<String> _uniquePath(String path) async {
    if (!await _pathExists(path)) return path;

    final directory = p.dirname(path);
    final extension = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    var index = 1;
    while (true) {
      final candidate = p.join(directory, '$base ($index)$extension');
      if (!await _pathExists(candidate)) return candidate;
      index++;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
