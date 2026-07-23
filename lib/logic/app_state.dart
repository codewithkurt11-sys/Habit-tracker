import 'package:flutter/foundation.dart';
import '../data/models/user_settings.dart';
import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/repositories/habits_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../data/repositories/goals_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/journal_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/focus_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../data/repositories/quotes_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/friends_repository.dart';

/// Central app state exposed via [Provider].
///
/// Holds all repository singletons and a [notifyListeners] hook so the
/// entire widget tree can rebuild after any CRUD mutation.
class AppState extends ChangeNotifier {
  final habitsRepo = HabitsRepository();
  final tasksRepo = TasksRepository();
  final goalsRepo = GoalsRepository();
  final notesRepo = NotesRepository();
  final journalRepo = JournalRepository();
  final financeRepo = FinanceRepository();
  final focusRepo = FocusRepository();
  final scheduleRepo = ScheduleRepository();
  final quotesRepo = QuotesRepository();
  final settingsRepo = SettingsRepository();

  // Cloud sync layer (optional). Always present but no-op when signed out.
  final authService = AuthService();
  final syncService = SyncService();
  final friendsRepo = FriendsRepository();

  bool _busy = false;
  bool get busy => _busy;

  // ---------- cloud sync wiring ----------
  /// Whether the cloud layer is available (signed in + online).
  bool get cloudAvailable => authService.isSignedIn && syncService.isOnline;

  /// Listen to SyncService notifyListeners (offline->online / sign-in) and
  /// trigger reconciliation. Call once after construction (in main.dart).
  void initSync() {
    syncService.addListener(_onSyncServiceChanged);
    // Also trigger an initial reconcile if already signed in + online.
    if (syncService.shouldReconcile) _reconcileWithCloud();
  }

  void _onSyncServiceChanged() {
    if (syncService.shouldReconcile) {
      _reconcileWithCloud();
    }
  }

  /// Full reconciliation: push all local records, pull cloud-only / newer.
  Future<void> _reconcileWithCloud() async {
    await syncService.reconcile(
      localHabits: habitsRepo.getAll(),
      localTasks: tasksRepo.getAll(includeArchived: true),
      localGoals: goalsRepo.getAll(includeArchived: true),
      localSchedule: scheduleRepo.getAll(),
      onHabitFromCloud: (h) => habitsRepo.update(h),
      onTaskFromCloud: (t) => tasksRepo.update(t),
      onGoalFromCloud: (g) => goalsRepo.update(g),
      onScheduleFromCloud: (s) => scheduleRepo.update(s),
    );
    notifyListeners();
  }

  /// Fire-and-forget push of a single record after a local mutation.
  void _pushRecord(String type, String id, Map<String, dynamic> data) {
    // no-op when signed out / offline
    syncService.pushRecord(type, id, data);
  }

  void _pushDelete(String type, String id) {
    syncService.pushDelete(type, id);
  }

  // ---------- theme ----------
  UserSettings get settings => settingsRepo.current;

  bool get isDark {
    switch (settings.themeMode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        return false; // web preview defaults to light
    }
  }

  // ---------- generic refresh ----------
  void refresh() => notifyListeners();

  // ---------- onboarding ----------
  bool get onboardingComplete => settings.onboardingComplete;

  Future<void> completeOnboarding(String name) async {
    await settingsRepo.setUserName(name);
    notifyListeners();
  }

  // ---------- theme switching ----------
  Future<void> setThemeMode(AppThemeMode mode) async {
    await settingsRepo.setThemeMode(mode);
    notifyListeners();
  }

  // ---------- habits ----------
  Future<void> addHabit({
    required String name,
    required int categoryIndex,
    required int frequencyIndex,
    List<int>? customDays,
    int iconIndex = 15,
    int? colorValue,
    int targetStreak = 0,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final habit = await habitsRepo.create(
        name: name,
        category: _habitCategory(categoryIndex),
        frequency: _habitFrequency(frequencyIndex),
        customDays: customDays,
        iconIndex: iconIndex,
        colorValue: colorValue,
        targetStreak: targetStreak,
      );
      _pushRecord('habits', habit.id, syncService.habitToMap(habit));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.toggleCompletion(h, date: date);
    _pushRecord('habits', h.id, syncService.habitToMap(h));
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    await habitsRepo.delete(id);
    _pushDelete('habits', id);
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await habitsRepo.update(habit);
    _pushRecord('habits', habit.id, syncService.habitToMap(habit));
    notifyListeners();
  }

  // ---------- tasks ----------
  Future<void> addTask({
    required String title,
    String description = '',
    int priorityIndex = 1,
    int categoryIndex = 1,
    DateTime? dueDate,
    List<String> subtaskTitles = const [],
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final task = await tasksRepo.create(
        title: title,
        description: description,
        priority: _taskPriority(priorityIndex),
        category: _taskCategory(categoryIndex),
        dueDate: dueDate,
        subtaskTitles: subtaskTitles,
      );
      _pushRecord('tasks', task.id, syncService.taskToMap(task));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskDone(String id) async {
    final t = tasksRepo.getById(id);
    if (t == null) return;
    if (t.status.name == 'done') {
      t.status = _taskStatus(0); // back to todo
      t.completedAt = null;
    } else {
      t.status = _taskStatus(2); // done
      t.completedAt = DateTime.now();
    }
    t.touch();
    await tasksRepo.update(t);
    _pushRecord('tasks', t.id, syncService.taskToMap(t));
    notifyListeners();
  }

  Future<void> toggleSubtask(String taskId, int index) async {
    final t = tasksRepo.getById(taskId);
    if (t == null) return;
    await tasksRepo.toggleSubtask(t, index);
    _pushRecord('tasks', t.id, syncService.taskToMap(t));
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await tasksRepo.delete(id);
    _pushDelete('tasks', id);
    notifyListeners();
  }

  // ---------- goals ----------
  Future<void> addGoal({
    required String title,
    String description = '',
    int categoryIndex = 6,
    DateTime? deadline,
    double targetValue = 100,
    int colorValue = 0xFF6B9080,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final goal = await goalsRepo.create(
        title: title,
        description: description,
        categoryIndex: categoryIndex,
        deadline: deadline,
        targetValue: targetValue,
        colorValue: colorValue,
      );
      _pushRecord('goals', goal.id, syncService.goalToMap(goal));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateGoalProgress(String id, double value) async {
    final g = goalsRepo
        .getAll(includeArchived: true)
        .where((g) => g.id == id)
        .firstOrNull;
    if (g == null) return;
    await goalsRepo.updateProgress(g, value);
    _pushRecord('goals', g.id, syncService.goalToMap(g));
    notifyListeners();
  }

  Future<void> toggleGoalMilestone(String id, int index) async {
    final g = goalsRepo
        .getAll(includeArchived: true)
        .where((g) => g.id == id)
        .firstOrNull;
    if (g == null) return;
    await goalsRepo.toggleMilestone(g, index);
    _pushRecord('goals', g.id, syncService.goalToMap(g));
    notifyListeners();
  }

  Future<void> addGoalMilestone(String id, String title,
      {DateTime? dueDate}) async {
    final g = goalsRepo
        .getAll(includeArchived: true)
        .where((g) => g.id == id)
        .firstOrNull;
    if (g == null) return;
    await goalsRepo.addMilestone(g, title, dueDate: dueDate);
    _pushRecord('goals', g.id, syncService.goalToMap(g));
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await goalsRepo.delete(id);
    _pushDelete('goals', id);
    notifyListeners();
  }

  // ---------- journal ----------
  Future<void> addJournal({
    required String title,
    required String body,
    int moodIndex = -1,
    required DateTime date,
    List<String> tags = const [],
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await journalRepo.create(
        title: title,
        body: body,
        moodIndex: moodIndex,
        date: date,
        tags: tags,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteJournal(String id) async {
    await journalRepo.delete(id);
    notifyListeners();
  }

  Future<void> toggleJournalFavorite(String id) async {
    final e = journalRepo.getAll().where((j) => j.id == id).firstOrNull;
    if (e == null) return;
    await journalRepo.toggleFavorite(e);
    notifyListeners();
  }

  // ---------- notes ----------
  Future<void> addNote({
    required String title,
    required String body,
    int moodIndex = -1,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await notesRepo.create(
        title: title,
        body: body,
        moodIndex: moodIndex,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    await notesRepo.delete(id);
    notifyListeners();
  }

  // ---------- finance ----------
  Future<void> addFinance({
    required String title,
    required double amount,
    required int typeIndex,
    required int categoryIndex,
    required DateTime date,
    String note = '',
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await financeRepo.create(
        title: title,
        amount: amount,
        typeIndex: typeIndex,
        categoryIndex: categoryIndex,
        date: date,
        note: note,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteFinance(String id) async {
    await financeRepo.delete(id);
    notifyListeners();
  }

  // ---------- focus ----------
  Future<void> saveFocusSession({
    required int typeIndex,
    required int durationSeconds,
    required int completedSeconds,
    String? taskTitle,
  }) async {
    final session = await focusRepo.startSession(
      typeIndex: typeIndex,
      durationSeconds: durationSeconds,
      taskTitle: taskTitle,
    );
    await focusRepo.completeSession(session, completedSeconds);
    notifyListeners();
  }

  Future<void> deleteFocus(String id) async {
    await focusRepo.delete(id);
    notifyListeners();
  }

  // ---------- schedule ----------
  Future<void> addSchedule({
    required String title,
    required DateTime dateTime,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final item = await scheduleRepo.create(title: title, dateTime: dateTime);
      _pushRecord('schedule', item.id, syncService.scheduleToMap(item));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleSchedule(String id) async {
    final s = scheduleRepo.getAll().where((s) => s.id == id).firstOrNull;
    if (s == null) return;
    await scheduleRepo.toggle(s);
    final updated = scheduleRepo.getAll().where((x) => x.id == id).firstOrNull;
    if (updated != null)
      _pushRecord('schedule', id, syncService.scheduleToMap(updated));
    notifyListeners();
  }

  Future<void> deleteSchedule(String id) async {
    await scheduleRepo.delete(id);
    _pushDelete('schedule', id);
    notifyListeners();
  }

  // ---------- quotes ----------
  Future<void> seedQuotes() async {
    await quotesRepo.seedIfEmpty();
    notifyListeners();
  }

  Future<void> addCustomQuote(String text, String author) async {
    await quotesRepo.addCustom(text: text, author: author);
    notifyListeners();
  }

  Future<void> deleteQuote(String id) async {
    await quotesRepo.delete(id);
    notifyListeners();
  }

  // ---------- export ----------
  /// Returns a complete JSON-serializable map of all app data.
  Map<String, dynamic> exportAllData() {
    final data = <String, dynamic>{};

    // settings
    data['settings'] = {
      'userName': settings.userName,
      'themeMode': settings.themeMode.name,
      'onboardingComplete': settings.onboardingComplete,
    };

    // habits
    data['habits'] = habitsRepo
        .getAll()
        .map((h) => {
              'id': h.id,
              'name': h.name,
              'category': h.category.name,
              'frequency': h.frequency.name,
              'customDays': h.customDays,
              'completionLog':
                  h.completionLog.map((d) => d.toIso8601String()).toList(),
              'createdAt': h.createdAt.toIso8601String(),
              'iconIndex': h.iconIndex,
              'colorValue': h.colorValue,
              'targetStreak': h.targetStreak,
              'currentStreak': h.currentStreak(),
              'bestStreak': h.bestStreak(),
              'totalCompletions': h.totalCompletions,
              'completionRate': h.completionRate(),
            })
        .toList();

    // tasks
    data['tasks'] = tasksRepo
        .getAll(includeArchived: true)
        .map((t) => {
              'id': t.id,
              'title': t.title,
              'description': t.description,
              'priority': t.priority.name,
              'status': t.status.name,
              'category': t.category.name,
              'dueDate': t.dueDate?.toIso8601String(),
              'tags': t.tags,
              'subtasks': List.generate(
                  t.subtaskTitles.length,
                  (i) => {
                        'title': t.subtaskTitles[i],
                        'done':
                            i < t.subtaskDone.length ? t.subtaskDone[i] : false,
                      }),
              'isRecurring': t.isRecurring,
              'recurringPattern': t.recurringPattern,
              'createdAt': t.createdAt.toIso8601String(),
              'completedAt': t.completedAt?.toIso8601String(),
              'archived': t.archived,
            })
        .toList();

    // goals
    data['goals'] = goalsRepo
        .getAll(includeArchived: true)
        .map((g) => {
              'id': g.id,
              'title': g.title,
              'description': g.description,
              'category': g.category.name,
              'deadline': g.deadline?.toIso8601String(),
              'targetValue': g.targetValue,
              'currentValue': g.currentValue,
              'progress': g.progressFraction,
              'milestones': List.generate(
                  g.milestoneTitles.length,
                  (i) => {
                        'title': g.milestoneTitles[i],
                        'done': i < g.milestoneDone.length
                            ? g.milestoneDone[i]
                            : false,
                        'dueDate': i < g.milestoneDates.length
                            ? g.milestoneDates[i]?.toIso8601String()
                            : null,
                      }),
              'completed': g.completed,
              'archived': g.archived,
              'createdAt': g.createdAt.toIso8601String(),
            })
        .toList();

    // journal
    data['journal'] = journalRepo
        .getAll()
        .map((j) => {
              'id': j.id,
              'title': j.title,
              'body': j.body,
              'mood': j.mood?.name,
              'date': j.date.toIso8601String(),
              'tags': j.tags,
              'isFavorite': j.isFavorite,
              'createdAt': j.createdAt.toIso8601String(),
            })
        .toList();

    // notes
    data['notes'] = notesRepo
        .getAll()
        .map((n) => {
              'id': n.id,
              'title': n.title,
              'body': n.body,
              'mood': n.mood?.name,
              'timestamp': n.timestamp.toIso8601String(),
              'habitId': n.habitId,
              'linkedDate': n.linkedDate?.toIso8601String(),
            })
        .toList();

    // finance
    data['finance'] = financeRepo
        .getAll()
        .map((f) => {
              'id': f.id,
              'title': f.title,
              'amount': f.amount,
              'type': f.type.name,
              'category': f.categoryLabel,
              'date': f.date.toIso8601String(),
              'note': f.note,
              'createdAt': f.createdAt.toIso8601String(),
            })
        .toList();

    // finance budget
    final budget = financeRepo.budget;
    data['financeBudget'] = {
      'monthlyBudget': budget.monthlyBudget,
      'savingsGoal': budget.savingsGoal,
      'categoryLimits': budget.categoryLimits,
    };

    // focus sessions
    data['focusSessions'] = focusRepo
        .getAll()
        .map((s) => {
              'id': s.id,
              'type': s.type.name,
              'durationSeconds': s.durationSeconds,
              'completedSeconds': s.completedSeconds,
              'completed': s.completed,
              'startedAt': s.startedAt.toIso8601String(),
              'taskTitle': s.taskTitle,
            })
        .toList();

    // schedule
    data['schedule'] = scheduleRepo
        .getAll()
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'dateTime': s.dateTime.toIso8601String(),
              'done': s.done,
            })
        .toList();

    // quotes
    data['quotes'] = quotesRepo
        .getAll()
        .map((q) => {
              'id': q.id,
              'text': q.text,
              'author': q.author,
              'isCustom': q.isCustom,
            })
        .toList();

    // summary counts
    data['_summary'] = {
      'habitsCount': habitsRepo.getAll().length,
      'tasksCount': tasksRepo.getAll(includeArchived: true).length,
      'goalsCount': goalsRepo.getAll(includeArchived: true).length,
      'journalCount': journalRepo.getAll().length,
      'notesCount': notesRepo.getAll().length,
      'financeEntriesCount': financeRepo.getAll().length,
      'focusSessionsCount': focusRepo.getAll().length,
      'scheduleItemsCount': scheduleRepo.getAll().length,
      'quotesCount': quotesRepo.getAll().length,
    };

    return data;
  }

  // ---------- enum helpers ----------
  HabitCategory _habitCategory(int i) =>
      HabitCategory.values[i.clamp(0, HabitCategory.values.length - 1)];
  HabitFrequency _habitFrequency(int i) =>
      HabitFrequency.values[i.clamp(0, HabitFrequency.values.length - 1)];
  TaskPriority _taskPriority(int i) =>
      TaskPriority.values[i.clamp(0, TaskPriority.values.length - 1)];
  TaskCategory _taskCategory(int i) =>
      TaskCategory.values[i.clamp(0, TaskCategory.values.length - 1)];
  TaskStatus _taskStatus(int i) =>
      TaskStatus.values[i.clamp(0, TaskStatus.values.length - 1)];
}
