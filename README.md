# Yourself

A local-first habit, task, schedule, focus, and personal organization app with optional cloud sync and friend visibility.

## Firebase indexes

The incoming friend-request query requires the composite index in `firestore.indexes.json`. Deploy it before using cloud friend requests:

```bash
firebase deploy --only firestore:indexes
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
