import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'file_utils.dart';

/// A storage location shown on the file manager home ("shortcuts").
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

/// Represents a pending copy/move operation (a clipboard).
class FileClipboard {
  final List<String> paths;
  final bool isCut; // true = move, false = copy
  const FileClipboard({required this.paths, required this.isCut});
}

/// Handles all filesystem interaction for the file manager. Kept free of
/// Flutter widget dependencies so the UI stays thin.
class FileManagerService {
  FileClipboard? clipboard;

  /// Requests the appropriate storage permission for the running platform.
  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    // Prefer broad access (Android 11+ MANAGE_EXTERNAL_STORAGE); fall back to
    // legacy storage permission on older devices.
    if (await Permission.manageExternalStorage.isGranted) return true;
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (await Permission.storage.isGranted) return true;
    status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
  }

  /// Discovers the available storage roots (internal + SD cards + app dirs).
  Future<List<StorageRoot>> storageRoots() async {
    final roots = <StorageRoot>[];
    if (Platform.isAndroid) {
      const primary = '/storage/emulated/0';
      if (await Directory(primary).exists()) {
        roots.add(const StorageRoot(
          label: 'Internal Storage',
          path: primary,
          isPrimary: true,
        ));
      }
      // Detect removable storage (SD cards) under /storage.
      try {
        final storageDir = Directory('/storage');
        if (await storageDir.exists()) {
          await for (final e in storageDir.list()) {
            final name = p.basename(e.path);
            if (e is Directory &&
                name != 'emulated' &&
                name != 'self' &&
                name.contains('-')) {
              roots.add(StorageRoot(label: 'SD Card ($name)', path: e.path));
            }
          }
        }
      } catch (_) {
        // Ignore unreadable /storage.
      }
      try {
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          roots.add(StorageRoot(label: 'App Storage', path: appDir.path));
        }
      } catch (_) {}
    } else {
      final home =
          Platform.environment['HOME'] ?? Directory.current.path;
      roots.add(StorageRoot(label: 'Home', path: home, isPrimary: true));
      try {
        final docs = await getApplicationDocumentsDirectory();
        roots.add(StorageRoot(label: 'Documents', path: docs.path));
      } catch (_) {}
    }
    return roots;
  }

  /// Lists the contents of [path], applying sorting and hidden-file filtering.
  Future<List<FileSystemEntity>> listDirectory(
    String path, {
    FileSortBy sortBy = FileSortBy.name,
    bool ascending = true,
    bool showHidden = false,
  }) async {
    final dir = Directory(path);
    final entities = <FileSystemEntity>[];
    await for (final e in dir.list(followLinks: false)) {
      final name = p.basename(e.path);
      if (!showHidden && name.startsWith('.')) continue;
      entities.add(e);
    }
    _sort(entities, sortBy, ascending);
    return entities;
  }

  void _sort(List<FileSystemEntity> items, FileSortBy sortBy, bool asc) {
    int folderFirst(FileSystemEntity a, FileSystemEntity b) {
      final af = a is Directory ? 0 : 1;
      final bf = b is Directory ? 0 : 1;
      return af.compareTo(bf);
    }

    items.sort((a, b) {
      final ff = folderFirst(a, b);
      if (ff != 0) return ff;
      int cmp;
      switch (sortBy) {
        case FileSortBy.name:
          cmp = p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
          break;
        case FileSortBy.size:
          cmp = _statSize(a).compareTo(_statSize(b));
          break;
        case FileSortBy.date:
          cmp = _statDate(a).compareTo(_statDate(b));
          break;
        case FileSortBy.type:
          cmp = FileUtils.extension(a.path)
              .compareTo(FileUtils.extension(b.path));
          break;
      }
      return asc ? cmp : -cmp;
    });
  }

  int _statSize(FileSystemEntity e) {
    try {
      return e is File ? e.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  DateTime _statDate(FileSystemEntity e) {
    try {
      return e.statSync().modified;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Recursively counts files/folders and total size within [path].
  Future<({int files, int folders, int size})> folderStats(
      String path) async {
    int files = 0, folders = 0, size = 0;
    try {
      final dir = Directory(path);
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          files++;
          try {
            size += await e.length();
          } catch (_) {}
        } else if (e is Directory) {
          folders++;
        }
      }
    } catch (_) {}
    return (files: files, folders: folders, size: size);
  }

  // ---- Operations ----

  Future<void> createFolder(String parent, String name) async {
    final dir = Directory(p.join(parent, name));
    if (await dir.exists()) {
      throw const FileSystemException('A folder with that name already exists');
    }
    await dir.create();
  }

  Future<void> rename(FileSystemEntity entity, String newName) async {
    final newPath = p.join(p.dirname(entity.path), newName);
    if (await File(newPath).exists() || await Directory(newPath).exists()) {
      throw const FileSystemException('An item with that name already exists');
    }
    await entity.rename(newPath);
  }

  Future<void> delete(List<FileSystemEntity> entities) async {
    for (final e in entities) {
      try {
        if (e is Directory) {
          await e.delete(recursive: true);
        } else {
          await e.delete();
        }
      } catch (err) {
        debugPrint('Delete failed for ${e.path}: $err');
        rethrow;
      }
    }
  }

  /// Pastes clipboard contents into [destination]. Returns number of items.
  Future<int> paste(String destination) async {
    final cb = clipboard;
    if (cb == null) return 0;
    int count = 0;
    for (final src in cb.paths) {
      final name = p.basename(src);
      var target = p.join(destination, name);
      target = await _uniquePath(target);
      if (await Directory(src).exists()) {
        await _copyDirectory(Directory(src), Directory(target));
        if (cb.isCut) await Directory(src).delete(recursive: true);
      } else if (await File(src).exists()) {
        await File(src).copy(target);
        if (cb.isCut) await File(src).delete();
      }
      count++;
    }
    clipboard = null;
    return count;
  }

  Future<String> _uniquePath(String path) async {
    if (!await File(path).exists() && !await Directory(path).exists()) {
      return path;
    }
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    int i = 1;
    while (true) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!await File(candidate).exists() &&
          !await Directory(candidate).exists()) {
        return candidate;
      }
      i++;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
