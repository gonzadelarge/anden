/// A saved trip between two stations. The home shows it in both directions.
class FavoriteTrip {
  const FavoriteTrip({
    required this.aId,
    required this.aName,
    required this.bId,
    required this.bName,
  });

  final int aId;
  final String aName;
  final int bId;
  final String bName;

  /// Same id for A ⇄ B and B ⇄ A, so the same pair cannot be saved twice.
  String get id => aId < bId ? '$aId-$bId' : '$bId-$aId';

  List<TripDirection> get directions => [
        TripDirection(originId: aId, originName: aName, destinationId: bId, destinationName: bName),
        TripDirection(originId: bId, originName: bName, destinationId: aId, destinationName: aName),
      ];

  factory FavoriteTrip.fromJson(Map<String, dynamic> json) => FavoriteTrip(
        aId: json['aId'] as int,
        aName: json['aName'] as String,
        bId: json['bId'] as int,
        bName: json['bName'] as String,
      );

  Map<String, dynamic> toJson() => {'aId': aId, 'aName': aName, 'bId': bId, 'bName': bName};
}

/// One direction of a trip: origin to destination.
class TripDirection {
  const TripDirection({
    required this.originId,
    required this.originName,
    required this.destinationId,
    required this.destinationName,
  });

  final int originId;
  final String originName;
  final int destinationId;
  final String destinationName;

  String get key => '$originId-$destinationId';

  TripDirection get reversed => TripDirection(
        originId: destinationId,
        originName: destinationName,
        destinationId: originId,
        destinationName: originName,
      );
}
