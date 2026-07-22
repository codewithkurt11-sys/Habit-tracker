import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/focus_session.dart';

class FocusRepository {
  Box<FocusSession> get _box => Hive.box<FocusSession>(HiveBoxes.focus);
  final _uuid = const Uuid();

  List<FocusSession> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<FocusSession> getCompleted() => getAll().where((s) => s.completed).toList();

  List<FocusSession> getForDate(DateTime date) =>
      getAll().where((s) =>
        s.startedAt.year == date.year &&
        s.startedAt.month == date.month &&
        s.startedAt.day == date.day
      ).toList();

  int getTotalFocusMinutesToday() {
    final today = DateTime.now();
    return getForDate(today).fold(0, (sum, s) => sum + s.completedSeconds ~/ 60);
  }

  int getTotalFocusMinutesThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return getAll()
        .where((s) => s.startedAt.isAfter(start))
        .fold(0, (sum, s) => sum + s.completedSeconds ~/ 60);
  }

  int getCompletedPomodorosToday() {
    final today = DateTime.now();
    return getForDate(today)
        .where((s) => s.type == FocusType.pomodoro && s.completed)
        .length;
  }

  Future<FocusSession> startSession({
    required int typeIndex,
    required int durationSeconds,
    String? taskTitle,
  }) async {
    final session = FocusSession(
      id: _uuid.v4(),
      typeIndex: typeIndex,
      durationSeconds: durationSeconds,
      startedAt: DateTime.now(),
      taskTitle: taskTitle,
    );
    await _box.put(session.id, session);
    return session;
  }

  Future<void> completeSession(FocusSession session, int completedSeconds) async {
    session.completedSeconds = completedSeconds;
    session.completed = completedSeconds >= session.durationSeconds * 0.8;
    await _box.put(session.id, session);
  }

  Future<void> delete(String id) async => _box.delete(id);
}
