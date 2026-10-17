import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// Who you are: name, bio, birthday and gender.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final p = controller.profile;
    return ProfilePage(
      title: 'Personal info',
      children: [
        ProfileSection(
          title: 'About you',
          footer: 'Your display name and bio are shown to friends you split '
              'expenses with. Everything else stays private to you.',
          children: [
            ProfileTile(
              icon: Icons.badge_outlined,
              title: 'Display name',
              subtitle: (p?.displayName ?? '').isEmpty ? 'Not set' : p!.displayName,
              onTap: () => _editText(context, controller,
                  field: 'displayName',
                  title: 'Display name',
                  initial: p?.displayName ?? '',
                  maxLength: 120),
            ),
            ProfileTile(
              icon: Icons.short_text,
              title: 'Bio',
              subtitle: (p?.bio ?? '').isEmpty ? 'Add a line about yourself' : p!.bio,
              onTap: () => _editText(context, controller,
                  field: 'bio',
                  title: 'Bio',
                  initial: p?.bio ?? '',
                  hint: 'e.g. Morning runner, coffee lover',
                  maxLength: 280,
                  maxLines: 3),
            ),
          ],
        ),
        ProfileSection(
          title: 'Details',
          footer: 'Date of birth and gender help Health and Diet give '
              'age- and body-appropriate targets.',
          children: [
            ProfileTile(
              icon: Icons.cake_outlined,
              title: 'Date of birth',
              subtitle: p?.dateOfBirth == null
                  ? 'Not set'
                  : '${formatProfileDate(p!.dateOfBirth)}'
                      '${p.age != null ? ' · ${p.age} years' : ''}',
              onTap: () => _pickDob(context, controller),
            ),
            ProfileTile(
              icon: Icons.wc_outlined,
              title: 'Gender',
              subtitle: kGenderLabels[p?.gender] ?? 'Not set',
              onTap: () async {
                final choice = await pickOption(context,
                    title: 'Gender', options: kGenderLabels, selected: p?.gender);
                if (choice == null || !context.mounted) return;
                final ok = await controller.save({'gender': choice});
                if (!ok && context.mounted) {
                  showProfileMessage(context, controller.error);
                }
              },
            ),
            const ProfileTile(
              icon: Icons.monitor_weight_outlined,
              title: 'Height, weight & blood type',
              subtitle: 'Kept in your Health profile and measurements',
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _editText(
    BuildContext context,
    ProfileController controller, {
    required String field,
    required String title,
    required String initial,
    String? hint,
    int? maxLength,
    int maxLines = 1,
  }) async {
    final value = await showTextFieldDialog(context,
        title: title,
        initial: initial,
        hint: hint,
        maxLength: maxLength,
        maxLines: maxLines);
    if (value == null || value == initial || !context.mounted) return;
    final ok = await controller.save({field: value});
    if (!ok && context.mounted) showProfileMessage(context, controller.error);
  }

  static Future<void> _pickDob(
      BuildContext context, ProfileController controller) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.profile?.dateOfBirth ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null || !context.mounted) return;
    final iso = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    final ok = await controller.save({'dateOfBirth': iso});
    if (!ok && context.mounted) showProfileMessage(context, controller.error);
  }
}
