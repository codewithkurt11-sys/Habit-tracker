import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/hive_boxes.dart';
import 'logic/app_state.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'UNCAUGHT FLUTTER ERROR: ${details.exceptionAsString()}',
      name: 'Yourself.Global',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      'UNCAUGHT PLATFORM ERROR: $error',
      name: 'Yourself.Global',
      error: error,
      stackTrace: stack,
    );
    return false;
  };

  await runZonedGuarded(() async {
    await HiveInitializer.init();
    developer.log('LOCAL INIT: Hive initialized', name: 'Yourself.Startup');
    runApp(const HabitTrackerApp());
  }, (error, stack) {
    developer.log(
      'UNCAUGHT ZONE ERROR: $error',
      name: 'Yourself.Global',
      error: error,
      stackTrace: stack,
    );
  });
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final state = AppState();
        state.seedQuotes();
        // These two startup steps are intentionally independent: recurring
        // task catch-up must never prevent the notification schedule from
        // being rebuilt (and vice versa). Previously they were chained with
        // .then(), so a thrown error in processRecurringTasks() silently
        // skipped initNotifications() entirely on that launch, leaving
        // stale/cancelled notifications un-cleaned and new reminders
        // unscheduled until the next successful restart.
        unawaited(state.processRecurringTasks().catchError((error) {
          if (kDebugMode) {
            debugPrint('processRecurringTasks failed on startup: $error');
          }
        }));
        unawaited(state.initNotifications().catchError((error) {
          if (kDebugMode) {
            debugPrint('initNotifications failed on startup: $error');
          }
        }));
        return state;
      },
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Yourself',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.values[state.settings.themeMode.index],
            home: state.onboardingComplete
                ? const AppShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
