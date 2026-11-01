class Line {
  const Line({required this.id, required this.number, required this.name, this.stops = const []});

  /// Internal id. `incidencias` refers to lines by this id (42 = L1).
  final int id;

  /// `linea_id_FGV`, the public line number.
  final int number;

  /// "L1"
  final String name;

  /// [Station.fgvId] of the stations this line stops at.
  final List<int> stops;

  factory Line.fromApi(Map<String, dynamic> json) => Line(
        id: json['id'] as int,
        number: json['linea_id_FGV'] as int,
        name: (json['nombre_corto'] as String).trim(),
        stops: _parseStops(json['stops'] as String?),
      );

  factory Line.fromJson(Map<String, dynamic> json) => Line(
        id: json['id'] as int,
        number: json['number'] as int,
        name: json['name'] as String,
        stops: ((json['stops'] as List?) ?? const []).cast<int>(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'name': name, 'stops': stops};

  /// "107,80,79"
  static List<int> _parseStops(String? stops) =>
      (stops ?? '').split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
}
