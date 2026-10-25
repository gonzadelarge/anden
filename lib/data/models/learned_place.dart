import '../../core/geo.dart';

/// "When I open the app here, I look at this direction." Learned from the
/// card the user opens in places that are not close to a saved station.
class LearnedPlace {
  const LearnedPlace({required this.point, required this.directionKey, required this.updatedAt});

  final GeoPoint point;

  /// [TripDirection.key]
  final String directionKey;
  final DateTime updatedAt;

  factory LearnedPlace.fromJson(Map<String, dynamic> json) => LearnedPlace(
        point: GeoPoint((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble()),
        directionKey: json['key'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'lat': point.latitude,
        'lon': point.longitude,
        'key': directionKey,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
