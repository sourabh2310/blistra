/// A single local notification that should be shown to the user.
///
/// `id` is a stable, reminder-derived integer so resyncing is idempotent and
/// duplicates are impossible. `when` is a local wall-clock moment.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String? payload;

  @override
  String toString() =>
      'ScheduledNotification(id: $id, title: "$title", when: $when)';
}