import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: AppMotion.medium,
        curve: Curves.easeInOut,
      );
    } else {
      final name = _nameController.text.trim();
      if (name.isEmpty) return;
      context.read<AppState>().completeOnboarding(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ext.gradientTop, ext.gradientBottom],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _buildWelcomePage(theme),
                      _buildFeaturesPage(theme),
                      _buildNamePage(theme),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? theme.colorScheme.primary
                            : ext.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(_page < 2 ? 'Continue' : 'Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.eco, size: 80, color: theme.colorScheme.secondary),
        const SizedBox(height: AppSpacing.lg),
        Text('Welcome to\nHabit Tracker',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Build better habits, track your progress,\nand become the best version of yourself.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFeaturesPage(ThemeData theme) {
    final features = [
      (Icons.repeat_rounded, 'Habits', 'Track daily habits and build streaks'),
      (Icons.check_circle_outline, 'Tasks', 'Manage tasks with priorities'),
      (Icons.track_changes, 'Goals', 'Set goals with milestones'),
      (Icons.book_outlined, 'Journal', 'Reflect on your day'),
      (Icons.account_balance_wallet_outlined, 'Finance', 'Track income & expenses'),
      (Icons.timer_outlined, 'Focus', 'Stay focused with a timer'),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Everything you need',
            style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xl),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Icon(f.$1, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$2, style: theme.textTheme.titleMedium),
                      Text(f.$3, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildNamePage(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.waving_hand, size: 64, color: theme.colorScheme.secondary),
        const SizedBox(height: AppSpacing.lg),
        Text("What's your name?",
            style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _next(),
        ),
      ],
    );
  }
}
