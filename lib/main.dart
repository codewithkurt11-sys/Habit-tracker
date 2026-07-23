import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'data/hive_boxes.dart';
import 'firebase_options.dart';
import 'logic/app_state.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();

  // Firebase init MUST be wrapped in try/catch — a missing/broken config
  // must degrade to offline-only, never crash app startup.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('Firebase initialized successfully.');
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init failed — offline-only mode: $e');
  }

  runApp(const HabitTrackerApp());
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
