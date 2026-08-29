import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_app/data/hive_boxes.dart';
import 'package:flutter_app/data/models/task.dart';
import 'package:flutter_app/data/models/task_category.dart';
import 'package:flutter_app/data/models/recurrence_rule.dart';
import 'package:flutter_app/data/repositories/task_categories_repository.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourself_categories_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(TaskCategoryAdapter().typeId)) {
      Hive.registerAdapter(TaskCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(TaskAdapter().typeId)) {
      Hive.registerAdapter(TaskAdapter());
    }
    if (!Hive.isAdapterRegistered(RecurrenceRuleAdapter().typeId)) {
      Hive.registerAdapter(RecurrenceRuleAdapter());
    }
    await Hive.openBox<TaskCategoryModel>(HiveBoxes.taskCategories);
    await Hive.openBox<Task>(HiveBoxes.tasks);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('custom category persists and prevents duplicate names', () async {
    final repo = TaskCategoriesRepository();
    final created = await repo.create(
      name: 'School',
      color: const Color(0xFF6B9080),
      icon: Icons.school_outlined,
    );

    expect(repo.getById(created.id)?.name, 'School');
    await expectLater(
      repo.create(
        name: 'school',
        color: const Color(0xFF6B9080),
        icon: Icons.school_outlined,
      ),
      throwsArgumentError,
    );
  });

  test('deleting a category resets affected tasks to Other', () async {
    final repo = TaskCategoriesRepository();
    final category = await repo.create(
      name: 'Projects',
      color: const Color(0xFFE8946F),
      icon: Icons.flag_outlined,
    );
    final task = Task(
      id: 't1',
      title: 'Project task',
      customCategoryId: category.id,
    );
    await Hive.box<Task>(HiveBoxes.tasks).put(task.id, task);

    await repo.delete(category.id, tasks: [task]);
    expect(task.customCategoryId, isNull);
    expect(task.category, TaskCategory.other);
  });
}
