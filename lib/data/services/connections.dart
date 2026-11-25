import '../models/day_timetable.dart';
import '../models/departure.dart';

/// Time to get off one train and reach the other platform. FGV uses 2 min after each
/// train's own arrival (anden_server docs/fgv-routing.md, rule 3); the app adds it to the
/// usual ride, so it matches FGV's connection in most cases.
const transferMargin = Duration(minutes: 2);

/// For each first-leg departure, the first train at the change station that
/// can be reached. Empty for direct trips or when the ride time is unknown.
///
/// Pass today and tomorrow: the connection can be after midnight.
Map<Departure, Departure> findConnections(List<Departure> departures, Iterable<DayTimetable?> days) {
  final legs = days.map((d) => d?.connection).whereType<ConnectionLeg>().toList();
  final rides = legs.map((l) => l.rideMinutes).whereType<int>();
  if (rides.isEmpty) return const {};
  final ride = Duration(minutes: rides.first);

  final trains = <Departure>{for (final leg in legs) ...leg.departures}.toList()..sort(Departure.compare);

  final chosen = <Departure, Departure>{};
  for (final departure in departures) {
    final earliest = departure.at.add(ride + transferMargin);
    for (final train in trains) {
      if (!train.at.isBefore(earliest)) {
        chosen[departure] = train;
        break;
      }
    }
  }
  return chosen;
}
