import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../data/models/user_settings.dart';
import '../data/models/habit.dart';
import '../data/models/task.dart';
import '../data/models/recurrence_rule.dart';
import '../data/models/task_category.dart';
import '../data/models/reminder_rule.dart';
import '../data/models/goal.dart';
import '../data/models/note.dart';
import '../data/models/finance_entry.dart';
import '../data/hive_boxes.dart';
import '../data/repositories/habits_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../data/repositories/task_categories_repository.dart';
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
import 'goal_progress_engine.dart';
import 'dart:async';

/// Central app state exposed via [Provider].
///
/// Holds all repository singletons and a [notifyListeners] hook so the
/// entire widget tree can rebuild after any CRUD mutation.
class AppState extends ChangeNotifier {
  final habitsRepo = HabitsRepository();
  final tasksRepo = TasksRepository();
  final taskCategoriesRepo = TaskCategoriesRepository();
  final goalsRepo = GoalsRepository();
  final notesRepo = NotesRepository();
  final journalRepo = JournalRepository();
  final financeRepo = FinanceRepository();
  final focusRepo = FocusRepository();
  final scheduleRepo = ScheduleRepository();
  final quotesRepo = QuotesRepository();
  final settingsRepo = SettingsRepository();
  final savingsGoalsRepo = SavingsGoalRepository();

  final NotificationService notificationService;

  /// [notificationService] is injectable (defaults to a real
  /// [NotificationService]) purely so tests can substitute a fake that
  /// simulates plugin-initialization failures without touching platform
  /// channels, e.g. to verify that a failure in one startup step never
  /// silently skips the other (see main.dart's startup wiring).
  AppState({NotificationService? notificationService})
      : notificationService = notificationService ?? NotificationService();

  bool _busy = false;
  bool quickCaptureOpen = false;

  void toggleQuickCapture() {
    quickCaptureOpen = !quickCaptureOpen;
    notifyListeners();
  }

  void hideQuickCapture() {
    if (!quickCaptureOpen) return;
    quickCaptureOpen = false;
    notifyListeners();
  }
  bool get busy => _busy;

  Future<void> initNotifications() async {
    await notificationService.refreshAll(
      tasks: tasksRepo.getAll(includeArchived: true),
      habits: habitsRepo.getAll(),
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

  String taskCategoryLabel(Task task) =>
      taskCategoriesRepo.getById(task.customCategoryId)?.name ?? task.category.label;

  IconData taskCategoryIcon(Task task) =>
      taskCategoriesRepo.getById(task.customCategoryId)?.icon ?? task.category.icon;

  Color taskCategoryColor(Task task) =>
      taskCategoriesRepo.getById(task.customCategoryId)?.color ?? ThemeData().colorScheme.primary;

  Future<void> addTaskCategory({required String name, required Color color, required IconData icon}) async {
    await taskCategoriesRepo.create(name: name, color: color, icon: icon);
    notifyListeners();
  }

  Future<void> updateTaskCategory(TaskCategoryModel category, {String? name, Color? color, IconData? icon}) async {
    await taskCategoriesRepo.update(category, name: name, color: color, icon: icon);
    notifyListeners();
  }

  Future<void> deleteTaskCategory(String id) async {
    final affected = tasksRepo
        .getAll(includeArchived: true)
        .where((task) => task.customCategoryId == id)
        .toList();
    await taskCategoriesRepo.delete(id, tasks: affected);
    // Persist the fallback to the built-in Other category; mutating a HiveObject
    // in memory is not enough when the app is restarted.
    for (final task in affected) {
      await tasksRepo.update(task);
    }
    notifyListeners();
  }


  // ---------- onboarding ----------
  bool get onboardingComplete => settings.onboardingComplete;

  Future<void> completeOnboarding(String name) async {
    await settingsRepo.setUserName(name);
    notifyListeners();
  }

  // ---------- theme switching ----------
  Future<void> updateProfile({String? emoji, String? bio}) async {
    await settingsRepo.setProfile(emoji: emoji, bio: bio);
    notifyListeners();
  }

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
    List<ReminderRule> reminders = const [],
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final habit = await habitsRepo.create(
        name: name, category: _habitCategory(categoryIndex), frequency: _habitFrequency(frequencyIndex),
        customDays: customDays, iconIndex: iconIndex, colorValue: colorValue, targetStreak: targetStreak, goalId: goalId, reminders: reminders,
      );
      unawaited(notificationService.scheduleHabit(habit).catchError((_) {}));
      if (goalId != null) {
        await _syncGoalReverseLink(newGoalId: goalId, entityId: habit.id, kind: 'habit');
        await syncGoalProgress(goalId);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.toggleCompletion(h, date: date);
    unawaited(notificationService.scheduleHabit(h).catchError((_) {}));
    notifyListeners();
    final linkedGoalIds = {if (h.goalId != null) h.goalId!, if (h.linkedGoalId != null) h.linkedGoalId!};
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> skipHabit(String id, {DateTime? date}) async {
    final h = habitsRepo.getById(id);
    if (h == null) return;
    await habitsRepo.skipDay(h, date: date);
    unawaited(notificationService.scheduleHabit(h).catchError((_) {}));
    notifyListeners();
    final linkedGoalIds = {if (h.goalId != null) h.goalId!, if (h.linkedGoalId != null) h.linkedGoalId!};
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    final habit = habitsRepo.getById(id);
    for (final task in tasksRepo.getAll(includeArchived: true)) {
      if (task.habitId == id || task.linkedHabitId == id) {
        task.habitId = task.habitId == id ? null : task.habitId;
        task.linkedHabitId = task.linkedHabitId == id ? null : task.linkedHabitId;
        await tasksRepo.update(task);
      }
    }
    for (final note in notesRepo.getAll(includeArchived: true)) {
      if (note.habitId == id) {
        await notesRepo.update(note.copyWith(clearHabitId: true));
      } else if (note.linkedEntityType == 'habit' && note.linkedEntityId == id) {
        await notesRepo.update(note.copyWith(clearLinkedEntity: true));
      }
    }
    await habitsRepo.delete(id);
    await notificationService.cancelHabit(id);
    await _removeGoalReverseReferences(habitId: id);
    final linkedGoalIds = {
      if (habit?.goalId != null) habit!.goalId!,
      if (habit?.linkedGoalId != null) habit!.linkedGoalId!,
    };
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    final old = habitsRepo.getById(habit.id);
    await habitsRepo.update(habit);
    unawaited(notificationService.scheduleHabit(habit).catchError((_) {}));
    await _syncGoalReverseLink(oldGoalId: old?.goalId ?? old?.linkedGoalId, newGoalId: habit.goalId, entityId: habit.id, kind: 'habit');
    final ids = {if (old?.goalId != null) old!.goalId!, if (habit.goalId != null) habit.goalId!};
    for (final id in ids) await syncGoalProgress(id);
    notifyListeners();
  }

  // ---------- tasks ----------
  Future<void> addTask({
    required String title,
    String description = '',
    int priorityIndex = 1,
    int categoryIndex = 1,
    DateTime? dueDate,
    DateTime? dueTime,
    List<String> tags = const [],
    List<String> subtaskTitles = const [],
    bool isRecurring = false,
    String recurringPattern = '',
    RecurrenceRule? recurrenceRule,
    String? customCategoryId,
    List<ReminderRule> reminders = const [],
    String? goalId,
    String? habitId,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final task = await tasksRepo.create(
        title: title, description: description, priority: _taskPriority(priorityIndex), category: _taskCategory(categoryIndex),
        dueDate: dueDate, dueTime: dueTime, tags: tags, subtaskTitles: subtaskTitles, isRecurring: isRecurring, recurringPattern: recurringPattern, recurrenceRule: recurrenceRule, customCategoryId: customCategoryId, reminders: reminders, goalId: goalId, habitId: habitId,
      );
      unawaited(notificationService.scheduleTask(task).catchError((_) {}));
      if (goalId != null) {
        await _syncGoalReverseLink(newGoalId: goalId, entityId: task.id, kind: 'task');
        await syncGoalProgress(goalId);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateTask(Task task) async {
    final previous = tasksRepo.getById(task.id);
    final oldGoalIds = <String>{
      if (previous?.goalId != null) previous!.goalId!,
      if (previous?.linkedGoalId != null) previous!.linkedGoalId!,
    };
    await tasksRepo.update(task);
    await _syncGoalReverseLink(oldGoalId: previous?.goalId ?? previous?.linkedGoalId, newGoalId: task.goalId, entityId: task.id, kind: 'task');
    notifyListeners();
    unawaited(notificationService.scheduleTask(task).catchError((_) {}));
    final goalIds = {
      ...oldGoalIds,
      if (task.goalId != null) task.goalId!,
      if (task.linkedGoalId != null) task.linkedGoalId!,
    };
    for (final goalId in goalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> toggleTaskDone(String id) async {
    final task = tasksRepo.getById(id);
    if (task == null) return;
    Task? nextOccurrence;
    final linkedGoalIds = {
      if (task.goalId != null) task.goalId!,
      if (task.linkedGoalId != null) task.linkedGoalId!,
    };
    if (task.status == TaskStatus.done) {
      task.status = TaskStatus.todo;
      task.completedAt = null;
      task.touch();
      await tasksRepo.update(task);
    } else {
      nextOccurrence = await tasksRepo.markDone(task);
    }
    notifyListeners();
    unawaited(notificationService.scheduleTask(task).catchError((_) {}));
    if (nextOccurrence != null) {
      unawaited(notificationService.scheduleTask(nextOccurrence!).catchError((_) {}));
      if (nextOccurrence!.goalId != null) {
        linkedGoalIds.add(nextOccurrence!.goalId!);
      }
    }
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> toggleSubtask(String taskId, int index) async {
    final t = tasksRepo.getById(taskId);
    if (t == null) return;
    final nextOccurrence = await tasksRepo.toggleSubtask(t, index);
    final linkedGoalIds = {if (t.goalId != null) t.goalId!, if (t.linkedGoalId != null) t.linkedGoalId!};
    notifyListeners();
    if (nextOccurrence != null) {
      if (nextOccurrence!.goalId != null) {
        linkedGoalIds.add(nextOccurrence!.goalId!);
      }
      unawaited(notificationService.scheduleTask(nextOccurrence!).catchError((_) {}));
    }
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    final task = tasksRepo.getById(id);
    for (final note in notesRepo.getAll(includeArchived: true)) {
      if (note.linkedEntityType == 'task' && note.linkedEntityId == id) {
        await notesRepo.update(note.copyWith(clearLinkedEntity: true));
      }
    }
    await tasksRepo.delete(id);
    await _removeGoalReverseReferences(taskId: id);
    await notificationService.cancelTask(id);
    final linkedGoalIds = {
      if (task?.goalId != null) task!.goalId!,
      if (task?.linkedGoalId != null) task!.linkedGoalId!,
    };
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> _removeGoalReverseReferences({
    String? habitId,
    String? taskId,
    String? financeId,
  }) async {
    for (final goal in goalsRepo.getAll(includeArchived: true)) {
      var changed = false;
      if (habitId != null && goal.linkedHabitIds.remove(habitId)) changed = true;
      if (taskId != null && goal.linkedTaskIds.remove(taskId)) changed = true;
      if (financeId != null && goal.linkedFinanceId == financeId) {
        goal.linkedFinanceId = null;
        changed = true;
      }
      if (changed) {
        goal.touch();
        await goalsRepo.update(goal);
      }
    }
  }

  /// Synchronizes the reverse links on **every** goal so that an entity can
  /// only ever belong to a single goal.
  ///
  /// The canonical relationship is `Habit.goalId` / `Task.goalId` /
  /// `FinanceEntry.goalId` / `SavingsGoal.goalId`. `Goal.linkedHabitIds`,
  /// `Goal.linkedTaskIds` and `Goal.linkedFinanceId` are legacy reverse arrays
  /// kept for Hive/backup compatibility and are *derived* from the canonical
  /// field here. Passing a null [newGoalId] removes the entity from all goals.
  ///
  /// Previously only the old and new goal were visited, so a stale reverse link
  /// on any third goal (e.g. after an earlier reassignment) survived and made
  /// the progress engine count one entity toward multiple goals.
  Future<void> _syncGoalReverseLink({
    String? oldGoalId,
    String? newGoalId,
    required String entityId,
    required String kind,
  }) async {
    for (final goal in goalsRepo.getAll(includeArchived: true)) {
      final isTarget = newGoalId != null && goal.id == newGoalId;
      var changed = false;
      if (kind == 'habit') {
        if (goal.linkedHabitIds.remove(entityId)) changed = true;
        // Drop any accidental duplicates left by older versions.
        while (goal.linkedHabitIds.remove(entityId)) {}
        if (isTarget) {
          goal.linkedHabitIds.add(entityId);
          changed = true;
        }
      } else if (kind == 'task') {
        if (goal.linkedTaskIds.remove(entityId)) changed = true;
        while (goal.linkedTaskIds.remove(entityId)) {}
        if (isTarget) {
          goal.linkedTaskIds.add(entityId);
          changed = true;
        }
      } else if (kind == 'finance') {
        if (goal.linkedFinanceId == entityId) {
          goal.linkedFinanceId = null;
          changed = true;
        }
        if (isTarget) {
          goal.linkedFinanceId = entityId;
          changed = true;
        }
      }
      if (changed) {
        goal.touch();
        await goalsRepo.update(goal);
      }
    }
  }

  // ---------- goals ----------
  Future<Goal> addGoal({
    required String title,
    String description = '',
    int categoryIndex = 6,
    DateTime? deadline,
    double targetValue = 100,
    int colorValue = 0xFF6B9080,
    DateTime? startDate,
    GoalProgressMode progressMode = GoalProgressMode.auto,
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
        startDate: startDate,
        progressMode: progressMode,
      );
      return goal;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateGoal(Goal goal, {
    List<String>? habitIds,
    List<String>? taskIds,
    String? financeId,
    List<String>? savingsIds,
    bool clearFinance = false,
  }) async {
    final selectedHabits = {...(habitIds ?? goal.linkedHabitIds)}
      ..retainAll(habitsRepo.getAll().map((h) => h.id));
    final selectedTasks = {...(taskIds ?? goal.linkedTaskIds)}
      ..retainAll(tasksRepo.getAll(includeArchived: true).map((t) => t.id));
    final selectedFinanceId = clearFinance ? null : (financeId ?? goal.linkedFinanceId);
    final financeIds = financeRepo.getAll().map((f) => f.id).toSet();
    final selectedFinance = selectedFinanceId != null && financeIds.contains(selectedFinanceId) ? selectedFinanceId : null;
    final selectedSavings = {...(savingsIds ?? savingsGoalsRepo.getForGoal(goal.id).map((s) => s.id))}
      ..retainAll(savingsGoalsRepo.getAll().map((s) => s.id));

    final habitCandidates = {for (final h in habitsRepo.getAll()) h.id: h};
    for (final habit in habitCandidates.values) {
      if (habit.goalId == goal.id || habit.linkedGoalId == goal.id || selectedHabits.contains(habit.id)) {
        habit.goalId = selectedHabits.contains(habit.id) ? goal.id : null;
        habit.linkedGoalId = null;
        await habitsRepo.update(habit);
      }
    }
    final taskCandidates = {for (final t in tasksRepo.getAll(includeArchived: true)) t.id: t};
    for (final task in taskCandidates.values) {
      if (task.goalId == goal.id || task.linkedGoalId == goal.id || selectedTasks.contains(task.id)) {
        task.goalId = selectedTasks.contains(task.id) ? goal.id : null;
        task.linkedGoalId = null;
        await tasksRepo.update(task);
      }
    }
    final financeCandidates = {for (final f in financeRepo.getAll()) f.id: f};
    for (final entry in financeCandidates.values) {
      if (entry.goalId == goal.id || entry.linkedGoalId == goal.id || selectedFinance == entry.id) {
        entry.goalId = selectedFinance == entry.id ? goal.id : null;
        entry.linkedGoalId = null;
        await financeRepo.update(entry);
      }
    }
    for (final saving in savingsGoalsRepo.getAll()) {
      if (saving.goalId == goal.id || selectedSavings.contains(saving.id)) {
        saving.goalId = selectedSavings.contains(saving.id) ? goal.id : null;
        await savingsGoalsRepo.update(saving);
      }
    }
    goal.linkedHabitIds = selectedHabits.toList();
    goal.linkedTaskIds = selectedTasks.toList();
    goal.linkedFinanceId = selectedFinance;
    goal.isAutoProgress = goal.progressMode != GoalProgressMode.manual;
    await goalsRepo.update(goal);
    // Reassigning an entity to this goal must strip it from whichever goal
    // previously owned it, otherwise the stale reverse link would let the
    // progress engine count it twice.
    final affected = await rebuildGoalReverseLinks(skipGoalId: goal.id);
    await syncGoalProgress(goal.id);
    for (final id in affected) {
      if (id != goal.id) await syncGoalProgress(id);
    }
    notifyListeners();
  }

  /// Derives every goal's legacy reverse arrays from the canonical
  /// `goalId` fields, removing stale links left behind by reassignment.
  ///
  /// Entities that have *no* canonical owner at all (legacy Hive data written
  /// before `goalId` existed) keep their existing reverse-array membership so
  /// old backups are not silently unlinked.
  ///
  /// Returns the IDs of the goals that were modified.
  Future<Set<String>> rebuildGoalReverseLinks({String? skipGoalId}) async {
    final habits = habitsRepo.getAll();
    final tasks = tasksRepo.getAll(includeArchived: true);
    final finance = financeRepo.getAll();
    final changedGoals = <String>{};

    for (final goal in goalsRepo.getAll(includeArchived: true)) {
      final habitIds = <String>[];
      for (final h in habits) {
        if (h.goalId != null) {
          if (h.goalId == goal.id) habitIds.add(h.id);
        } else if (h.linkedGoalId != null) {
          if (h.linkedGoalId == goal.id) habitIds.add(h.id);
        } else if (goal.linkedHabitIds.contains(h.id)) {
          habitIds.add(h.id);
        }
      }
      final taskIds = <String>[];
      for (final t in tasks) {
        if (t.goalId != null) {
          if (t.goalId == goal.id) taskIds.add(t.id);
        } else if (t.linkedGoalId != null) {
          if (t.linkedGoalId == goal.id) taskIds.add(t.id);
        } else if (goal.linkedTaskIds.contains(t.id)) {
          taskIds.add(t.id);
        }
      }
      String? financeId;
      for (final f in finance) {
        if (f.goalId == goal.id || f.linkedGoalId == goal.id) {
          financeId = f.id;
          break;
        }
      }
      if (financeId == null &&
          goal.linkedFinanceId != null &&
          finance.any((f) => f.id == goal.linkedFinanceId &&
              f.goalId == null &&
              f.linkedGoalId == null)) {
        financeId = goal.linkedFinanceId;
      }

      final changed = !_sameIds(goal.linkedHabitIds, habitIds) ||
          !_sameIds(goal.linkedTaskIds, taskIds) ||
          goal.linkedFinanceId != financeId;
      if (!changed) continue;
      goal.linkedHabitIds = habitIds;
      goal.linkedTaskIds = taskIds;
      goal.linkedFinanceId = financeId;
      goal.touch();
      await goalsRepo.update(goal);
      if (goal.id != skipGoalId) changedGoals.add(goal.id);
    }
    return changedGoals;
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
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
    for (final habit in habitsRepo.getAll()) {
      if (habit.goalId == id || habit.linkedGoalId == id) {
        habit.goalId = habit.goalId == id ? null : habit.goalId;
        habit.linkedGoalId = habit.linkedGoalId == id ? null : habit.linkedGoalId;
        await habitsRepo.update(habit);
      }
    }
    for (final task in tasksRepo.getAll(includeArchived: true)) {
      if (task.goalId == id || task.linkedGoalId == id) {
        task.goalId = task.goalId == id ? null : task.goalId;
        task.linkedGoalId = task.linkedGoalId == id ? null : task.linkedGoalId;
        await tasksRepo.update(task);
      }
    }
    for (final finance in financeRepo.getAll()) {
      if (finance.goalId == id || finance.linkedGoalId == id) {
        finance.goalId = finance.goalId == id ? null : finance.goalId;
        finance.linkedGoalId = finance.linkedGoalId == id ? null : finance.linkedGoalId;
        finance.touch();
        await financeRepo.update(finance);
      }
    }
    for (final savings in savingsGoalsRepo.getAll()) {
      if (savings.goalId == id) {
        savings.goalId = null;
        await savingsGoalsRepo.update(savings);
      }
    }
    for (final note in notesRepo.getAll(includeArchived: true)) {
      if (note.linkedEntityType == 'goal' && note.linkedEntityId == id) {
        await notesRepo.update(note.copyWith(clearLinkedEntity: true));
      }
    }
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

  Future<void> updateJournal(JournalEntry entry) async {
    await journalRepo.update(entry);
    notifyListeners();
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

  Future<void> updateNote(Note note) async {
    await notesRepo.update(note);
    notifyListeners();
  }

  Future<void> toggleNotePinned(String id) async {
    final note = notesRepo.getAll(includeArchived: true).where((n) => n.id == id).firstOrNull;
    if (note == null) return;
    await notesRepo.setPinned(note, !note.isPinned);
    notifyListeners();
  }

  Future<void> archiveNote(String id, {bool archived = true}) async {
    final note = notesRepo.getAll(includeArchived: true).where((n) => n.id == id).firstOrNull;
    if (note == null) return;
    await notesRepo.setArchived(note, archived);
    notifyListeners();
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
      final entry = await financeRepo.create(
        title: title, amount: amount, typeIndex: typeIndex, categoryIndex: categoryIndex, date: date, note: note, goalId: goalId, plannedAmount: plannedAmount,
      );
      if (goalId != null) {
        await _syncGoalReverseLink(newGoalId: goalId, entityId: entry.id, kind: 'finance');
        await syncGoalProgress(goalId);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateFinance(FinanceEntry entry) async {
    final old = financeRepo.getAll().where((e) => e.id == entry.id).firstOrNull;
    await financeRepo.update(entry);
    await _syncGoalReverseLink(oldGoalId: old?.goalId ?? old?.linkedGoalId, newGoalId: entry.goalId, entityId: entry.id, kind: 'finance');
    final ids = {
      if (old?.goalId != null) old!.goalId!,
      if (old?.linkedGoalId != null) old!.linkedGoalId!,
      if (entry.goalId != null) entry.goalId!,
      if (entry.linkedGoalId != null) entry.linkedGoalId!,
    };
    for (final goalId in ids) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  Future<void> deleteFinance(String id) async {
    final entry =
        financeRepo.getAll().where((item) => item.id == id).firstOrNull;
    for (final note in notesRepo.getAll(includeArchived: true)) {
      if (note.linkedEntityType == 'finance' && note.linkedEntityId == id) {
        await notesRepo.update(note.copyWith(clearLinkedEntity: true));
      }
    }
    await financeRepo.delete(id);
    await _removeGoalReverseReferences(financeId: id);
    final linkedGoalIds = {
      if (entry?.goalId != null) entry!.goalId!,
      if (entry?.linkedGoalId != null) entry!.linkedGoalId!,
    };
    for (final goalId in linkedGoalIds) {
      await syncGoalProgress(goalId);
    }
    notifyListeners();
  }

  /// Recalculates goal progress from its canonical linked entities.
  Future<void> syncGoal(String goalId) async {
    await syncGoalProgress(goalId);
  }

  /// Resolves the habits that belong to [goal].
  ///
  /// The canonical owner is `Habit.goalId`. A habit whose canonical field points
  /// at a *different* goal is never included, even if a stale legacy reverse
  /// link still names it — that is what previously let one habit count toward
  /// several goals. The legacy `linkedGoalId` / `linkedHabitIds` fallbacks are
  /// only consulted for habits that have no canonical owner yet (old Hive data).
  List<Habit> habitsForGoal(Goal goal) => habitsRepo.getAll().where((h) {
        if (h.goalId != null) return h.goalId == goal.id;
        if (h.linkedGoalId != null) return h.linkedGoalId == goal.id;
        return goal.linkedHabitIds.contains(h.id);
      }).toList();

  /// Resolves the tasks that belong to [goal]. See [habitsForGoal].
  List<Task> tasksForGoal(Goal goal) =>
      tasksRepo.getAll(includeArchived: true).where((t) {
        if (t.goalId != null) return t.goalId == goal.id;
        if (t.linkedGoalId != null) return t.linkedGoalId == goal.id;
        return goal.linkedTaskIds.contains(t.id);
      }).toList();

  /// Recalculates goal progress from its canonical linked entities.
  Future<void> syncGoalProgress(String goalId) async {
    final goal = goalsRepo.getAll(includeArchived: true).where((g) => g.id == goalId).firstOrNull;
    if (goal == null || !goal.isAutoProgress) return;
    final habits = habitsForGoal(goal);
    final tasks = tasksForGoal(goal);
    final finance = financeRepo.getForGoal(goalId);
    final savings = savingsGoalsRepo.getForGoal(goalId);
    final snapshot = GoalProgressEngine.compute(
      goal: goal, habits: habits, tasks: tasks, finance: finance, savings: savings);
    goal.currentValue = snapshot.currentUnits.clamp(0.0, goal.targetValue).toDouble();
    goal.progressPercent = snapshot.fraction * 100;
    final allMilestonesDone = goal.milestoneDone.isNotEmpty &&
        goal.milestoneDone.every((d) => d);
    goal.completed =
        (goal.targetValue > 0 && snapshot.fraction >= 1.0) || allMilestonesDone;
    goal.touch();
    await goalsRepo.update(goal);
  }

  double computeGoalProgress(String goalId) {
    final goal = goalsRepo.getAll(includeArchived: true).where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return 0;
    final snapshot = GoalProgressEngine.compute(
      goal: goal,
      habits: habitsForGoal(goal),
      tasks: tasksForGoal(goal),
      finance: financeRepo.getForGoal(goalId),
      savings: savingsGoalsRepo.getForGoal(goalId),
    );
    return snapshot.fraction;
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

  /// Confirms today's savings contribution. Returns false when the
  /// contribution was rejected (already confirmed, or outside the window).
  Future<bool> confirmSavingsContribution(String id, {DateTime? date}) async {
    final sg = savingsGoalsRepo.getById(id);
    if (sg == null) return false;
    final ok = await savingsGoalsRepo.confirmContribution(sg, date: date);
    if (ok && sg.goalId != null) await syncGoalProgress(sg.goalId!);
    notifyListeners();
    return ok;
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
    for (final note in notesRepo.getAll(includeArchived: true)) {
      if (note.linkedEntityType == 'finance' && note.linkedEntityId == id) {
        await notesRepo.update(note.copyWith(clearLinkedEntity: true));
      }
    }
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
      notifyListeners();
      unawaited(notificationService.scheduleItem(item).catchError((_) {}));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateSchedule(ScheduleItem item) async {
    await scheduleRepo.update(item);
    notifyListeners();
    unawaited(notificationService.scheduleItem(item).catchError((_) {}));
  }

  Future<void> toggleSchedule(String id) async {
    final s = scheduleRepo.getAll().where((s) => s.id == id).firstOrNull;
    if (s == null) return;
    await scheduleRepo.toggle(s);
    final updated = scheduleRepo.getAll().where((x) => x.id == id).firstOrNull;
    notifyListeners();
    if (updated != null) {
      unawaited(notificationService.scheduleItem(updated).catchError((_) {}));
    }
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
      'version': 7,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    // settings — includes dashboardConfig
    final s = settings;
    data['settings'] = {
      'userName': s.userName,
      'themeMode': s.themeMode.name,
      'onboardingComplete': s.onboardingComplete,
      'dashboardConfig': s.dashboardConfig.toMap(),
      'profileEmoji': s.profileEmoji,
      'profileBio': s.profileBio,
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
              'reminders': h.reminders.map(_reminderToJson).toList(),
            })
        .toList();

    data['taskCategories'] = taskCategoriesRepo.getAll().map((c) => {
          'id': c.id,
          'name': c.name,
          'colorValue': c.colorValue,
          'iconCodePoint': c.iconCodePoint,
          'iconFontFamily': c.iconFontFamily,
          'iconFontPackage': c.iconFontPackage,
          'createdAt': c.createdAt.toIso8601String(),
          'updatedAt': c.updatedAt.toIso8601String(),
        }).toList();

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
              'recurrenceSeriesId': t.recurrenceSeriesId,
              'customCategoryId': t.customCategoryId,
              'reminders': t.reminders.map(_reminderToJson).toList(),
              'recurrenceRule': t.recurrenceRule == null ? null : {
                'type': t.recurrenceRule!.type.name,
                'interval': t.recurrenceRule!.interval,
                'intervalUnit': t.recurrenceRule!.intervalUnit.name,
                'weekdays': t.recurrenceRule!.weekdays,
                'monthDays': t.recurrenceRule!.monthDays,
                'month': t.recurrenceRule!.month,
                'dayOfMonth': t.recurrenceRule!.dayOfMonth,
                'nthWeekday': t.recurrenceRule!.nthWeekday,
                'nthWeekdayDay': t.recurrenceRule!.nthWeekdayDay,
                'period': t.recurrenceRule!.period?.name,
                'occurrencesPerPeriod': t.recurrenceRule!.occurrencesPerPeriod,
                'activeDays': t.recurrenceRule!.activeDays,
                'restDays': t.recurrenceRule!.restDays,
                'flexible': t.recurrenceRule!.flexible,
                'startDate': t.recurrenceRule!.startDate?.toIso8601String(),
                'endDate': t.recurrenceRule!.endDate?.toIso8601String(),
              },
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
              'progressMode': g.progressMode.name,
              'startDate': g.startDate.toIso8601String(),
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
        .getAll(includeArchived: true)
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
              'isPinned': n.isPinned,
              'isArchived': n.isArchived,
              'updatedAt': n.updatedAt.toIso8601String(),
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
  /// Validates the shape of a decoded backup without touching stored data.
  ///
  /// Throws a [FormatException] with a user-facing message when the map is not
  /// a compatible Yourself backup. Call this before showing the destructive
  /// restore confirmation so the dialog never implies that arbitrary valid
  /// JSON is a valid backup.
  static void validateBackup(Map<String, dynamic> data) {
    if (data['format'] != 'yourself-backup') {
      throw const FormatException(
          'This file is not a Yourself backup (missing "yourself-backup" marker).');
    }
    if (data['version'] is! num) {
      throw const FormatException('Backup is missing a version number.');
    }
    final version = (data['version'] as num).toInt();
    if (version < 1 || version > 7) {
      throw FormatException('Unsupported backup version: $version.');
    }
    for (final key in ['habits', 'tasks', 'goals', 'notes', 'finance']) {
      if (data[key] is! List) {
        throw FormatException('Backup is missing the $key collection.');
      }
      // Every record must be a JSON object with a string id.
      for (final raw in data[key] as List) {
        if (raw is! Map) {
          throw FormatException('Backup contains a malformed $key record.');
        }
        if (raw['id'] is! String || (raw['id'] as String).isEmpty) {
          throw FormatException('A $key record is missing its id.');
        }
      }
    }
    // Optional collections may be absent (v1–v3 backups), but when present they
    // must still be well-formed lists of objects.
    for (final key in [
      'savingsGoals',
      'journal',
      'schedule',
      'quotes',
      'focusSessions',
      'taskCategories',
    ]) {
      final value = data[key];
      if (value == null) continue;
      if (value is! List) {
        throw FormatException('Backup has a malformed $key collection.');
      }
      for (final raw in value) {
        if (raw is! Map) {
          throw FormatException('Backup contains a malformed $key record.');
        }
      }
    }
    if (data['settings'] != null && data['settings'] is! Map) {
      throw const FormatException('Backup has malformed settings.');
    }
    if (data['financeBudget'] != null && data['financeBudget'] is! Map) {
      throw const FormatException('Backup has a malformed finance budget.');
    }
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    validateBackup(data);
    // Optional collections are only replaced when present. This keeps older
    // v1-v3 backups from silently deleting data introduced in newer versions.
    final hasSavings = data['savingsGoals'] is List;
    final hasJournal = data['journal'] is List;
    final hasSchedule = data['schedule'] is List;
    final hasQuotes = data['quotes'] is List;
    final hasFocus = data['focusSessions'] is List;
    final hasTaskCategories = data['taskCategories'] is List;

    // ── Parse ALL collections into local lists FIRST ──
    // If any parse fails, we throw before touching existing data.

    final goals = <Goal>[];
    for (final raw in data['goals'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final milestones = (item['milestones'] as List? ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      final categoryIndex = GoalCategory.values.indexWhere((value) => value.name == item['category']);
      goals.add(Goal(
        id: item['id'] as String,
        title: item['title'] as String,
        description: item['description'] as String? ?? '',
        categoryIndex: categoryIndex >= 0 ? categoryIndex : GoalCategory.personal.index,
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
        progressMode: GoalProgressMode.values.firstWhere((m) => m.name == (item['progressMode'] as String? ?? 'auto'), orElse: () => GoalProgressMode.auto),
        startDate: _date(item['startDate']),
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
        goalId: (item['goalId'] as String?) ?? (item['linkedGoalId'] as String?),
        linkedGoalId: null,
        reminders: _remindersFromJson(item['reminders']),
      ));
    }

    final taskCategories = <TaskCategoryModel>[];
    final importedTaskCategories = data['taskCategories'];
    if (importedTaskCategories is List) {
      for (final raw in importedTaskCategories) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id'] as String?;
        final name = item['name'] as String?;
        if (id == null || name == null || id.isEmpty || name.trim().isEmpty) {
          throw const FormatException('Backup contains a malformed task category.');
        }
        taskCategories.add(TaskCategoryModel(
          id: id,
          name: name.trim(),
          colorValue: item['colorValue'] as int? ?? 0xFF6B9080,
          iconCodePoint: item['iconCodePoint'] as int? ?? Icons.category.codePoint,
          iconFontFamily: item['iconFontFamily'] as String? ?? 'MaterialIcons',
          iconFontPackage: item['iconFontPackage'] as String?,
          createdAt: item['createdAt'] == null ? null : DateTime.tryParse(item['createdAt'] as String),
          updatedAt: item['updatedAt'] == null ? null : DateTime.tryParse(item['updatedAt'] as String),
        ));
      }
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
        goalId: (item['goalId'] as String?) ?? (item['linkedGoalId'] as String?),
        habitId: item['habitId'] as String?,
        linkedGoalId: null,
        linkedHabitId: item['linkedHabitId'] as String?,
        recurrenceSeriesId: item['recurrenceSeriesId'] as String?,
        customCategoryId: item['customCategoryId'] as String?,
        recurrenceRule: _recurrenceRuleFromJson(item['recurrenceRule']),
        reminders: _remindersFromJson(item['reminders']),
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
        isPinned: item['isPinned'] as bool? ?? false,
        archived: item['isArchived'] as bool? ?? false,
        updatedAt: _date(item['updatedAt']),
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
        goalId: (item['goalId'] as String?) ?? (item['linkedGoalId'] as String?),
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
        // Contribution arrays can be malformed in hand-edited or older
        // backups. Parse defensively, then normalize so the date/amount lists
        // are always the same length with no duplicate days.
        final rawDates = (item['contributionDates'] as List? ?? [])
            .map((v) => v is String ? DateTime.tryParse(v) : null)
            .whereType<DateTime>()
            .toList();
        final rawAmounts = (item['contributionAmounts'] as List? ?? [])
            .whereType<num>()
            .map((v) => v.toDouble())
            .toList();
        final pairs =
            rawDates.length < rawAmounts.length ? rawDates.length : rawAmounts.length;
        final imported = SavingsGoal(
          id: item['id'] as String,
          title: item['title'] as String,
          targetAmount: (item['targetAmount'] as num?)?.toDouble() ?? 0,
          targetDays: (item['targetDays'] as num?)?.toInt() ?? 0,
          startDate: _date(item['startDate']) ?? DateTime.now(),
          contributionDates: rawDates.sublist(0, pairs),
          contributionAmounts: rawAmounts.sublist(0, pairs),
          goalId: item['goalId'] as String?,
          createdAt: _date(item['createdAt']) ?? DateTime.now(),
          updatedAt: _date(item['updatedAt']),
        );
        imported.normalizeContributions();
        savingsGoals.add(imported);
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
        profileEmoji: sMap['profileEmoji'] as String? ?? '🙂',
        profileBio: sMap['profileBio'] as String? ?? '',
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

    // ══ ALL PARSING SUCCEEDED — now safe to replace data ══
    // Hive does not provide a cross-box transaction, so keep an in-memory
    // rollback snapshot. If any write fails, restore the exact previous
    // contents instead of leaving the database partially imported.
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
    final taskCategoryBox = Hive.box<TaskCategoryModel>(HiveBoxes.taskCategories);

    final oldGoals = Map<dynamic, Goal>.from(goalBox.toMap());
    final oldHabits = Map<dynamic, Habit>.from(habitBox.toMap());
    final oldTasks = Map<dynamic, Task>.from(taskBox.toMap());
    final oldNotes = Map<dynamic, Note>.from(noteBox.toMap());
    final oldFinance = Map<dynamic, FinanceEntry>.from(financeBox.toMap());
    final oldSavings = Map<dynamic, SavingsGoal>.from(savingsBox.toMap());
    final oldJournal = Map<dynamic, JournalEntry>.from(journalBox.toMap());
    final oldSchedule = Map<dynamic, ScheduleItem>.from(scheduleBox.toMap());
    final oldQuotes = Map<dynamic, Quote>.from(quotesBox.toMap());
    final oldFocus = Map<dynamic, FocusSession>.from(focusBox.toMap());
    final oldSettings = Map<dynamic, UserSettings>.from(settingsBox.toMap());
    final oldBudget = Map<dynamic, FinanceBudget>.from(budgetBox.toMap());
    final oldTaskCategories = Map<dynamic, TaskCategoryModel>.from(taskCategoryBox.toMap());

    Future<void> clearAll() async {
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
        settingsBox.clear(),
        budgetBox.clear(),
        taskCategoryBox.clear(),
      ]);
    }

    Future<void> restoreSnapshot() async {
      await clearAll();
      await goalBox.putAll(oldGoals);
      await habitBox.putAll(oldHabits);
      await taskBox.putAll(oldTasks);
      await noteBox.putAll(oldNotes);
      await financeBox.putAll(oldFinance);
      await savingsBox.putAll(oldSavings);
      await journalBox.putAll(oldJournal);
      await scheduleBox.putAll(oldSchedule);
      await quotesBox.putAll(oldQuotes);
      await focusBox.putAll(oldFocus);
      await settingsBox.putAll(oldSettings);
      await budgetBox.putAll(oldBudget);
      await taskCategoryBox.putAll(oldTaskCategories);
    }

    try {
      // Required collections are always replaced. Optional collections are
      // replaced only when present so old backups don't erase newer data.
      await Future.wait([
        goalBox.clear(),
        habitBox.clear(),
        taskBox.clear(),
        noteBox.clear(),
        financeBox.clear(),
      ]);
      if (hasSavings) await savingsBox.clear();
      if (hasJournal) await journalBox.clear();
      if (hasSchedule) await scheduleBox.clear();
      if (hasQuotes) await quotesBox.clear();
      if (hasFocus) await focusBox.clear();
      if (hasTaskCategories) await taskCategoryBox.clear();

      await goalBox.putAll({for (final item in goals) item.id: item});
      await habitBox.putAll({for (final item in habits) item.id: item});
      await taskBox.putAll({for (final item in tasks) item.id: item});
      await noteBox.putAll({for (final item in notes) item.id: item});
      await financeBox.putAll({for (final item in finance) item.id: item});
      if (hasSavings) {
        await savingsBox.putAll({for (final item in savingsGoals) item.id: item});
      }
      if (hasJournal) {
        await journalBox.putAll({for (final item in journal) item.id: item});
      }
      if (hasSchedule) {
        await scheduleBox.putAll({for (final item in schedule) item.id: item});
      }
      if (hasQuotes) {
        await quotesBox.putAll({for (final item in quotes) item.id: item});
      }
      if (hasFocus) {
        await focusBox.putAll({for (final item in focusSessions) item.id: item});
      }
      if (hasTaskCategories) {
        await taskCategoryBox.putAll({for (final item in taskCategories) item.id: item});
      }

      if (newSettings != null) {
        await settingsBox.put(HiveBoxes.settingsKey, newSettings);
      }
      if (newBudget != null) {
        await budgetBox.put('budget', newBudget);
      }

      // Rebuild goal reverse links from canonical children after import.
      // Stale linkedHabitIds/linkedTaskIds/linkedFinanceId from the backup
      // are replaced with the actual IDs of imported entities whose goalId
      // or linkedGoalId points to this goal.
      for (final goal in goals) {
        final habitIds = habits
            .where((h) => h.goalId == goal.id || h.linkedGoalId == goal.id)
            .map((h) => h.id)
            .toList();
        final taskIds = tasks
            .where((t) => t.goalId == goal.id || t.linkedGoalId == goal.id)
            .map((t) => t.id)
            .toList();
        final financeId = finance
            .where((f) => f.goalId == goal.id || f.linkedGoalId == goal.id)
            .map((f) => f.id)
            .toList();
        final storedGoal = goalBox.get(goal.id);
        if (storedGoal != null) {
          storedGoal.linkedHabitIds = habitIds;
          storedGoal.linkedTaskIds = taskIds;
          storedGoal.linkedFinanceId = financeId.isEmpty ? null : financeId.first;
          storedGoal.touch();
          await goalBox.put(storedGoal.id, storedGoal);
        }
      }

      // Re-sync goal progress for auto goals after import.
      for (final g in goals) {
        if (g.isAutoProgress) await syncGoalProgress(g.id);
      }
    } catch (_) {
      await restoreSnapshot();
      rethrow;
    }

    // Rebuild the notification schedule from the imported data. Notifications
    // scheduled for pre-import tasks/schedule items are cancelled by
    // refreshAll(), which cancels every pending ID that is no longer active.
    // Never let a notification/permission failure fail an otherwise
    // successful restore.
    try {
      await notificationService.refreshAll(
        tasks: tasksRepo.getAll(includeArchived: true),
        habits: habitsRepo.getAll(),
        schedule: scheduleRepo.getAll(),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Notification refresh after import failed: $error');
      }
    }

    notifyListeners();
  }

  Map<String, dynamic> _reminderToJson(ReminderRule reminder) => {
        'id': reminder.id,
        'enabled': reminder.enabled,
        'hour': reminder.hour,
        'minute': reminder.minute,
        'minutesBeforeDue': reminder.minutesBeforeDue,
        'weekdays': reminder.weekdays,
      };

  List<ReminderRule> _remindersFromJson(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((value) {
      final map = Map<String, dynamic>.from(value);
      return ReminderRule(
        id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        enabled: map['enabled'] as bool? ?? true,
        hour: ((map['hour'] as num?)?.toInt() ?? 9).clamp(0, 23),
        minute: ((map['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
        minutesBeforeDue: ((map['minutesBeforeDue'] as num?)?.toInt() ?? 0).clamp(0, 10080),
        weekdays: (map['weekdays'] as List?)?.whereType<int>().toList() ?? const [],
      );
    }).toList();
  }

  RecurrenceRule? _recurrenceRuleFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    RecurrenceType? type;
    try { type = RecurrenceType.values.firstWhere((e) => e.name == map['type']); } catch (_) {}
    if (type == null) return null;
    RecurrenceIntervalUnit? unit;
    try { unit = RecurrenceIntervalUnit.values.firstWhere((e) => e.name == map['intervalUnit']); } catch (_) {}
    RecurrencePeriod? period;
    try { period = map['period'] == null ? null : RecurrencePeriod.values.firstWhere((e) => e.name == map['period']); } catch (_) {}
    DateTime? parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    return RecurrenceRule(
      type: type,
      interval: map['interval'] as int? ?? 1,
      intervalUnit: unit ?? RecurrenceIntervalUnit.days,
      weekdays: (map['weekdays'] as List?)?.whereType<int>().toList() ?? const [],
      monthDays: (map['monthDays'] as List?)?.whereType<int>().toList() ?? const [],
      month: map['month'] as int?,
      dayOfMonth: map['dayOfMonth'] as int?,
      nthWeekday: map['nthWeekday'] as int?,
      nthWeekdayDay: map['nthWeekdayDay'] as int?,
      period: period,
      occurrencesPerPeriod: map['occurrencesPerPeriod'] as int?,
      activeDays: map['activeDays'] as int? ?? 1,
      restDays: map['restDays'] as int? ?? 1,
      flexible: map['flexible'] as bool? ?? false,
      startDate: parse(map['startDate']),
      endDate: parse(map['endDate']),
    );
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
