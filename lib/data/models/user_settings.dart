import 'package:hive/hive.dart';

enum AppThemeMode { system, light, dark }

/// Keys for dashboard section visibility toggles.
class DashboardConfig {
  bool showDailyProgress;
  bool showQuickStats;
  bool showQuickActions;
  bool showTodayHabits;
  bool showTasks;
  bool showSchedule;
  bool showGoalProgress;
  bool showSavingsTargets;
  bool showRecentNotes;
  bool showInsight;
  bool showDailyQuote;

  DashboardConfig({
    this.showDailyProgress = true,
    this.showQuickStats = true,
    this.showQuickActions = true,
    this.showTodayHabits = true,
    this.showTasks = true,
    this.showSchedule = true,
    this.showGoalProgress = true,
    this.showSavingsTargets = true,
    this.showRecentNotes = true,
    this.showInsight = true,
    this.showDailyQuote = true,
  });

  Map<String, dynamic> toMap() => {
        'showDailyProgress': showDailyProgress,
        'showQuickStats': showQuickStats,
        'showQuickActions': showQuickActions,
        'showTodayHabits': showTodayHabits,
        'showTasks': showTasks,
        'showSchedule': showSchedule,
        'showGoalProgress': showGoalProgress,
        'showSavingsTargets': showSavingsTargets,
        'showRecentNotes': showRecentNotes,
        'showInsight': showInsight,
        'showDailyQuote': showDailyQuote,
      };

  factory DashboardConfig.fromMap(Map<dynamic, dynamic> map) =>
      DashboardConfig(
        showDailyProgress: map['showDailyProgress'] as bool? ?? true,
        showQuickStats: map['showQuickStats'] as bool? ?? true,
        showQuickActions: map['showQuickActions'] as bool? ?? true,
        showTodayHabits: map['showTodayHabits'] as bool? ?? true,
        showTasks: map['showTasks'] as bool? ?? true,
        showSchedule: map['showSchedule'] as bool? ?? true,
        showGoalProgress: map['showGoalProgress'] as bool? ?? true,
        showSavingsTargets: map['showSavingsTargets'] as bool? ?? true,
        showRecentNotes: map['showRecentNotes'] as bool? ?? true,
        showInsight: map['showInsight'] as bool? ?? true,
        showDailyQuote: map['showDailyQuote'] as bool? ?? true,
      );
}

/// Singleton-style settings record (a single instance stored under a
/// fixed key in the settings box).
class UserSettings extends HiveObject {
  String? userName;
  AppThemeMode themeMode;
  bool onboardingComplete;
  DashboardConfig dashboardConfig;

  UserSettings({
    this.userName,
    this.themeMode = AppThemeMode.system,
    this.onboardingComplete = false,
    DashboardConfig? dashboardConfig,
  }) : dashboardConfig = dashboardConfig ?? DashboardConfig();
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
    final dashMap = fields[3] as Map?;
    return UserSettings(
      userName: fields[0] as String?,
      themeMode: AppThemeMode.values[fields[1] as int],
      onboardingComplete: fields[2] as bool,
      dashboardConfig: dashMap != null
          ? DashboardConfig.fromMap(dashMap)
          : DashboardConfig(),
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.userName)
      ..writeByte(1)
      ..write(obj.themeMode.index)
      ..writeByte(2)
      ..write(obj.onboardingComplete)
      ..writeByte(3)
      ..write(obj.dashboardConfig.toMap());
  }
}
