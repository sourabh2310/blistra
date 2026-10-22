import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/dietary_preference.dart';
import '../widgets/diet_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

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
  bool _hydrated = false;

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
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<DietController>();
    final profile = controller.profile;
    if (!_hydrated && profile != null) {
      _hydrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedPreference = profile.dietaryPreference;
          _customPreference.text = profile.customPreference ?? '';
          _dislikedFoods.text = profile.dislikedFoods ?? '';
          _notes.text = profile.notes ?? '';
        });
      });
    }
    final waiting = controller.profileLoading && profile == null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadProfile,
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              children: [
                const BlistraPageHeader(
                  eyebrow: 'Diet profile',
                  title: 'How do you eat?',
                  subtitle:
                      'Your preference and foods to avoid. Nutrition targets are not stored in Diet.',
                  showAvatar: false,
                ),
                if (waiting)
                  const PagePad(SkeletonLoader(rows: 3), top: 14)
                else ...[
                  const PagePad(DietFormLabel('Preference'), top: 8),
                  ChipRow(
                    labels: [for (final p in DietaryPreference.values) p.label],
                    selected: _selectedPreference == null
                        ? null
                        : DietaryPreference.values.indexOf(_selectedPreference!),
                    onSelected: (i) => setState(
                      () => _selectedPreference = DietaryPreference.values[i],
                    ),
                  ),
                  PagePad(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_selectedPreference == DietaryPreference.other)
                          DietTextField(
                            label: 'Custom preference label',
                            controller: _customPreference,
                            hint: 'e.g. Flexitarian',
                            validator: (value) {
                              if (_selectedPreference == DietaryPreference.other &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Required when "Other" is selected';
                              }
                              return null;
                            },
                          ),
                        DietTextField(
                          label: 'Disliked foods',
                          controller: _dislikedFoods,
                          hint: 'e.g. Shellfish, cilantro',
                          maxLines: 3,
                          maxLength: 1000,
                        ),
                        DietTextField(
                          label: 'Notes',
                          controller: _notes,
                          hint: 'Anything else we should know?',
                          maxLines: 4,
                          maxLength: 2000,
                        ),
                        if (controller.lastActionError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              controller.lastActionError!,
                              style: TextStyle(
                                color: colors.danger,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    top: 12,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: waiting
          ? null
          : StickyActionBar(
              label: 'Save profile',
              busy: controller.profileLoading,
              onPressed: () => _save(controller),
            ),
    );
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
