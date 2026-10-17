import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'app_update_controller.dart';

/// Checks for a newer build and, when one is due, shows the update dialog.
/// Safe to call on every launch: it stays quiet for dev builds, failed
/// checks, and builds the user postponed in the last day.
Future<void> checkForUpdateAndPrompt(BuildContext context,
    {bool userInitiated = false}) async {
  final AppUpdateController controller;
  try {
    controller = context.read<AppUpdateController>();
  } on ProviderNotFoundException {
    return; // Trees without the updater (isolated widget tests).
  }
  final release = await controller.check();
  if (!context.mounted) return;
  if (release == null) {
    if (userInitiated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(controller.supported
              ? 'You\'re on the latest version.'
              : 'Updates are only checked on installed Android builds.')));
    }
    return;
  }
  if (!userInitiated && !await controller.shouldPrompt()) return;
  if (!context.mounted) return;
  await showUpdateDialog(context);
}

Future<void> showUpdateDialog(BuildContext context) {
  final controller = context.read<AppUpdateController>();
  return showDialog<void>(
    context: context,
    barrierDismissible: !controller.mandatory,
    builder: (_) => ChangeNotifierProvider<AppUpdateController>.value(
      value: controller,
      child: const _UpdateDialog(),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppUpdateController>();
    final release = c.available;
    final colors = BlistraColors.resolve(context);
    if (release == null) return const SizedBox.shrink();
    final sizeMb = release.sizeBytes == null
        ? null
        : (release.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);
    return PopScope(
      canPop: !c.mandatory && !c.downloading,
      child: AlertDialog(
        icon: Icon(Icons.system_update_outlined, color: colors.accentText, size: 32),
        title: Text(c.mandatory ? 'Update required' : 'Update available'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.mandatory
                    ? 'This version is no longer supported. Install the update to keep using Blistra.'
                    : 'A new version of Blistra is ready to install.',
                style: TextStyle(color: colors.text),
              ),
              const SizedBox(height: 8),
              Text(
                '${release.versionName} · build ${release.buildNumber}'
                '${sizeMb != null ? ' · $sizeMb MB' : ''}',
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              if ((release.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Text(release.notes!,
                        style: TextStyle(fontSize: 13, color: colors.muted, height: 1.4)),
                  ),
                ),
              ],
              if (c.downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: c.progress),
                const SizedBox(height: 6),
                Text(
                  c.progress == null
                      ? 'Downloading…'
                      : 'Downloading… ${(c.progress! * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
              if (c.error != null && !c.downloading) ...[
                const SizedBox(height: 12),
                Text(c.error!,
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          if (!c.mandatory)
            TextButton(
              onPressed: c.downloading
                  ? null
                  : () async {
                      await c.snooze();
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: c.downloading
                ? null
                : () async {
                    final ok = await c.downloadAndInstall();
                    // Leave a mandatory prompt up: the app is unusable until
                    // the new build is installed and relaunched.
                    if (ok && !c.mandatory && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(c.error != null ? 'Try again' : 'Update'),
          ),
        ],
      ),
    );
  }
}
