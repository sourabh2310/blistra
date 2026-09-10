import 'dart:convert';

/// Derives a stable, strictly-positive 31-bit integer notification id from a
/// reminder UUID.
///
/// The value is a FNV-1a 32-bit hash of the reminder id, masked to
/// 0x7FFFFFFF so it fits Android's positive `int` notification id space.
/// Collisions are astronomically unlikely for a personal reminder list and can
/// never create duplicates — the worst case is that two reminders share an id
/// and only one notification is shown.
int notificationIdFor(String reminderId) {
  final bytes = utf8.encode(reminderId);
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final positive = hash & 0x7FFFFFFF;
  return positive == 0 ? 1 : positive;
}