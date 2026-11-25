import '../models/day_timetable.dart';
import '../models/departure.dart';

/// The next [count] departures at or after [now], across several service days.
///
/// Pass today and tomorrow: late in the evening the next trains are in
/// tomorrow's timetable, and night service after midnight is listed under the
/// next date.
List<Departure> nextDepartures(Iterable<DayTimetable?> days, DateTime now, {int count = 3}) {
  // A train that leaves this minute still counts.
  final from = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final all = <Departure>{
    for (final day in days)
      if (day != null) ...day.departures.where((d) => !d.at.isBefore(from)),
  }.toList()
    ..sort(Departure.compare);
  return all.take(count).toList();
}
