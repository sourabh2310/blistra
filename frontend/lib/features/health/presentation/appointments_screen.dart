import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      noun: 'appointment',
      emptyMessage: 'No appointments yet. Schedule one.',
      load: repository.loadAppointments,
      delete: (appointment) => repository.deleteAppointment(appointment.id),
      itemBuilder: _row,
      formBuilder: (context, edited) =>
          AppointmentFormScreen(repository: repository, initial: edited),
      onChanged: onChanged,
    );
  }

  static HealthRow _row(BuildContext context, HealthAppointment appointment) {
    final BlistraColors colors = BlistraColors.resolve(context);
    final String location = appointment.location?.trim() ?? '';
    final AppointmentStatus status =
        appointment.status ?? AppointmentStatus.scheduled;
    return HealthRow(
      icon: Icons.calendar_month_outlined,
      color: switch (status) {
        AppointmentStatus.cancelled || AppointmentStatus.missed => colors.danger,
        AppointmentStatus.completed => colors.muted,
        _ => colors.accentText,
      },
      title: appointment.title,
      subtitle: [
        friendlyDateTime(appointment.scheduledAt),
        if (location.isNotEmpty) location,
      ].join(' · '),
      meta: appointmentStatusLabels[status] ?? status.wire,
    );
  }
}
