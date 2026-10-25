class Line {
  const Line({required this.id, required this.number, required this.name});

  /// Internal id. `incidencias` refers to lines by this id (42 = L1).
  final int id;

  /// `linea_id_FGV`, the public line number.
  final int number;

  /// "L1"
  final String name;

  factory Line.fromApi(Map<String, dynamic> json) => Line(
        id: json['id'] as int,
        number: json['linea_id_FGV'] as int,
        name: (json['nombre_corto'] as String).trim(),
      );

  factory Line.fromJson(Map<String, dynamic> json) =>
      Line(id: json['id'] as int, number: json['number'] as int, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'name': name};
}
