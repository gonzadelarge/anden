import 'dart:math';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Great-circle distance in metres (haversine).
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLon = _rad(other.longitude - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(latitude)) * cos(_rad(other.latitude)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadius * asin(min(1, sqrt(a)));
  }

  static double _rad(double deg) => deg * pi / 180;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
