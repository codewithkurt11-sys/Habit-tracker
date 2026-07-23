import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_colors.dart';

/// High-level classification of a file used to pick icons and accent colors.
enum FileKind {
  folder,
  image,
  video,
  audio,
  document,
  archive,
  apk,
  code,
  other
}

/// Utility helpers for the file manager: sizing, naming, kind detection.
class FileUtils {
  FileUtils._();

  static const Set<String> _image = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'svg',
    'ico',
    'tiff',
  };
  static const Set<String> _video = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v',
  };
  static const Set<String> _audio = {
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'm4a',
    'wma',
    'opus',
  };
  static const Set<String> _doc = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'odt',
    'csv',
    'epub',
    'md',
  };
  static const Set<String> _archive = {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'iso',
  };
  static const Set<String> _code = {
    'dart',
    'java',
    'kt',
    'js',
    'ts',
    'py',
    'c',
    'cpp',
    'h',
    'html',
    'css',
    'json',
    'xml',
    'yaml',
    'yml',
    'sh',
    'gradle',
  };

  static String extension(String path) {
    final ext = p.extension(path);
    if (ext.isEmpty) return '';
    return ext.substring(1).toLowerCase();
  }

  static FileKind kindOf(FileSystemEntity entity) {
    if (entity is Directory) return FileKind.folder;
    final ext = extension(entity.path);
    if (ext == 'apk') return FileKind.apk;
    if (_image.contains(ext)) return FileKind.image;
    if (_video.contains(ext)) return FileKind.video;
    if (_audio.contains(ext)) return FileKind.audio;
    if (_doc.contains(ext)) return FileKind.document;
    if (_archive.contains(ext)) return FileKind.archive;
    if (_code.contains(ext)) return FileKind.code;
    return FileKind.other;
  }

  static IconData iconFor(FileKind kind) {
    switch (kind) {
      case FileKind.folder:
        return Icons.folder_rounded;
      case FileKind.image:
        return Icons.image_rounded;
      case FileKind.video:
        return Icons.movie_rounded;
      case FileKind.audio:
        return Icons.music_note_rounded;
      case FileKind.document:
        return Icons.description_rounded;
      case FileKind.archive:
        return Icons.folder_zip_rounded;
      case FileKind.apk:
        return Icons.android_rounded;
      case FileKind.code:
        return Icons.code_rounded;
      case FileKind.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color colorFor(FileKind kind) {
    switch (kind) {
      case FileKind.folder:
        return AppColors.fileFolder;
      case FileKind.image:
        return AppColors.fileImage;
      case FileKind.video:
        return AppColors.fileVideo;
      case FileKind.audio:
        return AppColors.fileAudio;
      case FileKind.document:
        return AppColors.fileDoc;
      case FileKind.archive:
        return AppColors.fileArchive;
      case FileKind.apk:
        return AppColors.fileApk;
      case FileKind.code:
        return AppColors.fileCode;
      case FileKind.other:
        return AppColors.fileOther;
    }
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes / 1024;
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || size == size.roundToDouble() ? 0 : 1)} ${units[unit]}';
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0 && now.day == date.day) {
      return 'Today ${_two(date.hour)}:${_two(date.minute)}';
    }
    if (diff.inDays <= 1) {
      return 'Yesterday ${_two(date.hour)}:${_two(date.minute)}';
    }
    return '${date.year}-${_two(date.month)}-${_two(date.day)} '
        '${_two(date.hour)}:${_two(date.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// Sort options for a directory listing.
enum FileSortBy { name, size, date, type }
