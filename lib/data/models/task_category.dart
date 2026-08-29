import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class TaskCategoryModel {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskCategoryModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);

  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily,
        fontPackage: iconFontPackage,
      );

  TaskCategoryModel copyWith({
    String? name,
    int? colorValue,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
  }) {
    return TaskCategoryModel(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      createdAt: createdAt,
    );
  }
}

class TaskCategoryAdapter extends TypeAdapter<TaskCategoryModel> {
  @override
  final int typeId = 13;

  @override
  TaskCategoryModel read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return TaskCategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      iconCodePoint: fields[3] as int,
      iconFontFamily: fields[4] as String? ?? 'MaterialIcons',
      iconFontPackage: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskCategoryModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.iconFontFamily)
      ..writeByte(5)
      ..write(obj.iconFontPackage)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }
}
