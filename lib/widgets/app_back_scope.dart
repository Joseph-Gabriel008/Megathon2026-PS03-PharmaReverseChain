import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// Displays a sleek, MediLoop-themed confirmation dialog asking the user
/// if they want to exit the application.
Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: MediLoopColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MediLoopColors.line, width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MediLoopColors.critical.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.exit_to_app_rounded,
              color: MediLoopColors.critical,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Exit MediLoop?',
            style: MediLoopText.h3,
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to exit the application?',
        style: MediLoopText.bodyMuted,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: MediLoopColors.line),
            foregroundColor: MediLoopColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: MediLoopColors.critical,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Exit App'),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// A wrapper widget that intercepts swipe / system back gestures:
/// 1. If a modal, nested route, or dialog can pop, it pops it first.
/// 2. If the user is on a subpage or tab (not [homeRoute]), it navigates
///    back to [homeRoute].
/// 3. If the user is already on [homeRoute], it displays an exit confirmation
///    dialog before closing the application.
class AppBackScope extends StatelessWidget {
  final String homeRoute;
  final Widget child;
  final Future<void> Function()? onExitConfirmed;

  const AppBackScope({
    super.key,
    required this.homeRoute,
    required this.child,
    this.onExitConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If a pushed modal, dialog, or inner route exists on Navigator, pop it
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // 2. If not on the role home screen, navigate to the role home screen
        String? currentPath;
        try {
          currentPath = GoRouterState.of(context).uri.path;
        } catch (_) {
          // Context is outside a GoRoute subtree (e.g. standalone test)
        }

        if (currentPath != null && currentPath != homeRoute) {
          context.go(homeRoute);
          return;
        }

        // 3. If already on the home screen, prompt with exit confirmation dialog
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit) {
          if (onExitConfirmed != null) {
            await onExitConfirmed!();
          } else {
            await SystemNavigator.pop();
          }
        }
      },
      child: child,
    );
  }
}
