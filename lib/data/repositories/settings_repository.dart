import 'package:hive/hive.dart';
import '../hive_boxes.dart';
import '../models/user_settings.dart';

class SettingsRepository {
  Box<UserSettings> get _box => Hive.box<UserSettings>(HiveBoxes.settings);

  UserSettings get current {
    final existing = _box.get(HiveBoxes.settingsKey);
    if (existing != null) return existing;
    final fresh = UserSettings(memberSince: DateTime.now());
    _box.put(HiveBoxes.settingsKey, fresh);
    return fresh;
  }

  Future<void> setUserName(String name) async {
    final s = current;
    s.userName = name.trim();
    s.onboardingComplete = true;
    s.memberSince ??= DateTime.now();
    await s.save();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final s = current;
    s.themeMode = mode;
    await s.save();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final s = current;
    s.notificationsEnabled = enabled;
    await s.save();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final s = current;
    s.currencySymbol = symbol;
    await s.save();
  }

  Future<void> setDashboardWidgetOrder(List<String> order) async {
    final s = current;
    s.dashboardWidgetOrder = order;
    await s.save();
  }

  Future<void> save(UserSettings updated) async {
    final s = current;
    s.userName = updated.userName;
    s.themeMode = updated.themeMode;
    s.onboardingComplete = updated.onboardingComplete;
    s.notificationsEnabled = updated.notificationsEnabled;
    s.currencySymbol = updated.currencySymbol;
    s.dashboardWidgetOrder = updated.dashboardWidgetOrder;
    s.memberSince ??= updated.memberSince;
    await s.save();
  }
}
