import '../../core/geo.dart';
import '../models/station.dart';

/// A station up to this much farther than the nearest one is also offered.
const nearbyStationsMargin = 400.0;
const maxNearbyStations = 3;

class NearbyStation {
  const NearbyStation(this.station, this.distance);

  final Station station;

  /// Metres from the user.
  final double distance;
}

/// The nearest station plus up to two others about as close, nearest first.
List<NearbyStation> nearbyStations(GeoPoint here, List<Station> stations) {
  final ranked = [
    for (final s in stations) NearbyStation(s, GeoPoint(s.latitude, s.longitude).distanceTo(here)),
  ]..sort((a, b) => a.distance.compareTo(b.distance));
  if (ranked.isEmpty) return const [];
  final limit = ranked.first.distance + nearbyStationsMargin;
  return ranked.where((s) => s.distance <= limit).take(maxNearbyStations).toList();
}
