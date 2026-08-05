import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../data/models/user_settings.dart';
import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/models/goal.dart';
import '../data/models/note.dart';
import '../data/models/finance_entry.dart';
import '../data/repositories/habits_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../data/repositories/goals_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/notification_service.dart';

/// Central app state for v2.0.0.
/// Manages all repositories and linked-entity logic.
class AppState extends ChangeNotifier {
  final habitsRepo = HabitsRepository();
  final tasksRepo = TasksRepository();
  final goalsRepo = GoalsRepository();
  final notesRepo = NotesRepository();
  final financeRepo = FinanceRepository();
  final settingsRepo = SettingsRepository();

  final notificationService = NotificationService();

  bool _busy = false;
  bool get busy => _busy;

  void initNotifications() {
    notificationService.refreshAll(tasks: tasksRepo.getAll(includeArchived: true));
  }

  Future<bool> requestNotificationPermission() =>
      notificationService.requestPermission();

  // ---------- theme ----------
  UserSettings get settings => settingsRepo.current;

  bool get isDark {
    switch (settings.themeMode) {
      case AppThemeMode.dark: return true;
      case AppThemeMode.light: return false;
      case AppThemeMode.system: return false;
    }
  }

  void refresh() => notifyListeners();

  // ---------- onboarding ----------
  bool get onboardingComplete => settings.onboardingComplete;

  Future<void> completeOnboarding(String name) async {
    await settingsRepo.setUserName(name);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await settingsRepo.setThemeMode(mode);
    notifyListeners();
  }

  // ---------- habits ----------
  List<Habit> get habits => habitsRepo.getAll();
  List<Habit> get habitsDueToday => habitsRepo.getDueToday();

  Future<void> addHabit({
    required String title,
    String description = '',
    String? linkedGoalId,
    required HabitFrequency frequency,
    List<int>? customDays,
    DateTime? reminderTime,
    int iconIndex = 0,
    int? colorValue,
    int targetStreak = 0,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await habitsRepo.create(
        title: title,
        description: description,
        linkedGoalId: linkedGoalId,
        frequency: frequency,
        customDays: customDays,
        reminderTime: reminderTime,
        iconIndex: iconIndex,
        colorValue: colorValue,
        targetStreak: targetStreak,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.toggleCompletion(h, date: date);
    notifyListeners();
  }

  Future<void> skipHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.skipDay(h, date: date);
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    await habitsRepo.delete(id);
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await habitsRepo.update(habit);
    notifyListeners();
  }

  // ---------- tasks ----------
  List<Task> get tasks => tasksRepo.getAll();
  List<Task> get activeTasks => tasksRepo.getActive();
  List<Task> get tasksDueToday => tasksRepo.getDueToday();
  Map<String, List<Task>> get tasksGrouped => tasksRepo.groupedByDueDate();

  Future<void> addTask({
    required String title,
    String description = '',
    int priorityIndex = 1,
    int categoryIndex = 1,
    DateTime? dueDate,
    DateTime? dueTime,
    List<String> subtaskTitles = const [],
    bool recurring = false,
    String recurrenceRule = '',
    String? linkedGoalId,
    String? linkedHabitId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final task = await tasksRepo.create(
        title: title,
        description: description,
        priority: TaskPriority.values[priorityIndex.clamp(0, 3)],
        category: TaskCategory.values[categoryIndex.clamp(0, 7)],
        dueDate: dueDate,
        dueTime: dueTime,
        subtaskTitles: subtaskTitles,
        recurring: recurring,
        recurrenceRule: recurrenceRule,
        linkedGoalId: linkedGoalId,
        linkedHabitId: linkedHabitId,
      );
      await notificationService.scheduleTask(task);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskDone(String id) async {
    final t = tasksRepo.getById(id);
    if (t == null) return;
    await tasksRepo.toggleDone(t);
    await notificationService.scheduleTask(t);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await tasksRepo.delete(id);
    await notificationService.cancelTask(id);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await tasksRepo.update(task);
    notifyListeners();
  }

  // ---------- goals ----------
  List<Goal> get goals => goalsRepo.getAll();
  List<Goal> get activeGoals => goalsRepo.getActive();
  List<Goal> get completedGoals => goalsRepo.getCompleted();

  Future<void> addGoal({
    required String title,
    String description = '',
    int categoryIndex = 6,
    DateTime? targetDate,
    int colorValue = 0xFF6B9080,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await goalsRepo.create(
        title: title,
        description: description,
        categoryIndex: categoryIndex,
        targetDate: targetDate,
        colorValue: colorValue,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    await goalsRepo.delete(id);
    notifyListeners();
  }

  Future<void> updateGoal(Goal goal) async {
    await goalsRepo.update(goal);
    notifyListeners();
  }

  Future<void> linkHabitToGoal(String goalId, String habitId) async {
    final g = goalsRepo.getById(goalId);
    if (g == null) return;
    await goalsRepo.linkHabit(g, habitId);
    // Also set habit.linkedGoalId
    final h = habitsRepo.getById(habitId);
    if (h != null) {
      h.linkedGoalId = goalId;
      await habitsRepo.update(h);
    }
    notifyListeners();
  }

  Future<void> unlinkHabitFromGoal(String goalId, String habitId) async {
    final g = goalsRepo.getById(goalId);
    if (g == null) return;
    await goalsRepo.unlinkHabit(g, habitId);
    final h = habitsRepo.getById(habitId);
    if (h != null && h.linkedGoalId == goalId) {
      h.linkedGoalId = null;
      await habitsRepo.update(h);
    }
    notifyListeners();
  }

  Future<void> linkTaskToGoal(String goalId, String taskId) async {
    final g = goalsRepo.getById(goalId);
    if (g == null) return;
    await goalsRepo.linkTask(g, taskId);
    final t = tasksRepo.getById(taskId);
    if (t != null) {
      t.linkedGoalId = goalId;
      await tasksRepo.update(t);
    }
    notifyListeners();
  }

  Future<void> unlinkTaskFromGoal(String goalId, String taskId) async {
    final g = goalsRepo.getById(goalId);
    if (g == null) return;
    await goalsRepo.unlinkTask(g, taskId);
    final t = tasksRepo.getById(taskId);
    if (t != null && t.linkedGoalId == goalId) {
      t.linkedGoalId = null;
      await tasksRepo.update(t);
    }
    notifyListeners();
  }

  Future<void> linkFinanceToGoal(String goalId, String financeId) async {
    final g = goalsRepo.getById(goalId);
    if (g == null) return;
    await goalsRepo.linkFinance(g, financeId);
    final f = financeRepo.getById(financeId);
    if (f != null) {
      f.linkedGoalId = goalId;
      await financeRepo.update(f);
    }
    notifyListeners();
  }

  /// Compute auto-calculated goal progress from linked items.
  double computeGoalProgress(Goal goal) {
    final habitRates = <double>[];
    for (final hid in goal.linkedHabitIds) {
      final h = habitsRepo.getById(hid);
      if (h != null) habitRates.add(h.completionRate(days: 30));
    }
    double taskFraction = 0;
    if (goal.linkedTaskIds.isNotEmpty) {
      final done = goal.linkedTaskIds.where((tid) {
        final t = tasksRepo.getById(tid);
        return t != null && t.status == TaskStatus.done;
      }).length;
      taskFraction = done / goal.linkedTaskIds.length;
    }
    double financeFraction = 0;
    if (goal.linkedFinanceId != null) {
      final f = financeRepo.getById(goal.linkedFinanceId!);
      if (f != null) financeFraction = f.progressFraction;
    }
    return goal.progressPercent(habitRates, taskFraction, financeFraction);
  }

  // ---------- notes ----------
  List<Note> get notes => notesRepo.getAll();
  List<String> get allTags => notesRepo.getAllTags();

  Future<void> addNote({
    required String title,
    required String body,
    List<String>? attachments,
    String linkedEntityType = 'none',
    String? linkedEntityId,
    List<String>? tags,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await notesRepo.create(
        title: title,
        body: body,
        attachments: attachments,
        linkedEntityType: linkedEntityType,
        linkedEntityId: linkedEntityId,
        tags: tags,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateNote(Note note) async {
    await notesRepo.update(note);
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await notesRepo.delete(id);
    notifyListeners();
  }

  // ---------- finance ----------
  List<FinanceEntry> get finances => financeRepo.getAll();
  List<FinanceEntry> get financesDueToday => financeRepo.getDueToday();

  Future<void> addFinance({
    required String title,
    String description = '',
    required double targetAmount,
    required int targetDays,
    String? linkedGoalId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await financeRepo.create(
        title: title,
        description: description,
        targetAmount: targetAmount,
        targetDays: targetDays,
        linkedGoalId: linkedGoalId,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> confirmFinanceToday(String id) async {
    final f = financeRepo.getById(id);
    if (f == null) return;
    await financeRepo.confirmToday(f);
    notifyListeners();
  }

  Future<void> unconfirmFinanceToday(String id) async {
    final f = financeRepo.getById(id);
    if (f == null) return;
    await financeRepo.unconfirmToday(f);
    notifyListeners();
  }

  Future<void> deleteFinance(String id) async {
    await financeRepo.delete(id);
    notifyListeners();
  }

  Future<void> updateFinance(FinanceEntry entry) async {
    await financeRepo.update(entry);
    notifyListeners();
  }

  /// Check for missed finance days on app open.
  List<(FinanceEntry, DateTime)> getMissedFinanceDays() {
    final missed = <(FinanceEntry, DateTime)>[];
    for (final f in finances) {
      final missedDays = f.getMissedDays();
      if (missedDays.isNotEmpty) {
        missed.add((f, missedDays.last));
      }
    }
    return missed;
  }

  // ---------- calendar (computed view) ----------
  /// Returns calendar events for a date range from habits, tasks, and goals.
  List<CalendarEvent> getCalendarEvents(DateTime start, DateTime end) {
    final events = <CalendarEvent>[];

    // Habit reminders
    for (final h in habits) {
      var cursor = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(endDay)) {
        if (h.isDueOn(cursor)) {
          events.add(CalendarEvent(
            date: cursor,
            title: h.title,
            type: 'habit',
            entityId: h.id,
            color: h.customColor ?? const Color(0xFF6B9080),
            completed: h.isCompletedOn(cursor),
          ));
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
    }

    // Task due dates
    for (final t in tasks) {
      if (t.dueDate != null && !t.archived) {
        final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (!d.isBefore(DateTime(start.year, start.month, start.day)) &&
            !d.isAfter(DateTime(end.year, end.month, end.day))) {
          events.add(CalendarEvent(
            date: d,
            title: t.title,
            type: 'task',
            entityId: t.id,
            color: t.priority.color,
            completed: t.status == TaskStatus.done,
          ));
        }
      }
    }

    // Goal target dates
    for (final g in goals) {
      if (g.targetDate != null && !g.archived) {
        final d = DateTime(g.targetDate!.year, g.targetDate!.month, g.targetDate!.day);
        if (!d.isBefore(DateTime(start.year, start.month, start.day)) &&
            !d.isAfter(DateTime(end.year, end.month, end.day))) {
          events.add(CalendarEvent(
            date: d,
            title: g.title,
            type: 'goal',
            entityId: g.id,
            color: g.color,
            completed: g.completed,
          ));
        }
      }
    }

    // Finance due days
    for (final f in finances) {
      var cursor = DateTime(f.createdAt.year, f.createdAt.month, f.createdAt.day);
      for (int i = 0; i < f.targetDays; i++) {
        final day = DateTime(cursor.year, cursor.month, cursor.day + i);
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day))) {
          events.add(CalendarEvent(
            date: day,
            title: f.title,
            type: 'finance',
            entityId: f.id,
            color: const Color(0xFF6B9080),
            completed: f.isConfirmedOn(day),
          ));
        }
      }
    }

    return events;
  }

  // ---------- stats ----------
  int get totalCurrentStreaks =>
      habits.where((h) => h.currentStreak() > 0).length;

  int get totalCompletions =>
      habits.fold(0, (sum, h) => sum + h.totalCompletions);

  int get goalsAchieved => completedGoals.length;

  int get totalHabits => habits.length;

  int get totalTasks => tasks.length;

  int get totalNotes => notes.length;

  int get totalFinances => finances.length;

  // ---------- export/import ----------
  Map<String, dynamic> exportAllData() {
    return {
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'userName': settings.userName,
        'themeMode': settings.themeMode.name,
        'onboardingComplete': settings.onboardingComplete,
        'notificationsEnabled': settings.notificationsEnabled,
        'currencySymbol': settings.currencySymbol,
        'memberSince': settings.memberSince?.toIso8601String(),
        'dashboardWidgetOrder': settings.dashboardWidgetOrder,
      },
      'habits': habits.map((h) => {
        'id': h.id,
        'title': h.title,
        'description': h.description,
        'linkedGoalId': h.linkedGoalId,
        'frequency': h.frequency.name,
        'customDays': h.customDays,
        'reminderTime': h.reminderTime?.toIso8601String(),
        'completionLog': h.completionLog.map((d) => d.toIso8601String()).toList(),
        'skipLog': h.skipLog.map((d) => d.toIso8601String()).toList(),
        'createdAt': h.createdAt.toIso8601String(),
        'iconIndex': h.iconIndex,
        'colorValue': h.colorValue,
        'targetStreak': h.targetStreak,
      }).toList(),
      'tasks': tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'priority': t.priority.name,
        'status': t.status.name,
        'category': t.category.name,
        'dueDate': t.dueDate?.toIso8601String(),
        'dueTime': t.dueTime?.toIso8601String(),
        'tags': t.tags,
        'subtaskTitles': t.subtaskTitles,
        'subtaskDone': t.subtaskDone,
        'recurring': t.recurring,
        'recurrenceRule': t.recurrenceRule,
        'linkedGoalId': t.linkedGoalId,
        'linkedHabitId': t.linkedHabitId,
        'createdAt': t.createdAt.toIso8601String(),
        'completedAt': t.completedAt?.toIso8601String(),
        'archived': t.archived,
      }).toList(),
      'goals': goals.map((g) => {
        'id': g.id,
        'title': g.title,
        'description': g.description,
        'categoryIndex': g.categoryIndex,
        'targetDate': g.targetDate?.toIso8601String(),
        'linkedHabitIds': g.linkedHabitIds,
        'linkedTaskIds': g.linkedTaskIds,
        'linkedFinanceId': g.linkedFinanceId,
        'colorValue': g.colorValue,
        'completed': g.completed,
        'archived': g.archived,
        'createdAt': g.createdAt.toIso8601String(),
      }).toList(),
      'notes': notes.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'attachments': n.attachments,
        'linkedEntityType': n.linkedEntityType,
        'linkedEntityId': n.linkedEntityId,
        'tags': n.tags,
        'createdAt': n.createdAt.toIso8601String(),
        'updatedAt': n.updatedAt.toIso8601String(),
      }).toList(),
      'finances': finances.map((f) => {
        'id': f.id,
        'title': f.title,
        'description': f.description,
        'targetAmount': f.targetAmount,
        'targetDays': f.targetDays,
        'linkedGoalId': f.linkedGoalId,
        'contributionLog': f.contributionLog.map((c) => {
          'date': c.date.toIso8601String(),
          'amount': c.amount,
          'confirmed': c.confirmed,
        }).toList(),
        'createdAt': f.createdAt.toIso8601String(),
      }).toList(),
    };
  }

  /// Validates import data structure. Returns null if valid, error message if not.
  String? validateImportData(Map<String, dynamic> data) {
    if (!data.containsKey('version')) return 'Invalid file: missing version';
    if (!data.containsKey('habits')) return 'Invalid file: missing habits data';
    if (!data.containsKey('tasks')) return 'Invalid file: missing tasks data';
    if (!data.containsKey('goals')) return 'Invalid file: missing goals data';
    if (!data.containsKey('notes')) return 'Invalid file: missing notes data';
    if (!data.containsKey('finances')) return 'Invalid file: missing finances data';
    return null;
  }

  /// Import preview summary.
  Map<String, int> getImportSummary(Map<String, dynamic> data) {
    return {
      'habits': (data['habits'] as List?)?.length ?? 0,
      'tasks': (data['tasks'] as List?)?.length ?? 0,
      'goals': (data['goals'] as List?)?.length ?? 0,
      'notes': (data['notes'] as List?)?.length ?? 0,
      'finances': (data['finances'] as List?)?.length ?? 0,
    };
  }
}

/// A computed calendar event.
class CalendarEvent {
  final DateTime date;
  final String title;
  final String type; // 'habit', 'task', 'goal', 'finance'
  final String entityId;
  final Color color;
  final bool completed;

  CalendarEvent({
    required this.date,
    required this.title,
    required this.type,
    required this.entityId,
    required this.color,
    required this.completed,
  });
}
