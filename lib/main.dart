import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'data/hive_boxes.dart';
import 'firebase_options.dart';
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
    developer.log('LOCAL INIT ✓ Hive initialized', name: 'Yourself.Startup');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log(
      'STEP 1 ✓ Firebase initialized: ${Firebase.app().options.projectId}',
      name: 'Yourself.Auth',
    );

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
        state.initSync();
        state.initNotifications();
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
