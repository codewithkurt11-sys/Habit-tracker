import 'package:hive/hive.dart';

enum AppThemeMode { system, light, dark }

/// v2.0.0 UserSettings: added [dashboardWidgetOrder], [notificationsEnabled],
/// [memberSince], [currencySymbol].
class UserSettings extends HiveObject {
  String? userName;
  AppThemeMode themeMode;
  bool onboardingComplete;
  bool notificationsEnabled;
  String currencySymbol;
  DateTime? memberSince;
  List<String> dashboardWidgetOrder;

  UserSettings({
    this.userName,
    this.themeMode = AppThemeMode.system,
    this.onboardingComplete = false,
    this.notificationsEnabled = true,
    this.currencySymbol = '\u20B1',
    this.memberSince,
    List<String>? dashboardWidgetOrder,
  }) : dashboardWidgetOrder = dashboardWidgetOrder ??
            ['habits', 'tasks', 'goals', 'finance', 'notes'];
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
      themeMode: AppThemeMode.values[fields[1] as int? ?? 0],
      onboardingComplete: fields[2] as bool? ?? false,
      notificationsEnabled: fields[3] as bool? ?? true,
      currencySymbol: fields[4] as String? ?? '\u20B1',
      memberSince: fields[5] as DateTime?,
      dashboardWidgetOrder: (fields[6] as List?)?.cast<String>() ??
          ['habits', 'tasks', 'goals', 'finance', 'notes'],
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userName)
      ..writeByte(1)
      ..write(obj.themeMode.index)
      ..writeByte(2)
      ..write(obj.onboardingComplete)
      ..writeByte(3)
      ..write(obj.notificationsEnabled)
      ..writeByte(4)
      ..write(obj.currencySymbol)
      ..writeByte(5)
      ..write(obj.memberSince)
      ..writeByte(6)
      ..write(obj.dashboardWidgetOrder);
  }
}
