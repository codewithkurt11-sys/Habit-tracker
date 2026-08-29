import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/logic/stats_engine.dart';

void main() {
  group('StatsEngine.heatMap weekday alignment', () {
    test('first cell is a Monday and last cell is a Sunday', () {
      final cells = StatsEngine.heatMap(const [], 84);
      expect(cells.first.date.weekday, DateTime.monday);
      expect(cells.last.date.weekday, DateTime.sunday);
    });

    test('grid is a whole number of Mon-Sun weeks', () {
      final cells = StatsEngine.heatMap(const [], 84);
      expect(cells.length % 7, 0);
      expect(cells.length, 84); // 12 weeks
    });

    test('every row index maps to a single fixed weekday', () {
      // The UI renders columns of 7 with row 0 = Mon .. row 6 = Sun.
      final cells = StatsEngine.heatMap(const [], 84);
      const expectedWeekdays = [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ];
      for (var i = 0; i < cells.length; i++) {
        expect(
          cells[i].date.weekday,
          expectedWeekdays[i % 7],
          reason: 'cell $i (row ${i % 7}) has the wrong weekday',
        );
      }
    });

    test('dates are strictly consecutive with no gaps', () {
      final cells = StatsEngine.heatMap(const [], 28);
      for (var i = 1; i < cells.length; i++) {
        expect(
          cells[i].date.difference(cells[i - 1].date).inDays,
          1,
          reason: 'gap before cell $i',
        );
      }
    });

    test('the current week is the last column', () {
      final cells = StatsEngine.heatMap(const [], 84);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastWeek = cells.sublist(cells.length - 7);
      expect(
        lastWeek.any((c) => c.date == today),
        isTrue,
        reason: 'today must appear in the final Mon-Sun column',
      );
    });

    test('requesting a non multiple of 7 rounds up to whole weeks', () {
      final cells = StatsEngine.heatMap(const [], 30);
      expect(cells.length, 35); // ceil(30/7) == 5 weeks
      expect(cells.first.date.weekday, DateTime.monday);
      expect(cells.last.date.weekday, DateTime.sunday);
    });
  });
}
