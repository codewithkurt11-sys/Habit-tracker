import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/task_category.dart';
import '../models/task.dart';

class TaskCategoriesRepository {
  Box<TaskCategoryModel> get _box => Hive.box<TaskCategoryModel>(HiveBoxes.taskCategories);
  final _uuid = const Uuid();

  List<TaskCategoryModel> getAll() {
    final values = _box.values.toList();
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  TaskCategoryModel? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return _box.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TaskCategoryModel> create({
    required String name,
    required Color color,
    required IconData icon,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Category name cannot be empty');
    if (getAll().any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('A category with this name already exists');
    }
    final category = TaskCategoryModel(
      id: _uuid.v4(),
      name: trimmed,
      colorValue: color.toARGB32(),
      iconCodePoint: icon.codePoint,
      iconFontFamily: icon.fontFamily,
      iconFontPackage: icon.fontPackage,
    );
    await _box.put(category.id, category);
    return category;
  }

  Future<void> update(TaskCategoryModel category, {String? name, Color? color, IconData? icon}) async {
    final nextName = (name ?? category.name).trim();
    if (nextName.isEmpty) throw ArgumentError('Category name cannot be empty');
    if (getAll().any((c) => c.id != category.id && c.name.toLowerCase() == nextName.toLowerCase())) {
      throw ArgumentError('A category with this name already exists');
    }
    final updated = category.copyWith(
      name: nextName,
      colorValue: color?.toARGB32(),
      iconCodePoint: icon?.codePoint,
      iconFontFamily: icon?.fontFamily,
      iconFontPackage: icon?.fontPackage,
    );
    await _box.put(updated.id, updated);
  }

  Future<void> delete(String id, {required Iterable<Task> tasks}) async {
    if (_box.get(id) == null) return;
    for (final task in tasks) {
      if (task.customCategoryId == id) {
        task.customCategoryId = null;
        task.category = TaskCategory.other;
        task.touch();
      }
    }
    await _box.delete(id);
  }
}
