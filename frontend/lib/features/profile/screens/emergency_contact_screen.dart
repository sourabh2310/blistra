import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
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
      title: 'Emergency contact',
      children: [
        const SizedBox(height: 8),
        Text(
          'Someone we can point you or a helper to in an emergency. '
          'Stored privately on your account; Blistra never contacts them.',
          style: TextStyle(color: colors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter their name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _relation,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  hintText: 'e.g. Mother, Partner, Friend',
                  prefixIcon: Icon(Icons.favorite_border),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+919876543210',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: controller.saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: controller.saving
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save contact'),
        ),
        if (hasContact) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.saving ? null : _remove,
            child: const Text('Remove contact'),
          ),
        ],
      ],
    );
  }
}
