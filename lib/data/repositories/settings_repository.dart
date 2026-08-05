import 'package:hive/hive.dart';
import '../hive_boxes.dart';
import '../models/user_settings.dart';

class SettingsRepository {
  Box<UserSettings> get _box => Hive.box<UserSettings>(HiveBoxes.settings);

  UserSettings get current {
    final existing = _box.get(HiveBoxes.settingsKey);
    if (existing != null) return existing;
    final fresh = UserSettings();
    _box.put(HiveBoxes.settingsKey, fresh);
    return fresh;
  }

  Future<void> setUserName(String name) async {
    final s = current;
    s.userName = name.trim();
    s.onboardingComplete = true;
    await s.save();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final s = current;
    s.themeMode = mode;
    await s.save();
  }

  Future<void> save(UserSettings updated) async {
    final s = current;
    s.userName = updated.userName;
    s.themeMode = updated.themeMode;
    s.onboardingComplete = updated.onboardingComplete;
    await s.save();
  }
}
