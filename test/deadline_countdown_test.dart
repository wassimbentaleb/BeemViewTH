import 'package:beemview/core/deadline_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7, 23, 59);

  test('countdown uses one complete month, week or day unit', () {
    for (final (date, label) in [
      (DateTime(2027, 3, 7), 'Expires: 5 months'),
      (DateTime(2026, 11, 7), 'Expires: 1 month'),
      (DateTime(2026, 10, 28), 'Expires: 3 weeks'),
      (DateTime(2026, 10, 14), 'Expires: 1 week'),
      (DateTime(2026, 10, 13), 'Expires: 6 days'),
      (DateTime(2026, 10, 11), 'Expires: 4 days'),
      (DateTime(2026, 10, 8), 'Expires: 1 day'),
      (DateTime(2026, 10, 7), 'Expires: Today'),
    ]) {
      expect(DeadlineCountdown.at(date, now: today).label, label);
    }
  });

  test('urgency changes at 14, 4 and 0 remaining calendar days', () {
    for (final (days, urgency, attention) in [
      (15, DeadlineUrgency.relaxed, false),
      (14, DeadlineUrgency.upcoming, false),
      (5, DeadlineUrgency.upcoming, false),
      (4, DeadlineUrgency.soon, true),
      (1, DeadlineUrgency.soon, true),
      (0, DeadlineUrgency.soon, true),
      (-1, DeadlineUrgency.overdue, false),
    ]) {
      final countdown = DeadlineCountdown.at(
        DateTime(2026, 10, 7 + days),
        now: today,
      );
      expect(countdown.days, days);
      expect(countdown.urgency, urgency);
      expect(countdown.needsAttention, attention);
    }
  });

  test('month anniversaries clamp to short months and cross leap years', () {
    for (final (start, end, label) in [
      (DateTime(2026, 1, 31), DateTime(2026, 2, 28), '1 month'),
      (DateTime(2024, 1, 31), DateTime(2024, 2, 29), '1 month'),
      (DateTime(2026, 1, 31), DateTime(2026, 2, 27), '3 weeks'),
      (DateTime(2026, 12, 31), DateTime(2027, 2, 28), '2 months'),
      (DateTime(2026, 10, 7), DateTime(2027, 10, 7), '12 months'),
    ]) {
      expect(DeadlineCountdown.at(end, now: start).label, 'Expires: $label');
    }
  });

  test('calendar days ignore times and timezone representations', () {
    final countdown = DeadlineCountdown.at(
      DateTime.utc(2026, 10, 8),
      now: DateTime(2026, 10, 7, 23, 59, 59),
    );
    expect(countdown.days, 1);
    expect(countdown.label, 'Expires: 1 day');
    expect(
      DeadlineCountdown.at(
        DateTime.utc(2026, 11, 1),
        now: DateTime(2026, 10, 31, 23),
      ).days,
      1,
    );
  });

  test('missing and closed deadlines stay neutral without attention', () {
    final missing = DeadlineCountdown.at(null, now: today);
    expect(missing.label, 'No due date');
    expect(missing.days, isNull);
    expect(missing.urgency, DeadlineUrgency.none);
    for (final date in [DateTime(2026, 10, 6), DateTime(2026, 10, 11)]) {
      final closed = DeadlineCountdown.at(date, now: today, inactive: true);
      expect(closed.urgency, DeadlineUrgency.none);
      expect(closed.needsAttention, isFalse);
    }
    expect(
      DeadlineCountdown.at(
        DateTime(2026, 10, 6),
        now: today,
        inactive: true,
      ).label,
      'Expired: 1 day',
    );
    expect(
      DeadlineCountdown.at(DateTime(2026, 9, 30), now: today).label,
      'Expired: 1 week',
    );
  });
}
