import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// The person to reach in an emergency, kept alongside medicines and health
/// records so it is one tap away when it matters.
class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relation;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileController>().profile;
    _name = TextEditingController(text: p?.emergencyContactName ?? '');
    _relation = TextEditingController(text: p?.emergencyContactRelation ?? '');
    _phone = TextEditingController(text: p?.emergencyContactPhone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final controller = context.read<ProfileController>();
    final ok = await controller.save({
      'emergencyContactName': _name.text.trim(),
      'emergencyContactRelation': _relation.text.trim(),
      'emergencyContactPhone': _phone.text.trim(),
    });
    if (!mounted) return;
    if (!ok) {
      showProfileMessage(context, controller.error);
      return;
    }
    showProfileMessage(context, 'Emergency contact saved.');
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final controller = context.read<ProfileController>();
    final ok = await controller.save({
      'emergencyContactName': '',
      'emergencyContactRelation': '',
      'emergencyContactPhone': '',
    });
    if (!mounted) return;
    if (!ok) {
      showProfileMessage(context, controller.error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final colors = BlistraColors.resolve(context);
    final hasContact = controller.profile?.hasEmergencyContact ?? false;
    return ProfilePage(
      eyebrow: 'Safety',
      title: 'Emergency contact',
      subtitle: 'Someone we can point you or a helper to in an emergency. '
          'Stored privately on your account; Blistra never contacts them.',
      bottom: StickyActionBar(
        label: 'Save contact',
        busy: controller.saving,
        onPressed: _save,
        secondary: hasContact
            ? TextButton(
                onPressed: controller.saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                child: const Text('Remove contact'),
              )
            : null,
      ),
      children: [
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            children: [
              GlassTextField(
                label: 'Name',
                controller: _name,
                hint: 'Their full name',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter their name' : null,
              ),
              GlassTextField(
                label: 'Relationship (optional)',
                controller: _relation,
                hint: 'e.g. Mother, Partner, Friend',
                textInputAction: TextInputAction.next,
              ),
              GlassTextField(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                hint: '+919876543210',
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[\s()-]'), '');
                  if (digits.isEmpty) return 'Enter their phone number';
                  if (!RegExp(r'^\+\d{7,15}$').hasMatch(digits)) {
                    return 'Use international format, e.g. +919876543210';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
