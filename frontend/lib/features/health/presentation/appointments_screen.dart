import 'package:flutter/material.dart';

import '../health_models.dart';
import '../health_repository.dart';
import 'appointment_form_screen.dart';
import 'widgets.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final HealthRepository repository;

  /// Invoked after a successful create/edit/delete: upcoming appointments
  /// feed the Home dashboard and Planner timeline, so they must refresh.
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthAppointment>(
      title: 'Appointments',
      emptyMessage: 'No appointments yet.\nTap + to schedule one.',
      load: repository.loadAppointments,
      delete: (appointment) => repository.deleteAppointment(appointment.id),
      itemBuilder: (context, appointment) => _AppointmentTile(appointment),
      formBuilder: (context, edited) =>
          AppointmentFormScreen(repository: repository, initial: edited),
      onChanged: onChanged,
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile(this.appointment);

  final HealthAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      appointmentStatusLabels[appointment.status] ?? appointment.status?.wire ?? 'Scheduled',
      formatDateTime(appointment.scheduledAt),
      if (appointment.location != null && appointment.location!.isNotEmpty)
        appointment.location!,
    ];
    return Row(
      children: [
        const Icon(Icons.calendar_month_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}