/// A service notice from metrovalencia.es, read by the own server.
class Incident {
  const Incident({
    required this.category,
    required this.priority,
    required this.title,
    required this.lines,
    this.url = '',
  });

  /// The site's category, for example `incidencia` or `servicio_especial`.
  final String category;

  /// From the site's priority block. The server sends these first.
  final bool priority;
  final String title;

  /// Public line numbers, 4 for L4.
  final List<int> lines;

  /// The notice's own link, "" when it has none.
  final String url;

  /// "Incidencia", "Servicio especial". Unknown categories are written out as they come.
  String get categoryLabel {
    final known = _categories[category];
    if (known != null) return known;
    final words = category.replaceAll('_', ' ').trim();
    return words.isEmpty ? 'Aviso' : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static const _categories = {
    'incidencia': 'Incidencia',
    'alerta_meteorologica': 'Alerta meteorológica',
    'circulacion': 'Circulación',
    'medioambiental': 'Medioambiental',
    'servicio_especial': 'Servicio especial',
  };

  /// Same shape in `/v2/incidents` and in the cache.
  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        category: (json['category'] as String?) ?? '',
        priority: json['priority'] == true,
        title: ((json['title'] as String?) ?? '').trim(),
        lines: ((json['lines'] as List?) ?? const []).map((l) => (l as num).toInt()).toList(),
        url: (json['url'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'priority': priority,
        'title': title,
        'lines': lines,
        'url': url,
      };
}
