import 'package:hive/hive.dart';

enum AppThemeMode { system, light, dark }

/// Singleton-style settings record (a single instance stored under a
/// fixed key in the settings box).
class UserSettings extends HiveObject {
  String? userName;
  AppThemeMode themeMode;
  bool onboardingComplete;

  UserSettings({
    this.userName,
    this.themeMode = AppThemeMode.system,
    this.onboardingComplete = false,
  });
}

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 4;

  @override
  UserSettings read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      userName: fields[0] as String?,
      themeMode: AppThemeMode.values[fields[1] as int],
      onboardingComplete: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.userName)
      ..writeByte(1)
      ..write(obj.themeMode.index)
      ..writeByte(2)
      ..write(obj.onboardingComplete);
  }
}
