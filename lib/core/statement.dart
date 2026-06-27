/// Credit-card statement date/amount helpers. Pure Dart (only uses DateTime),
/// with `today` injected so they stay deterministic and unit-testable.
library;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthAbbrev(int month) => _months[(month - 1).clamp(0, 11)];

/// Calendar-day label for the Activity screen: Today / Yesterday / 'Jun 21'.
String dayLabel(DateTime date, DateTime today) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${monthAbbrev(date.month)} ${date.day}';
}

/// Compact date for inputs/pickers, e.g. '26 Jun 2026'.
String compactDate(DateTime date) =>
    '${date.day} ${monthAbbrev(date.month)} ${date.year}';

/// Ordinal form of a day-of-month, e.g. 1 -> "1st", 5 -> "5th", 22 -> "22nd".
String ordinalDay(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

int _daysInMonth(int year, int month) {
  final firstOfNext = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  return firstOfNext.subtract(const Duration(days: 1)).day;
}

/// Day-of-month cells for a Sunday-first month grid: leading `null`s padding to
/// the weekday of the 1st, then 1..daysInMonth. Drives the in-sheet calendar.
List<int?> monthGridCells(int year, int month) {
  final lead = DateTime(year, month, 1).weekday % 7; // Mon=1..Sun=7 → Sun=0
  final days = _daysInMonth(year, month);
  return [
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= days; d++) d,
  ];
}

DateTime _clampedDate(int year, int month, int day) =>
    DateTime(year, month, day.clamp(1, _daysInMonth(year, month)));

/// The next calendar date whose day-of-month is [day], on or after [today]
/// (clamped to month length, so day 31 lands on Feb 28/29 etc.).
DateTime nextOccurrence(int day, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  final thisMonth = _clampedDate(t.year, t.month, day);
  if (!thisMonth.isBefore(t)) return thisMonth;
  var year = t.year, month = t.month + 1;
  if (month > 12) {
    month = 1;
    year += 1;
  }
  return _clampedDate(year, month, day);
}

/// Short label for the next occurrence of [day], e.g. "Jul 25".
String nextDueLabel(int day, DateTime today) {
  final d = nextOccurrence(day, today);
  return '${monthAbbrev(d.month)} ${d.day}';
}

/// The next due date for a recurring item: +7 days for `'Weekly'`, otherwise one
/// month on with the day clamped to the target month's length (Jan 31 → Feb 28).
/// Pass [anchorDay] to advance from a fixed day-of-month so a clamp doesn't
/// stick — e.g. a Jan-31 bill stays on the 31st (Feb 28 → Mar 31), not drifting
/// to the 28th. Defaults to [from]'s own day.
DateTime nextRecurringDate(DateTime from, String freq, {int? anchorDay}) {
  if (freq == 'Weekly') return from.add(const Duration(days: 7));
  final month = from.month == 12 ? 1 : from.month + 1;
  final year = from.month == 12 ? from.year + 1 : from.year;
  return _clampedDate(year, month, anchorDay ?? from.day);
}

/// Charges accrued since the statement closed (not yet billed) =
/// total owed − the manually-entered statement balance, floored at 0.
double pendingThisCycle(double balance, double? statementBalance) {
  final pending = balance.abs() - (statementBalance ?? 0);
  return pending < 0 ? 0 : pending;
}
