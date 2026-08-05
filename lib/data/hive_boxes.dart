import 'package:hive_flutter/hive_flutter.dart';
import 'models/note.dart';
import 'models/habit.dart';
import 'models/user_settings.dart';
import 'models/task.dart';
import 'models/finance_entry.dart';
import 'models/goal.dart';

/// Box name constants. Centralized so repositories never hardcode string literals.
class HiveBoxes {
  HiveBoxes._();

  static const String notes = 'notes_box';
  static const String habits = 'habits_box';
  static const String settings = 'settings_box';
  static const String tasks = 'tasks_box';
  static const String finance = 'finance_box';
  static const String financeBudget = 'finance_budget_box';
  static const String goals = 'goals_box';

  static const String settingsKey = 'user_settings';
}

/// Registers all Hive adapters and opens all boxes. Call once at app startup.
class HiveInitializer {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(HabitAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(FinanceEntryAdapter());
    Hive.registerAdapter(FinanceBudgetAdapter());
    Hive.registerAdapter(GoalAdapter());

    await Future.wait([
      Hive.openBox<Note>(HiveBoxes.notes),
      Hive.openBox<Habit>(HiveBoxes.habits),
      Hive.openBox<UserSettings>(HiveBoxes.settings),
      Hive.openBox<Task>(HiveBoxes.tasks),
      Hive.openBox<FinanceEntry>(HiveBoxes.finance),
      Hive.openBox<FinanceBudget>(HiveBoxes.financeBudget),
      Hive.openBox<Goal>(HiveBoxes.goals),
    ]);

    _initialized = true;
  }
}
