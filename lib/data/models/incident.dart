/// A service notice for one line.
class Incident {
  const Incident({
    required this.id,
    required this.lineId,
    required this.title,
    required this.text,
    required this.updatedAt,
  });

  final int id;

  /// Internal line id, see [Line.id].
  final int lineId;
  final String title;
  final String text;
  final DateTime updatedAt;

  /// Parses `GET incidencias`. The texts come in a separate list, one entry
  /// per language; [locale] is picked first, then any other language.
  static List<Incident> listFromApi(Map<String, dynamic> json, {String locale = 'ES'}) {
    final translations = <int, List<Map<String, dynamic>>>{};
    for (final t in ((json['incidencias_translations'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      if (t['deleted_at'] != null) continue;
      translations.putIfAbsent(t['incidencia_id'] as int, () => []).add(t);
    }

    final result = <Incident>[];
    for (final i in ((json['incidencias'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      if (i['deleted_at'] != null || (i['sede'] != null && i['sede'] != 'V')) continue;
      final texts = translations[i['id']] ?? const [];
      if (texts.isEmpty) continue;
      final chosen = texts.firstWhere((t) => t['locale'] == locale, orElse: () => texts.first);
      final text = ((chosen['descripcion'] as String?) ?? '').trim();
      if (text.isEmpty) continue;
      result.add(Incident(
        id: i['id'] as int,
        lineId: i['linea_id'] as int,
        title: ((chosen['titulo'] as String?) ?? '').trim(),
        text: text,
        updatedAt: DateTime.parse((i['updated_at'] ?? i['created_at']) as String).toLocal(),
      ));
    }
    return result;
  }

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as int,
        lineId: json['lineId'] as int,
        title: json['title'] as String,
        text: json['text'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lineId': lineId,
        'title': title,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
