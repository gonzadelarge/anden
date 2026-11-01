import '../../core/text_normalize.dart';
import '../models/live_train.dart';

/// A real-time train further than this from a timetable time is another train.
/// Seen on 2026-11-01: estimates are usually under 1 min from the timetable.
const matchTolerance = Duration(minutes: 3);

/// Links timetable [departures] to [live] trains that go towards [destinations].
///
/// The timetable has no line or destination per departure, and the real-time
/// list mixes both directions and other routes. Each train is used only once.
Map<DateTime, LiveTrain> matchLiveTrains(
  List<DateTime> departures,
  List<LiveTrain> live,
  List<String> destinations,
) {
  final wanted = destinations.map(normalizeForSearch).toSet();
  final free = live.where((t) => wanted.contains(normalizeForSearch(t.destination))).toList();
  final matches = <DateTime, LiveTrain>{};
  for (final departure in departures) {
    LiveTrain? best;
    var bestGap = matchTolerance;
    for (final train in free) {
      final gap = train.at.difference(departure).abs();
      if (gap <= bestGap) {
        best = train;
        bestGap = gap;
      }
    }
    if (best != null) {
      matches[departure] = best;
      free.remove(best);
    }
  }
  return matches;
}

/// "L5, L7 hacia Aeroport, Torrent Avinguda". Null when nothing is known.
String? routeSummary(List<String> lines, List<String> destinations) {
  final names = lines.join(', ');
  final towards = destinations.join(', ');
  if (names.isEmpty && towards.isEmpty) return null;
  if (towards.isEmpty) return names;
  return names.isEmpty ? 'Hacia $towards' : '$names hacia $towards';
}
