class Station {
  const Station({
    required this.id,
    required this.fgvId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.interchange,
  });

  /// Internal id. Used by `horarios-online2` (timetables).
  final int id;

  /// `estacion_id_FGV`. Used by `horarios-prevision-3` (real time, not in v1).
  final int fgvId;
  final String name;
  final double latitude;
  final double longitude;
  final bool interchange;

  factory Station.fromApi(Map<String, dynamic> json) => Station(
        id: json['id'] as int,
        fgvId: json['estacion_id_FGV'] as int,
        name: (json['nombre'] as String).trim(),
        latitude: (json['latitud'] as num).toDouble(),
        longitude: (json['longitud'] as num).toDouble(),
        interchange: json['transbordo'] == 1,
      );

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as int,
        fgvId: json['fgvId'] as int,
        name: json['name'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        interchange: json['interchange'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fgvId': fgvId,
        'name': name,
        'lat': latitude,
        'lon': longitude,
        'interchange': interchange,
      };
}
