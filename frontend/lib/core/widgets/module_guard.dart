/// Controlled failure paths for module navigation.
///
/// No module entry may produce a red Flutter error screen. [ModuleErrorScreen]
/// renders a user-friendly error with Retry/Back; [ModulePlaceholder] renders
/// a polished coming-soon state for features without a backend/frontend
/// implementation. Both match the Blistra warm/off-white + teal language.
library;

import 'package:flutter/material.dart';

/// Full-page friendly error for a module that failed to open or load.
class ModuleErrorScreen extends StatelessWidget {
  const ModuleErrorScreen({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFFFBF6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 36,
                  color: Color(0xFFB42318),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => onRetry!(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Polished placeholder for a module that is not implemented yet.
///
/// Only used when the backend/frontend truly lacks the feature. Never used to
/// hide a runtime error from an implemented module.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFFFBF6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6F3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: const Color(0xFF0C6B6B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: Color(0xFF0C6B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes [page] and converts any synchronous route-build failure into a
/// friendly [ModuleErrorScreen] instead of a red error screen.
///
/// Asynchronous load errors remain owned by each module page (loading / empty
/// / error states); this guard only covers navigation-time failures.
Future<void> pushModulePage(
  BuildContext context,
  Widget page, {
  String title = 'Module',
  bool ownAppBar = true,
}) {
  try {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ownAppBar
            ? page
            : Scaffold(
                backgroundColor: const Color(0xFFFFFBF6),
                appBar: AppBar(
                  title: Text(title),
                  backgroundColor: const Color(0xFFFFFBF6),
                ),
                body: page,
              ),
      ),
    );
  } catch (error) {
    debugPrint('Module navigation failed ($title): $error');
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleErrorScreen(
          title: title,
          message: 'Could not open $title. Please try again.',
          onRetry: null,
        ),
      ),
    );
  }
}
