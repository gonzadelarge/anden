import '../models/day_timetable.dart';

/// The next [count] departures at or after [now], across several service days.
///
/// Pass today and tomorrow: late in the evening the next trains are in
/// tomorrow's timetable, and night service after midnight is listed under the
/// next date.
List<DateTime> nextDepartures(Iterable<DayTimetable?> days, DateTime now, {int count = 3}) {
  // A train that leaves this minute still counts.
  final from = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final all = <DateTime>{
    for (final day in days)
      if (day != null) ...day.departures.where((t) => !t.isBefore(from)),
  }.toList()
    ..sort();
  return all.take(count).toList();
}
