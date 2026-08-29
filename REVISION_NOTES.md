# Yourself v2 — stability / integration revision

Build: `2.0.0+5`

## Major fixes

### Navigation / UX
- Bottom navigation is now exactly **Home · Habits · Quick Action · Tasks · Finance**.
- Focus moved to the sidebar.
- Center Quick Action is the only global action button and closes on selection, outside tap, navigation changes, and sidebar navigation.
- Restored contextual Add buttons for Habits, Tasks and Finance; Focus has a sidebar Add action.
- Added consistent edit entry points to major modules.
- Replaced the generic goal list navigation with a dedicated Goal Detail screen.

### Goal / linking system
- Added `GoalProgressMode` and `startDate` while keeping Hive backward compatibility.
- Habit-linked goals now count **unique completed scheduled days**, not a rolling 30-day percentage. A 100-day push-up goal therefore moves 0 → 1% after one completed day instead of incorrectly becoming 100%.
- Task-linked goals count completed linked task occurrences, including recurring-task history.
- Finance-linked goals count linked income / savings contributions.
- Goal completion only occurs when the configured target is actually reached.
- Added goal statistics: completed, skipped, missed, remaining, progress type, start/deadline and calendar history.
- Added Ongoing / Completed goal tabs.
- Goals can edit title, description, category, target, dates, progress mode, connected habits, connected tasks and connected finance.
- Goal editing normalizes legacy `goalId` / `linkedGoalId` relationships into the canonical relationship.
- Habit, Task and Finance editors can now change their goal connections.
- Connected items in Goal Detail are navigable/editable.
- Goal deletion clears child references and linked notes.

### Tasks / scheduling
- Task checkbox persistence now updates UI before notification scheduling; notification work no longer blocks the visual state.
- Schedule completion has the same non-blocking behavior.
- Recurring tasks now generate the next occurrence when completed through the normal checkbox path.
- Recurring tasks now use `recurrenceSeriesId` to avoid same-title collisions.
- Subtask completion can also advance recurring tasks.
- Added task editing, due time, recurrence pattern and tags.

### Notes / Journal
- Notes now support pinning and archiving.
- Notes search/folders remain available with an active/archive view.
- Note links now open the exact goal/habit/task/finance target rather than a generic module screen.
- Fixed the misleading Finance/Savings link mapping.
- Added file picker support for note attachments.
- Journal now supports search, favorite filtering and the full edit flow.

### Analytics
- Added task completion rate, consistency score, goal outcome rate, focus, journal and note metrics.
- Added a central `StatsEngine` habit window snapshot for due/completed/skipped/missed values.
- Goal progress no longer uses the old misleading rolling-rate calculation for habit-day goals.

### Profile / Settings
- Profile now supports an emoji avatar and short bio.
- Added dashboard section controls to Settings.
- Backup & Export is now accessed from Settings rather than the sidebar.
- Settings keeps notification permission controls and data backup access.

### Branding
- Applied the supplied Yourself logo to onboarding branding.
- Updated Android/iOS launcher icon assets using the supplied Yourself emblem.

### Permissions / notifications
- Added Android `MANAGE_EXTERNAL_STORAGE` declaration for the File Manager's explicit broad-storage mode.
- Notification permission handling is now platform-aware.
- Task/schedule notification scheduling is intentionally non-blocking for UI state changes.

### Backup compatibility
- Backup format is now version `5`.
- Added Goal progress mode/start date, Task recurrence series ID, Note pin/archive/update metadata and Profile fields to export/import.
- Older backups remain readable with defaults for new fields.
- Existing rollback protection remains in place for destructive imports.

## Verification

Flutter/Dart is not installed in the execution container, so `flutter analyze`, `flutter test` and APK compilation cannot be truthfully reported as locally executed. The repository CI workflow runs dependency resolution, analysis, tests and debug APK compilation.

Static checks performed in this environment include source inspection, stale-symbol checks, duplicate-import checks, adapter-field review and modified-code consistency checks.

### Additional pass after user-reported issues
- Goal engine now supports `mixed` progress mode when a goal intentionally combines habits, tasks and finance/savings sources.
- Task goal completions are constrained to the goal start/deadline window.
- Finance/savings goal contributions are constrained to the goal window.
- Goal progress displayed by Dashboard and Analytics is computed from the live goal engine rather than cached `progressFraction`.
- Goal reverse links are synchronized when creating/updating habits, tasks and finance entries.
- Recurring task occurrences are added back into goal reverse links.
- Connected tasks are visible from Habit Detail.
- Schedule items now have immediate checkbox updates and an edit dialog.
- Empty Kanban/Schedule/Focus states now have working actions.
- Profile and Settings have clearer internal headers.
