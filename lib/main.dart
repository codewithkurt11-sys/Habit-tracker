import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/hive_boxes.dart';
import 'logic/app_state.dart';
import 'core/theme/app_theme.dart';
import 'ui/widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();
  runApp(const LifeTrackerApp());
}

class LifeTrackerApp extends StatelessWidget {
  const LifeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initNotifications(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final isDark = state.isDark;
          return MaterialApp(
            title: 'Life Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
