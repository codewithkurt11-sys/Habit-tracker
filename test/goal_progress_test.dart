import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/data/models/goal.dart';

void main() {
  group('Goal progressFraction', () {
    test('zero target returns 0', () {
      final goal = Goal(
        id: 'g1',
        title: 'Test',
        targetValue: 0,
        currentValue: 50,
      );
      expect(goal.progressFraction, 0);
    });

    test('negative target returns 0', () {
      final goal = Goal(
        id: 'g2',
        title: 'Test',
        targetValue: -10,
        currentValue: 50,
      );
      expect(goal.progressFraction, 0);
    });

    test('normal progress', () {
      final goal = Goal(
        id: 'g3',
        title: 'Test',
        targetValue: 100,
        currentValue: 50,
      );
      expect(goal.progressFraction, 0.5);
    });

    test('progress clamped to 1.0', () {
      final goal = Goal(
        id: 'g4',
        title: 'Test',
        targetValue: 100,
        currentValue: 150,
      );
      expect(goal.progressFraction, 1.0);
    });

    test('progress clamped to 0.0 for negative current', () {
      final goal = Goal(
        id: 'g5',
        title: 'Test',
        targetValue: 100,
        currentValue: -10,
      );
      expect(goal.progressFraction, 0.0);
    });
  });

  group('Goal milestones', () {
    test('milestones list generated correctly', () {
      final goal = Goal(
        id: 'g6',
        title: 'Test',
        milestoneTitles: ['Step 1', 'Step 2', 'Step 3'],
        milestoneDone: [true, false, true],
      );
      final milestones = goal.milestones;
      expect(milestones.length, 3);
      expect(milestones[0].completed, true);
      expect(milestones[1].completed, false);
      expect(milestones[2].completed, true);
    });

    test('empty milestones returns empty list', () {
      final goal = Goal(
        id: 'g7',
        title: 'Test',
      );
      expect(goal.milestones, isEmpty);
    });
  });

  group('Goal daysLeft', () {
    test('null deadline returns -1', () {
      final goal = Goal(
        id: 'g8',
        title: 'Test',
      );
      expect(goal.daysLeft, -1);
    });

    test('future deadline returns positive days', () {
      final future = DateTime.now().add(const Duration(days: 10));
      final goal = Goal(
        id: 'g9',
        title: 'Test',
        deadline: future,
      );
      expect(goal.daysLeft, 10);
    });

    test('past deadline returns negative days', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final goal = Goal(
        id: 'g10',
        title: 'Test',
        deadline: past,
      );
      expect(goal.daysLeft, -5);
    });
  });

  group('Goal category and color', () {
    test('category index maps to correct GoalCategory', () {
      final goal = Goal(
        id: 'g11',
        title: 'Test',
        categoryIndex: 0, // health
      );
      expect(goal.category, GoalCategory.health);
    });

    test('color is derived from colorValue', () {
      final goal = Goal(
        id: 'g12',
        title: 'Test',
        colorValue: 0xFF6B9080,
      );
      expect(goal.color, const Color(0xFF6B9080));
    });

    test('category index is clamped to valid range', () {
      final goal = Goal(
        id: 'g13',
        title: 'Test',
        categoryIndex: 999, // out of bounds
      );
      // Should clamp to last index
      expect(goal.category, GoalCategory.values.last);
    });
  });
}
