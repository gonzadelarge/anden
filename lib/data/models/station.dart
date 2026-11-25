class Station {
  const Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.lines = const [],
  });

  /// GTFS `stop_id` (Amistat 121, Colón 70). The server uses it everywhere.
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// Public numbers of the lines that stop here, sorted.
  final List<int> lines;

  /// Same shape in `/v2/stations` and in the cache.
  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as int,
        name: (json['name'] as String).trim(),
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        lines: ((json['lines'] as List?) ?? const []).map((l) => (l as num).toInt()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lon': longitude,
        'lines': lines,
      };
}
