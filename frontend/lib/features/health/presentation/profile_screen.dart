import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repository});

  final HealthRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightController;

  BloodType _bloodType = BloodType.unknown;
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final HealthProfile? profile = widget.repository.profile;
    _bloodType = profile?.bloodType ?? BloodType.unknown;
    _dateOfBirth = profile?.dateOfBirth;
    _heightController = TextEditingController(
        text: profile?.heightCm == null ? '' : formatDouble(profile!.heightCm));
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final double? height = _heightController.text.trim().isEmpty
        ? null
        : double.tryParse(_heightController.text.trim());
    if (height != null && height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Height must be greater than zero')),
      );
      return;
    }

    final HealthProfileInput input = HealthProfileInput(
      heightCm: height,
      bloodType: _bloodType,
      dateOfBirth: _dateOfBirth,
    );

    setState(() => _saving = true);
    try {
      await widget.repository.saveProfile(input);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Health profile',
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _heightController,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<BloodType>(
              label: 'Blood type',
              value: _bloodType,
              items: [
                for (final BloodType type in BloodType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(bloodTypeLabels[type] ?? type.wire),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _bloodType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'Date of birth',
              value: _dateOfBirth,
              onChanged: (value) => setState(() => _dateOfBirth = value),
            ),
          ],
        ),
      ),
    );
  }
}