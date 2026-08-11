import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../data/models/user_settings.dart';
import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/models/goal.dart';
import '../data/models/note.dart';
import '../data/models/finance_entry.dart';
import '../data/hive_boxes.dart';
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
import '../data/repositories/savings_goal_repository.dart';
import '../data/models/savings_goal.dart';
import '../data/models/journal_entry.dart';
import '../data/models/schedule_item.dart';
import '../data/models/quote.dart';
import '../data/models/focus_session.dart';
import '../services/notification_service.dart';

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
  final savingsGoalsRepo = SavingsGoalRepository();

  final notificationService = NotificationService();

  bool _busy = false;
  bool get busy => _busy;

  Future<void> initNotifications() async {
    await notificationService.refreshAll(
      tasks: tasksRepo.getAll(includeArchived: true),
      schedule: scheduleRepo.getAll(),
    );
  }

  /// Called on app startup to generate overdue recurring task occurrences.
  Future<void> processRecurringTasks() async {
    final created = await tasksRepo.generateOverdueOccurrences();
    if (created.isNotEmpty) {
      for (final task in created) {
        await notificationService.scheduleTask(task);
      }
    }
  }

  Future<bool> requestNotificationPermission() =>
      notificationService.requestPermission();

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
    String? goalId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await habitsRepo.create(
        name: name,
        category: _habitCategory(categoryIndex),
        frequency: _habitFrequency(frequencyIndex),
        customDays: customDays,
        iconIndex: iconIndex,
        colorValue: colorValue,
        targetStreak: targetStreak,
        goalId: goalId,
      );
      if (goalId != null) await syncGoalProgress(goalId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.toggleCompletion(h, date: date);
    if (h.goalId != null) await syncGoalProgress(h.goalId!);
    notifyListeners();
  }

  Future<void> skipHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.skipDay(h, date: date);
    if (h.goalId != null) await syncGoalProgress(h.goalId!);
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    final habit = habitsRepo.getById(id);
    await habitsRepo.delete(id);
    if (habit?.goalId != null) await syncGoalProgress(habit!.goalId!);
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await habitsRepo.update(habit);
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
    bool isRecurring = false,
    String recurringPattern = '',
    String? goalId,
    String? habitId,
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
        isRecurring: isRecurring,
        recurringPattern: recurringPattern,
        goalId: goalId,
        habitId: habitId,
      );
      await notificationService.scheduleTask(task);
      if (goalId != null) await syncGoalProgress(goalId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskDone(String id) async {
    final t = tasksRepo.getById(id);
    if (t == null) return;
    if (t.status == TaskStatus.done) {
      t.status = _taskStatus(0); // back to todo
      t.completedAt = null;
    } else {
      t.status = _taskStatus(2); // done
      t.completedAt = DateTime.now();
    }
    t.touch();
    await tasksRepo.update(t);
    await notificationService.scheduleTask(t);
    if (t.goalId != null) await syncGoalProgress(t.goalId!);
    notifyListeners();
  }

  Future<void> toggleSubtask(String taskId, int index) async {
    final t = tasksRepo.getById(taskId);
    if (t == null) return;
    await tasksRepo.toggleSubtask(t, index);
    if (t.goalId != null) await syncGoalProgress(t.goalId!);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    final task = tasksRepo.getById(id);
    await tasksRepo.delete(id);
    await notificationService.cancelTask(id);
    if (task?.goalId != null) await syncGoalProgress(task!.goalId!);
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
      await goalsRepo.create(
        title: title,
        description: description,
        categoryIndex: categoryIndex,
        deadline: deadline,
        targetValue: targetValue,
        colorValue: colorValue,
      );
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
    notifyListeners();
  }

  Future<void> toggleGoalMilestone(String id, int index) async {
    final g = goalsRepo
        .getAll(includeArchived: true)
        .where((g) => g.id == id)
        .firstOrNull;
    if (g == null) return;
    await goalsRepo.toggleMilestone(g, index);
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
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await goalsRepo.delete(id);
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
    String folder = 'Notes',
    List<String> tags = const [],
    List<String> attachmentPaths = const [],
    String? linkedEntityType,
    String? linkedEntityId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await notesRepo.create(
        title: title,
        body: body,
        moodIndex: moodIndex,
        folder: folder,
        tags: tags,
        attachmentPaths: attachmentPaths,
        linkedEntityType: linkedEntityType,
        linkedEntityId: linkedEntityId,
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
    String? goalId,
    double plannedAmount = 0,
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
        goalId: goalId,
        plannedAmount: plannedAmount,
      );
      if (goalId != null) await syncGoalProgress(goalId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteFinance(String id) async {
    final entry =
        financeRepo.getAll().where((item) => item.id == id).firstOrNull;
    await financeRepo.delete(id);
    if (entry?.goalId != null) await syncGoalProgress(entry!.goalId!);
    notifyListeners();
  }

  /// Recalculates a goal's progress from all linked habits, tasks, finance
  /// contributions, and savings goals.  Only runs if the goal is in
  /// auto-progress mode (isAutoProgress == true).  Manual progress goals
  /// are never overwritten by auto-sync.
  Future<void> syncGoalProgress(String goalId) async {
    final goal = goalsRepo
        .getAll(includeArchived: true)
        .where((item) => item.id == goalId)
        .firstOrNull;
    if (goal == null) return;
    if (!goal.isAutoProgress) return;
    final pct = computeGoalProgress(goalId);
    final linkedValue = pct * goal.targetValue;
    // Directly set value without flipping isAutoProgress (unlike updateProgress)
    goal.currentValue = linkedValue.clamp(0.0, goal.targetValue).toDouble();
    goal.completed =
        goal.targetValue > 0 && goal.currentValue >= goal.targetValue;
    goal.touch();
    await goalsRepo.update(goal);
  }

  /// Computes the auto-calculated progress percentage (0.0–1.0) for a goal
  /// from all linked entities:
  ///   - 30-day habit completion rate (average across linked habits)
  ///   - task completion fraction (average across linked tasks)
  ///   - finance progress fraction (contributed / target)
  ///   - savings goal progress fraction (average across linked savings goals)
  /// All three fractions are equally weighted when present.
  double computeGoalProgress(String goalId) {
    final goal = goalsRepo
        .getAll(includeArchived: true)
        .where((item) => item.id == goalId)
        .firstOrNull;
    if (goal == null) return 0;

    final habits =
        habitsRepo.getAll().where((h) => h.goalId == goalId).toList();
    final tasks = tasksRepo
        .getAll(includeArchived: true)
        .where((t) => t.goalId == goalId)
        .toList();
    final savingsGoals = savingsGoalsRepo.getForGoal(goalId);

    final fractions = <double>[];

    // 30-day habit completion rate
    if (habits.isNotEmpty) {
      final habitRate =
          habits.fold(0.0, (s, h) => s + h.completionRate(days: 30)) /
              habits.length;
      fractions.add(habitRate);
    }

    // Task completion fraction
    if (tasks.isNotEmpty) {
      final taskFrac = tasks.fold(0.0, (s, t) => s + t.progress) / tasks.length;
      fractions.add(taskFrac);
    }

    // Finance / savings progress fraction
    if (goal.category == GoalCategory.finance) {
      final financeTotal = financeRepo.contributedToGoal(goalId);
      if (savingsGoals.isNotEmpty) {
        final savingsFrac =
            savingsGoals.fold(0.0, (s, sg) => s + sg.progressFraction) /
                savingsGoals.length;
        fractions.add(savingsFrac);
      } else if (goal.targetValue > 0) {
        fractions.add((financeTotal / goal.targetValue).clamp(0.0, 1.0));
      }
    }

    if (fractions.isEmpty) return 0;
    final avg = fractions.reduce((a, b) => a + b) / fractions.length;
    return avg.clamp(0.0, 1.0);
  }

  // ---------- savings goals ----------

  Future<void> addSavingsGoal({
    required String title,
    required double targetAmount,
    required int targetDays,
    String? goalId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await savingsGoalsRepo.create(
        title: title,
        targetAmount: targetAmount,
        targetDays: targetDays,
        goalId: goalId,
      );
      if (goalId != null) await syncGoalProgress(goalId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> confirmSavingsContribution(String id) async {
    final sg = savingsGoalsRepo.getById(id);
    if (sg == null) return;
    await savingsGoalsRepo.confirmContribution(sg);
    if (sg.goalId != null) await syncGoalProgress(sg.goalId!);
    notifyListeners();
  }

  Future<void> recalculateSavingsGoal(String id) async {
    final sg = savingsGoalsRepo.getById(id);
    if (sg == null) return;
    await savingsGoalsRepo.recalculate(sg);
    if (sg.goalId != null) await syncGoalProgress(sg.goalId!);
    notifyListeners();
  }

  Future<void> deleteSavingsGoal(String id) async {
    final sg = savingsGoalsRepo.getById(id);
    await savingsGoalsRepo.delete(id);
    if (sg?.goalId != null) await syncGoalProgress(sg!.goalId!);
    notifyListeners();
  }

  // ---------- dashboard config ----------

  Future<void> setDashboardConfig(DashboardConfig config) async {
    await settingsRepo.setDashboardConfig(config);
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
      await notificationService.scheduleItem(item);
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
    if (updated != null) {
      await notificationService.scheduleItem(updated);
    }
    notifyListeners();
  }

  Future<void> deleteSchedule(String id) async {
    await scheduleRepo.delete(id);
    await notificationService.cancelSchedule(id);
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
    final data = <String, dynamic>{
      'format': 'yourself-backup',
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    // settings — includes dashboardConfig
    final s = settings;
    data['settings'] = {
      'userName': s.userName,
      'themeMode': s.themeMode.name,
      'onboardingComplete': s.onboardingComplete,
      'dashboardConfig': s.dashboardConfig.toMap(),
    };

    // habits — includes skipLog, updatedAt, linkedGoalId
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
              'skipLog': h.skipLog.map((d) => d.toIso8601String()).toList(),
              'createdAt': h.createdAt.toIso8601String(),
              'updatedAt': h.updatedAt.toIso8601String(),
              'iconIndex': h.iconIndex,
              'colorValue': h.colorValue,
              'targetStreak': h.targetStreak,
              'goalId': h.goalId,
              'linkedGoalId': h.linkedGoalId,
            })
        .toList();

    // tasks — includes dueTime, updatedAt, linkedGoalId, linkedHabitId, milestoneIds
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
              'dueTime': t.dueTime?.toIso8601String(),
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
              'updatedAt': t.updatedAt.toIso8601String(),
              'goalId': t.goalId,
              'habitId': t.habitId,
              'linkedGoalId': t.linkedGoalId,
              'linkedHabitId': t.linkedHabitId,
            })
        .toList();

    // goals — includes milestoneIds, colorValue, updatedAt, linked fields, progressPercent, isAutoProgress
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
              'milestoneIds': g.milestoneIds,
              'milestones': List.generate(
                  g.milestoneTitles.length,
                  (i) => {
                        'id': i < g.milestoneIds.length
                            ? g.milestoneIds[i]
                            : null,
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
              'colorValue': g.colorValue,
              'createdAt': g.createdAt.toIso8601String(),
              'updatedAt': g.updatedAt.toIso8601String(),
              'linkedHabitIds': g.linkedHabitIds,
              'linkedTaskIds': g.linkedTaskIds,
              'linkedFinanceId': g.linkedFinanceId,
              'progressPercent': g.progressPercent,
              'isAutoProgress': g.isAutoProgress,
            })
        .toList();

    // journal — includes updatedAt
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
              'updatedAt': j.updatedAt.toIso8601String(),
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
              'folder': n.folder,
              'tags': n.tags,
              'attachmentPaths': n.attachmentPaths,
              'linkedEntityType': n.linkedEntityType,
              'linkedEntityId': n.linkedEntityId,
            })
        .toList();

    // finance — includes all schema fields
    data['finance'] = financeRepo
        .getAll()
        .map((f) => {
              'id': f.id,
              'title': f.title,
              'amount': f.amount,
              'type': f.type.name,
              'typeIndex': f.typeIndex,
              'category': f.categoryLabel,
              'categoryIndex': f.categoryIndex,
              'date': f.date.toIso8601String(),
              'note': f.note,
              'createdAt': f.createdAt.toIso8601String(),
              'goalId': f.goalId,
              'plannedAmount': f.plannedAmount,
              'targetAmount': f.targetAmount,
              'targetDays': f.targetDays,
              'dailyAmount': f.dailyAmount,
              'contributionLogDates': f.contributionLogDates
                  .map((d) => d.toIso8601String())
                  .toList(),
              'contributionLogAmounts': f.contributionLogAmounts,
              'contributionLogConfirmed': f.contributionLogConfirmed,
              'linkedGoalId': f.linkedGoalId,
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
              'typeIndex': s.typeIndex,
              'durationSeconds': s.durationSeconds,
              'completedSeconds': s.completedSeconds,
              'completed': s.completed,
              'startedAt': s.startedAt.toIso8601String(),
              'taskTitle': s.taskTitle,
            })
        .toList();

    // schedule — includes updatedAt
    data['schedule'] = scheduleRepo
        .getAll()
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'dateTime': s.dateTime.toIso8601String(),
              'done': s.done,
              'updatedAt': s.updatedAt.toIso8601String(),
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

    // savings goals — includes updatedAt
    data['savingsGoals'] = savingsGoalsRepo
        .getAll()
        .map((sg) => {
              'id': sg.id,
              'title': sg.title,
              'targetAmount': sg.targetAmount,
              'targetDays': sg.targetDays,
              'startDate': sg.startDate.toIso8601String(),
              'contributionDates':
                  sg.contributionDates.map((d) => d.toIso8601String()).toList(),
              'contributionAmounts': sg.contributionAmounts,
              'goalId': sg.goalId,
              'createdAt': sg.createdAt.toIso8601String(),
              'updatedAt': sg.updatedAt.toIso8601String(),
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
      'savingsGoalsCount': savingsGoalsRepo.getAll().length,
    };

    return data;
  }

  /// Validates and restores all data from a local backup.
  /// Parses ALL data into local lists first; only if every collection
  /// parses successfully are existing boxes cleared and new data written.
  /// If parsing fails at any point, existing data is left untouched.
  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['format'] != 'yourself-backup' || data['version'] is! num) {
      throw const FormatException('This is not a valid Yourself backup file.');
    }
    for (final key in ['habits', 'tasks', 'goals', 'notes', 'finance']) {
      if (data[key] is! List) {
        throw FormatException('Backup is missing the $key collection.');
      }
    }

    // ── Parse ALL collections into local lists FIRST ──
    // If any parse fails, we throw before touching existing data.

    final goals = <Goal>[];
    for (final raw in data['goals'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final milestones = (item['milestones'] as List? ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      goals.add(Goal(
        id: item['id'] as String,
        title: item['title'] as String,
        description: item['description'] as String? ?? '',
        categoryIndex: GoalCategory.values
            .indexWhere((value) => value.name == item['category']),
        deadline: _date(item['deadline']),
        targetValue: (item['targetValue'] as num?)?.toDouble() ?? 100,
        currentValue: (item['currentValue'] as num?)?.toDouble() ?? 0,
        milestoneIds: (item['milestoneIds'] as List?)?.cast<String>() ??
            milestones
                .map((m) => m['id'] as String?)
                .where((id) => id != null)
                .cast<String>()
                .toList(),
        milestoneTitles: milestones.map((m) => m['title'] as String).toList(),
        milestoneDone:
            milestones.map((m) => m['done'] as bool? ?? false).toList(),
        milestoneDates: milestones.map((m) => _date(m['dueDate'])).toList(),
        completed: item['completed'] as bool? ?? false,
        archived: item['archived'] as bool? ?? false,
        colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF6B9080,
        createdAt: _date(item['createdAt']),
        updatedAt: _date(item['updatedAt']),
        linkedHabitIds: (item['linkedHabitIds'] as List?)?.cast<String>() ?? [],
        linkedTaskIds: (item['linkedTaskIds'] as List?)?.cast<String>() ?? [],
        linkedFinanceId: item['linkedFinanceId'] as String?,
        progressPercent: (item['progressPercent'] as num?)?.toDouble() ?? 0,
        isAutoProgress: item['isAutoProgress'] as bool? ?? true,
      ));
    }

    final habits = <Habit>[];
    for (final raw in data['habits'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      habits.add(Habit(
        id: item['id'] as String,
        name: item['name'] as String,
        category: HabitCategory.values.firstWhere(
          (value) => value.name == item['category'],
          orElse: () => HabitCategory.other,
        ),
        frequency: HabitFrequency.values.firstWhere(
          (value) => value.name == item['frequency'],
          orElse: () => HabitFrequency.daily,
        ),
        customDays: (item['customDays'] as List?)?.cast<int>() ?? [],
        completionLog: (item['completionLog'] as List? ?? [])
            .map((value) => DateTime.parse(value as String))
            .toList(),
        skipLog: (item['skipLog'] as List? ?? [])
            .map((value) => DateTime.parse(value as String))
            .toList(),
        createdAt: _date(item['createdAt']),
        updatedAt: _date(item['updatedAt']),
        iconIndex: item['iconIndex'] as int? ?? 15,
        colorValue: item['colorValue'] as int?,
        targetStreak: item['targetStreak'] as int? ?? 0,
        goalId: item['goalId'] as String?,
        linkedGoalId: item['linkedGoalId'] as String?,
      ));
    }

    final tasks = <Task>[];
    for (final raw in data['tasks'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final subtasks = (item['subtasks'] as List? ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      tasks.add(Task(
        id: item['id'] as String,
        title: item['title'] as String,
        description: item['description'] as String? ?? '',
        priority: TaskPriority.values.firstWhere(
          (value) => value.name == item['priority'],
          orElse: () => TaskPriority.medium,
        ),
        status: TaskStatus.values.firstWhere(
          (value) => value.name == item['status'],
          orElse: () => TaskStatus.todo,
        ),
        category: TaskCategory.values.firstWhere(
          (value) => value.name == item['category'],
          orElse: () => TaskCategory.other,
        ),
        dueDate: _date(item['dueDate']),
        dueTime: _date(item['dueTime']),
        tags: (item['tags'] as List?)?.cast<String>() ?? [],
        subtaskTitles: subtasks.map((item) => item['title'] as String).toList(),
        subtaskDone:
            subtasks.map((item) => item['done'] as bool? ?? false).toList(),
        isRecurring: item['isRecurring'] as bool? ?? false,
        recurringPattern: item['recurringPattern'] as String? ?? '',
        createdAt: _date(item['createdAt']),
        completedAt: _date(item['completedAt']),
        archived: item['archived'] as bool? ?? false,
        updatedAt: _date(item['updatedAt']),
        goalId: item['goalId'] as String?,
        habitId: item['habitId'] as String?,
        linkedGoalId: item['linkedGoalId'] as String?,
        linkedHabitId: item['linkedHabitId'] as String?,
      ));
    }

    final notes = <Note>[];
    for (final raw in data['notes'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      notes.add(Note(
        id: item['id'] as String,
        title: item['title'] as String,
        body: item['body'] as String? ?? '',
        timestamp: _date(item['timestamp']) ?? DateTime.now(),
        habitId: item['habitId'] as String?,
        linkedDate: _date(item['linkedDate']),
        folder: item['folder'] as String? ?? 'Notes',
        tags: (item['tags'] as List?)?.cast<String>() ?? [],
        attachmentPaths:
            (item['attachmentPaths'] as List?)?.cast<String>() ?? [],
        linkedEntityType: item['linkedEntityType'] as String?,
        linkedEntityId: item['linkedEntityId'] as String?,
      ));
    }

    // ── Finance: fix categoryIndex from label lookup ──
    final finance = <FinanceEntry>[];
    for (final raw in data['finance'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final isIncome =
          item['type'] == FinanceType.income.name || item['typeIndex'] == 0;
      // Look up categoryIndex from label, fall back to stored index, then 0
      int catIndex;
      if (item['categoryIndex'] is int) {
        catIndex = item['categoryIndex'] as int;
      } else if (item['category'] is String) {
        final label = item['category'] as String;
        if (isIncome) {
          catIndex = IncomeCategory.values.indexWhere((c) => c.label == label);
        } else {
          catIndex = ExpenseCategory.values.indexWhere((c) => c.label == label);
        }
        if (catIndex < 0) catIndex = 0;
      } else {
        catIndex = 0;
      }
      finance.add(FinanceEntry(
        id: item['id'] as String,
        title: item['title'] as String,
        amount: (item['amount'] as num).toDouble(),
        typeIndex: isIncome ? 0 : 1,
        categoryIndex: catIndex,
        date: _date(item['date']) ?? DateTime.now(),
        note: item['note'] as String? ?? '',
        createdAt: _date(item['createdAt']),
        goalId: item['goalId'] as String?,
        plannedAmount: (item['plannedAmount'] as num?)?.toDouble() ?? 0,
        targetAmount: (item['targetAmount'] as num?)?.toDouble() ?? 0,
        targetDays: (item['targetDays'] as num?)?.toInt() ?? 0,
        dailyAmount: (item['dailyAmount'] as num?)?.toDouble() ?? 0,
        contributionLogDates: (item['contributionLogDates'] as List? ?? [])
            .map((v) => DateTime.parse(v as String))
            .toList(),
        contributionLogAmounts:
            (item['contributionLogAmounts'] as List?)?.cast<double>() ?? [],
        contributionLogConfirmed:
            (item['contributionLogConfirmed'] as List?)?.cast<bool>() ?? [],
        linkedGoalId: item['linkedGoalId'] as String?,
      ));
    }

    // ── Savings goals ──
    final savingsGoals = <SavingsGoal>[];
    if (data['savingsGoals'] is List) {
      for (final raw in data['savingsGoals'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        savingsGoals.add(SavingsGoal(
          id: item['id'] as String,
          title: item['title'] as String,
          targetAmount: (item['targetAmount'] as num).toDouble(),
          targetDays: item['targetDays'] as int,
          startDate: _date(item['startDate']) ?? DateTime.now(),
          contributionDates: (item['contributionDates'] as List? ?? [])
              .map((v) => DateTime.parse(v as String))
              .toList(),
          contributionAmounts:
              (item['contributionAmounts'] as List?)?.cast<double>() ?? [],
          goalId: item['goalId'] as String?,
          createdAt: _date(item['createdAt']) ?? DateTime.now(),
          updatedAt: _date(item['updatedAt']),
        ));
      }
    }

    // ── Journal ──
    final journal = <JournalEntry>[];
    if (data['journal'] is List) {
      for (final raw in data['journal'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final moodName = item['mood'] as String?;
        final moodIdx = moodName != null
            ? JournalMood.values.indexWhere((m) => m.name == moodName)
            : -1;
        journal.add(JournalEntry(
          id: item['id'] as String,
          title: item['title'] as String,
          body: item['body'] as String? ?? '',
          moodIndex: moodIdx >= 0 ? moodIdx : -1,
          date: _date(item['date']) ?? DateTime.now(),
          tags: (item['tags'] as List?)?.cast<String>() ?? [],
          isFavorite: item['isFavorite'] as bool? ?? false,
          createdAt: _date(item['createdAt']) ?? DateTime.now(),
          updatedAt: _date(item['updatedAt']),
        ));
      }
    }

    // ── Schedule ──
    final schedule = <ScheduleItem>[];
    if (data['schedule'] is List) {
      for (final raw in data['schedule'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        schedule.add(ScheduleItem(
          id: item['id'] as String,
          title: item['title'] as String,
          dateTime: _date(item['dateTime']) ?? DateTime.now(),
          done: item['done'] as bool? ?? false,
          updatedAt: _date(item['updatedAt']),
        ));
      }
    }

    // ── Quotes ──
    final quotes = <Quote>[];
    if (data['quotes'] is List) {
      for (final raw in data['quotes'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        quotes.add(Quote(
          id: item['id'] as String,
          text: item['text'] as String,
          author: item['author'] as String? ?? '',
          isCustom: item['isCustom'] as bool? ?? false,
        ));
      }
    }

    // ── Focus sessions ──
    final focusSessions = <FocusSession>[];
    if (data['focusSessions'] is List) {
      for (final raw in data['focusSessions'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final typeName = item['type'] as String?;
        final typeIdx = typeName != null
            ? FocusType.values.indexWhere((t) => t.name == typeName)
            : (item['typeIndex'] as int? ?? 0);
        focusSessions.add(FocusSession(
          id: item['id'] as String,
          typeIndex: typeIdx >= 0 ? typeIdx : 0,
          durationSeconds: (item['durationSeconds'] as num?)?.toInt() ?? 0,
          completedSeconds: (item['completedSeconds'] as num?)?.toInt() ?? 0,
          completed: item['completed'] as bool? ?? false,
          startedAt: _date(item['startedAt']) ?? DateTime.now(),
          taskTitle: item['taskTitle'] as String?,
        ));
      }
    }

    // ── Settings ──
    UserSettings? newSettings;
    if (data['settings'] is Map) {
      final sMap = Map<String, dynamic>.from(data['settings'] as Map);
      final themeName = sMap['themeMode'] as String?;
      final themeIdx = themeName != null
          ? AppThemeMode.values.indexWhere((t) => t.name == themeName)
          : 0;
      DashboardConfig? dashConfig;
      if (sMap['dashboardConfig'] is Map) {
        dashConfig = DashboardConfig.fromMap(
            Map<dynamic, dynamic>.from(sMap['dashboardConfig'] as Map));
      }
      newSettings = UserSettings(
        userName: sMap['userName'] as String?,
        themeMode:
            themeIdx >= 0 ? AppThemeMode.values[themeIdx] : AppThemeMode.system,
        onboardingComplete: sMap['onboardingComplete'] as bool? ?? false,
        dashboardConfig: dashConfig ?? DashboardConfig(),
      );
    }

    // ── Finance budget ──
    FinanceBudget? newBudget;
    if (data['financeBudget'] is Map) {
      final bMap = Map<String, dynamic>.from(data['financeBudget'] as Map);
      final rawLimits = bMap['categoryLimits'] as Map?;
      newBudget = FinanceBudget(
        monthlyBudget: (bMap['monthlyBudget'] as num?)?.toDouble() ?? 0,
        savingsGoal: (bMap['savingsGoal'] as num?)?.toDouble() ?? 0,
        categoryLimits: rawLimits?.map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
            {},
      );
    }

    // ══ ALL PARSING SUCCEEDED — now safe to clear and write ══
    final goalBox = Hive.box<Goal>(HiveBoxes.goals);
    final habitBox = Hive.box<Habit>(HiveBoxes.habits);
    final taskBox = Hive.box<Task>(HiveBoxes.tasks);
    final noteBox = Hive.box<Note>(HiveBoxes.notes);
    final financeBox = Hive.box<FinanceEntry>(HiveBoxes.finance);
    final savingsBox = Hive.box<SavingsGoal>(HiveBoxes.savingsGoals);
    final journalBox = Hive.box<JournalEntry>(HiveBoxes.journal);
    final scheduleBox = Hive.box<ScheduleItem>(HiveBoxes.schedule);
    final quotesBox = Hive.box<Quote>(HiveBoxes.quotes);
    final focusBox = Hive.box<FocusSession>(HiveBoxes.focus);
    final settingsBox = Hive.box<UserSettings>(HiveBoxes.settings);
    final budgetBox = Hive.box<FinanceBudget>(HiveBoxes.financeBudget);

    await Future.wait([
      goalBox.clear(),
      habitBox.clear(),
      taskBox.clear(),
      noteBox.clear(),
      financeBox.clear(),
      savingsBox.clear(),
      journalBox.clear(),
      scheduleBox.clear(),
      quotesBox.clear(),
      focusBox.clear(),
    ]);

    await goalBox.putAll({for (final item in goals) item.id: item});
    await habitBox.putAll({for (final item in habits) item.id: item});
    await taskBox.putAll({for (final item in tasks) item.id: item});
    await noteBox.putAll({for (final item in notes) item.id: item});
    await financeBox.putAll({for (final item in finance) item.id: item});
    await savingsBox.putAll({for (final item in savingsGoals) item.id: item});
    await journalBox.putAll({for (final item in journal) item.id: item});
    await scheduleBox.putAll({for (final item in schedule) item.id: item});
    await quotesBox.putAll({for (final item in quotes) item.id: item});
    await focusBox.putAll({for (final item in focusSessions) item.id: item});

    if (newSettings != null) {
      await settingsBox.put(HiveBoxes.settingsKey, newSettings);
    }
    if (newBudget != null) {
      await budgetBox.put('budget', newBudget);
    }

    // Re-sync goal progress for auto goals after import
    for (final g in goals) {
      if (g.isAutoProgress) await syncGoalProgress(g.id);
    }

    notifyListeners();
  }

  DateTime? _date(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
