import '../models/day_timetable.dart';
import '../models/live_train.dart';
import 'train_match.dart';

/// Time to get off one train and reach the other platform. The stations are small.
const transferMargin = Duration(minutes: 1);

/// The train to take at the change station.
class Connection {
  const Connection({required this.at, required this.line, required this.destination});

  final DateTime at;

  /// "L9", or "L3, L5" when the line of this train is not known.
  final String line;
  final String destination;
}

/// For each first-leg departure, the first train at the change station that
/// can be reached. Empty for direct trips or when the ride time is unknown.
///
/// Pass today and tomorrow: the connection can be after midnight. [live] are
/// the real-time trains at the change station; [lines] are used without them.
Map<DateTime, Connection> findConnections(
  List<DateTime> departures,
  Iterable<DayTimetable?> days, {
  List<LiveTrain> live = const [],
  List<String> lines = const [],
}) {
  final legs = days.map((d) => d?.connection).whereType<ConnectionLeg>().toList();
  final rides = legs.map((l) => l.rideMinutes).whereType<int>();
  if (rides.isEmpty) return const {};
  final ride = Duration(minutes: rides.first);

  final times = <DateTime>{for (final leg in legs) ...leg.departures}.toList()..sort();
  final destinations = {for (final leg in legs) ...leg.destinations}.toList();

  final chosen = <DateTime, DateTime>{};
  for (final departure in departures) {
    final earliest = departure.add(ride + transferMargin);
    for (final time in times) {
      if (!time.isBefore(earliest)) {
        chosen[departure] = time;
        break;
      }
    }
  }

  final trains = matchLiveTrains(chosen.values.toSet().toList(), live, destinations);
  return chosen.map((departure, time) {
    final train = trains[time];
    return MapEntry(
      departure,
      Connection(
        at: time,
        line: train?.lineName ?? lines.join(', '),
        destination: train?.destination ?? destinations.join(', '),
      ),
    );
  });
}
