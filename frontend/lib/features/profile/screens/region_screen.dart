import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/device/device_context.dart';
import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// Country, timezone, language and measurement units.
class RegionScreen extends StatelessWidget {
  const RegionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final p = controller.profile;
    final deviceZone = DeviceContext.currentTimezone();

    Future<void> save(Map<String, Object?> fields) async {
      final ok = await controller.save(fields);
      if (!ok && context.mounted) showProfileMessage(context, controller.error);
    }

    return ProfilePage(
      title: 'Language & region',
      children: [
        ProfileSection(
          title: 'Region',
          footer: 'Your timezone decides when "today" starts for meals, '
              'doses, habits and reminders.',
          children: [
            ProfileTile(
              icon: Icons.public_outlined,
              title: 'Country',
              subtitle: countryLabel(p?.country),
              onTap: () async {
                final c = await pickCountry(context);
                if (c != null) await save({'country': c.code});
              },
            ),
            ProfileTile(
              icon: Icons.schedule_outlined,
              title: 'Timezone',
              subtitle: p?.timezone ?? 'Not set',
              trailing: p?.timezone != deviceZone
                  ? TextButton(
                      onPressed: () => save({'timezone': deviceZone}),
                      child: const Text('Use device'),
                    )
                  : const StatusPill(label: 'Matches device', positive: true),
              onTap: () async {
                final value = await showTextFieldDialog(context,
                    title: 'Timezone',
                    initial: p?.timezone ?? deviceZone,
                    hint: 'e.g. Asia/Kolkata',
                    helper: 'IANA name. This device: $deviceZone');
                if (value != null && value.isNotEmpty) {
                  await save({'timezone': value});
                }
              },
            ),
          ],
        ),
        ProfileSection(
          title: 'Preferences',
          children: [
            ProfileTile(
              icon: Icons.translate_outlined,
              title: 'Language',
              subtitle: languageLabel(p?.language),
              onTap: () async {
                final choice = await pickOption(context,
                    title: 'Language',
                    options: kLanguageLabels,
                    selected: p?.language);
                if (choice != null) await save({'language': choice});
              },
            ),
            ProfileTile(
              icon: Icons.straighten_outlined,
              title: 'Units',
              subtitle: unitLabel(p?.unitSystem),
              onTap: () async {
                final choice = await pickOption(context,
                    title: 'Units',
                    options: const {
                      'METRIC': 'Metric (cm, kg, ml)',
                      'IMPERIAL': 'Imperial (in, lb, oz)',
                    },
                    selected: p?.unitSystem);
                if (choice != null) await save({'unitSystem': choice});
              },
            ),
          ],
        ),
      ],
    );
  }
}
