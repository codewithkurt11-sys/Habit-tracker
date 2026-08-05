import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/app_spacing.dart';
import '../../logic/app_state.dart';

Future<bool> showDeleteConfirmation(
  BuildContext context, {
  required String itemName,
  String? message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete $itemName?'),
      content: Text(
        message ??
            'This will permanently remove the $itemName from this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows an "Undone" toast for 3 seconds with undo action.
void showUndoToast(BuildContext context, String message, VoidCallback? onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      action: onUndo != null
          ? SnackBarAction(label: 'Undo', onPressed: onUndo)
          : null,
    ),
  );
}

/// Shows a non-blocking banner for missed finance days.
void showMissedFinanceBanner(
  BuildContext context,
  String message, {
  VoidCallback? onYes,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: 'Recalculate', onPressed: onYes ?? () {}),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  const SoftCard({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class PillChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const PillChip({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
          Text(label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ScreenTitleBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData menuIcon;
  final VoidCallback? onMenuTap;
  final Widget? trailing;

  const ScreenTitleBar({super.key, required this.title, this.subtitle,
    this.menuIcon = Icons.menu, this.onMenuTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: Icon(menuIcon),
            onPressed: onMenuTap ?? () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Circular progress fill icon — Streaks-app style.
class CircularFillIcon extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final IconData icon;
  final Color color;
  final double size;

  const CircularFillIcon({
    super.key,
    required this.progress,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Icon(icon, size: size * 0.4, color: color),
        ],
      ),
    );
  }
}

/// Animated completion check — subtle milestone feedback.
class CompletionRing extends StatefulWidget {
  final bool completed;
  final Color color;
  final double size;
  final int? milestone; // 7, 30, 100

  const CompletionRing({
    super.key,
    required this.completed,
    required this.color,
    this.size = 28,
    this.milestone,
  });

  @override
  State<CompletionRing> createState() => _CompletionRingState();
}

class _CompletionRingState extends State<CompletionRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    if (widget.completed) _controller.forward();
  }

  @override
  void didUpdateWidget(CompletionRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.milestone != null && widget.completed
        ? _milestoneColor(widget.milestone!)
        : widget.color;

    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.completed ? color : Colors.transparent,
          border: Border.all(
            color: color.withValues(alpha: widget.completed ? 1.0 : 0.3),
            width: 2,
          ),
        ),
        child: widget.completed
            ? Icon(Icons.check, size: widget.size * 0.6, color: Colors.white)
            : null,
      ),
    );
  }

  Color _milestoneColor(int days) {
    if (days >= 100) return const Color(0xFFE8B66F); // gold
    if (days >= 30) return const Color(0xFF6B9080); // sage
    if (days >= 7) return const Color(0xFF7B93B5); // blue
    return widget.color;
  }
}

/// Quick note composer — minimal inline composer for post-completion notes.
class QuickNoteComposer extends StatefulWidget {
  final String entityType;
  final String entityId;
  final VoidCallback? onSaved;

  const QuickNoteComposer({
    super.key,
    required this.entityType,
    required this.entityId,
    this.onSaved,
  });

  @override
  State<QuickNoteComposer> createState() => _QuickNoteComposerState();
}

class _QuickNoteComposerState extends State<QuickNoteComposer> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add a quick note', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What went well?',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _saving ? null : () => _save(context),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    if (_controller.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    // Save note via Provider
    final state = context.read<AppState>();
    state.addNote(
      title: 'Quick note',
      body: _controller.text.trim(),
      linkedEntityType: widget.entityType,
      linkedEntityId: widget.entityId,
    );
    Navigator.pop(context);
    widget.onSaved?.call();
  }
}

/// Quick note button — appears for 5 seconds after completion.
/// Tapping opens a minimal note composer. If ignored, no note is created.
class QuickNoteButton extends StatefulWidget {
  final String entityType;
  final String entityId;

  const QuickNoteButton({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  State<QuickNoteButton> createState() => _QuickNoteButtonState();
}

class _QuickNoteButtonState extends State<QuickNoteButton> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.note_add, size: 20),
      onPressed: () {
        setState(() => _visible = false);
        showModalBottomSheet(
          context: context,
          builder: (ctx) => QuickNoteComposer(
            entityType: widget.entityType,
            entityId: widget.entityId,
          ),
        );
      },
    );
  }
}
