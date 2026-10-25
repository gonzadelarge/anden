import '../../core/geo.dart';
import '../models/favorite_trip.dart';
import '../models/learned_place.dart';
import '../repositories/learned_places_repository.dart';

/// A saved origin must be this close to count as "your" station.
const nearStationRadius = 1000.0;

/// When a second saved origin is within [nearStationRadius] too, and not at
/// least this much farther than the nearest, the position is ambiguous.
const ambiguityMargin = 400.0;

enum NearbyReason { station, learnedPlace }

class NearbyResult {
  const NearbyResult(this.directionKeys, this.reason);

  /// Usually one key. More than one when several saved trips start at the
  /// same station.
  final Set<String> directionKeys;
  final NearbyReason reason;
}

/// Picks the card(s) to highlight for the user at [here].
///
/// 1. Station rule: the nearest saved origin within 1 km wins, unless another
///    saved origin is about as close (then nothing is marked).
/// 2. Learned places: otherwise, a place within 300 m where the user opened a
///    card before.
NearbyResult? pickNearbyDirections({
  required GeoPoint here,
  required List<TripDirection> directions,
  required Map<int, GeoPoint> stationPoints,
  List<LearnedPlace> learned = const [],
}) {
  final byStation = nearestOrigin(here: here, directions: directions, stationPoints: stationPoints);
  if (byStation != null) return NearbyResult(byStation, NearbyReason.station);

  final keys = directions.map((d) => d.key).toSet();
  LearnedPlace? best;
  var bestDistance = double.infinity;
  for (final place in learned) {
    if (!keys.contains(place.directionKey)) continue;
    final d = place.point.distanceTo(here);
    if (d <= LearnedPlacesRepository.samePlaceRadius && d < bestDistance) {
      best = place;
      bestDistance = d;
    }
  }
  return best == null ? null : NearbyResult({best.directionKey}, NearbyReason.learnedPlace);
}

/// Directions whose origin is clearly the nearest saved station within 1 km.
/// Null when no origin is that close or when two origins are about as close.
Set<String>? nearestOrigin({
  required GeoPoint here,
  required List<TripDirection> directions,
  required Map<int, GeoPoint> stationPoints,
}) {
  final distances = <int, double>{};
  for (final d in directions) {
    final point = stationPoints[d.originId];
    if (point != null) distances[d.originId] = point.distanceTo(here);
  }
  final ranked = distances.entries.where((e) => e.value <= nearStationRadius).toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  if (ranked.isEmpty) return null;
  if (ranked.length > 1 && ranked[1].value - ranked[0].value < ambiguityMargin) return null;

  final origin = ranked.first.key;
  return directions.where((d) => d.originId == origin).map((d) => d.key).toSet();
}
