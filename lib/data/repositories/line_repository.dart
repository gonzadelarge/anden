import '../../core/clock.dart';
import '../api/fgv_api.dart';
import '../models/line.dart';
import '../storage/local_store.dart';

class LineRepository {
  LineRepository(this._api, this._store, this._clock);

  static const _key = 'lines';
  static const maxAge = Duration(days: 7);

  final FgvApi _api;
  final LocalStore _store;
  final Clock _clock;

  List<Line> cached() {
    final entry = _store.read<Map<String, dynamic>>(_key);
    if (entry == null) return const [];
    return (entry['items'] as List).map((l) => Line.fromJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  /// Same policy as stations: cached for 7 days, old list used when offline.
  Future<List<Line>> getLines() async {
    final entry = _store.read<Map<String, dynamic>>(_key);
    final fetchedAt = entry == null ? null : DateTime.parse(entry['fetchedAt'] as String);
    if (fetchedAt != null && _clock.now().difference(fetchedAt) < maxAge) return cached();

    try {
      final lines = await _api.fetchLines();
      lines.sort((a, b) => a.number.compareTo(b.number));
      await _store.write(_key, {
        'fetchedAt': _clock.now().toIso8601String(),
        'items': lines.map((l) => l.toJson()).toList(),
      });
      return lines;
    } on FgvApiException {
      final old = cached();
      if (old.isNotEmpty) return old;
      rethrow;
    }
  }
}
