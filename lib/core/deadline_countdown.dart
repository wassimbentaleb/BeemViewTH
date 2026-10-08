enum DeadlineUrgency { none, relaxed, upcoming, soon, overdue }

// Une seule unite complete; les dates de travail gardent leur jour de calendrier.
class DeadlineCountdown {
  const DeadlineCountdown._(this.label, this.days, this.urgency);

  final String label;
  final int? days;
  final DeadlineUrgency urgency;

  bool get needsAttention => urgency == DeadlineUrgency.soon;

  factory DeadlineCountdown.at(
    DateTime? dueDate, {
    required DateTime now,
    bool inactive = false,
  }) {
    if (dueDate == null) {
      return const DeadlineCountdown._(
        'No due date',
        null,
        DeadlineUrgency.none,
      );
    }
    // UTC sert uniquement au calcul: un changement d'heure ne retire pas un jour.
    final today = DateTime.utc(now.year, now.month, now.day);
    final due = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;
    final urgency = inactive
        ? DeadlineUrgency.none
        : switch (days) {
            < 0 => DeadlineUrgency.overdue,
            <= 4 => DeadlineUrgency.soon,
            <= 14 => DeadlineUrgency.upcoming,
            _ => DeadlineUrgency.relaxed,
          };
    if (days == 0) return DeadlineCountdown._('Due today', days, urgency);

    final earlier = days > 0 ? today : due;
    final later = days > 0 ? due : today;
    var months = (later.year - earlier.year) * 12 + later.month - earlier.month;
    final lastDay = DateTime.utc(
      earlier.year,
      earlier.month + months + 1,
      0,
    ).day;
    final anniversary = DateTime.utc(
      earlier.year,
      earlier.month + months,
      earlier.day.clamp(1, lastDay),
    );
    if (anniversary.isAfter(later)) months--;
    final magnitude = days.abs();
    final (amount, unit) = months >= 1
        ? (months, 'month')
        : magnitude >= 7
        ? (magnitude ~/ 7, 'week')
        : (magnitude, 'day');
    final period = '$amount $unit${amount == 1 ? '' : 's'}';
    final label = days > 0 ? 'Due in $period' : 'Expired: $period';
    return DeadlineCountdown._(label, days, urgency);
  }
}
