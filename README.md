# Yourself

Yourself is a fully local-first, offline-only habit tracker and personal productivity app. Habits, tasks, goals, schedules, journal entries, notes, finance records, focus sessions, settings, and statistics are stored only on-device in Hive.

## Privacy and storage

- No account or sign-in is required.
- No cloud services, social features, analytics, or network synchronization are used.
- The Android app does not request internet access.
- Data can be backed up manually with the in-app JSON export tools.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Changelog

### Offline-only refactor and quality pass

- Removed all former online services, account access, connectivity monitoring, synchronization, and social functionality.
- Removed remote-service configuration, service Gradle setup, the custom CI signing key, and Android internet permissions.
- Restored Hive as the sole source of truth for every retained feature.
- Fixed task subtask completion so reopening a subtask also reopens the task and clears its completion timestamp.
- Fixed goal completion state when progress is reduced or a milestone is reopened; completion now reflects either the target or all milestones.
- Fixed goal deadline day counts by comparing normalized local calendar dates.
- Made habit, statistics, and heatmap date traversal calendar-based to avoid daylight-saving and midnight boundary errors.
- Fixed daily habit completion rates so only habits due on that day contribute to the rate.
- Fixed focus totals so leftover seconds across sessions are accumulated before converting to minutes.
- Added confirmations before deleting tasks and goals, including from the Kanban board.
- Added working actions and clearer copy to empty states for habits, tasks, and goals.
- Removed Friends navigation and account/cloud settings while preserving the existing theme and visual identity.
