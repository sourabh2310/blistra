import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/dietary_preference.dart';
import '../models/diet_profile.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

/// Displays and edits the user's diet preferences.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customPreference = TextEditingController();
  final _dislikedFoods = TextEditingController();
  final _notes = TextEditingController();

  DietaryPreference? _selectedPreference;

  @override
  void initState() {
    super.initState();
    final controller = context.read<DietController>();
    if (controller.profile == null) {
      controller.loadProfile();
    }
  }

  @override
  void dispose() {
    _customPreference.dispose();
    _dislikedFoods.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DietController>();
    final profile = controller.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Diet Profile')),
      body: RefreshIndicator(
        onRefresh: controller.loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (controller.profileLoading && profile == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (profile == null)
              const EmptyState(
                icon: Icons.person_outline,
                title: 'No diet profile yet',
                subtitle: 'Set your dietary preference and notes.',
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preference', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in DietaryPreference.values)
                            ChoiceChip(
                              label: Text(p.label),
                              selected: _selectedPreference == p,
                              onSelected: (_) =>
                                  setState(() => _selectedPreference = p),
                            ),
                        ],
                      ),
                      if (_selectedPreference == DietaryPreference.other) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customPreference,
                          decoration: const InputDecoration(
                            labelText: 'Custom preference label',
                            hintText: 'e.g. Flexitarian',
                          ),
                          validator: (value) {
                            if (_selectedPreference == DietaryPreference.other &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Required when "Other" is selected';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dislikedFoods,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Disliked foods',
                          alignLabelWithHint: true,
                          hintText: 'e.g. Shellfish, cilantro',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notes,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          alignLabelWithHint: true,
                          hintText: 'Anything else we should know?',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (controller.profileLoading)
                const Center(child: CircularProgressIndicator())
              else if (controller.lastActionError != null)
                ErrorState(
                  message: controller.lastActionError!,
                  onRetry: () => _save(controller),
                )
              else
                FilledButton.icon(
                  onPressed: () => _save(controller),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _populate(DietProfile profile) {
    setState(() {
      _selectedPreference = profile.dietaryPreference;
      _customPreference.text = profile.customPreference ?? '';
      _dislikedFoods.text = profile.dislikedFoods ?? '';
      _notes.text = profile.notes ?? '';
    });
  }

  Future<void> _save(DietController controller) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ok = await controller.saveProfile(
      dietaryPreference: _selectedPreference?.wireName,
      customPreference: _customPreference.text.trim().isEmpty
          ? null
          : _customPreference.text.trim(),
      dislikedFoods: _dislikedFoods.text.trim(),
      notes: _notes.text.trim(),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    }
  }
}