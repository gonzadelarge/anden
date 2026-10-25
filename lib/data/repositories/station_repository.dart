import '../../core/clock.dart';
import '../../core/text_normalize.dart';
import '../api/fgv_api.dart';
import '../models/station.dart';
import '../storage/local_store.dart';

class StationRepository {
  StationRepository(this._api, this._store, this._clock);

  static const _key = 'stations';
  static const maxAge = Duration(days: 7);

  final FgvApi _api;
  final LocalStore _store;
  final Clock _clock;

  /// Stations from the cache, sorted by name. Empty before the first download.
  List<Station> cached() {
    final entry = _store.read<Map<String, dynamic>>(_key);
    if (entry == null) return const [];
    return (entry['items'] as List).map((s) => Station.fromJson(Map<String, dynamic>.from(s as Map))).toList();
  }

  /// Returns the cached list while it is fresh. Downloads it otherwise. If the
  /// download fails and an old list exists, the old list is returned.
  Future<List<Station>> getStations({bool force = false}) async {
    final entry = _store.read<Map<String, dynamic>>(_key);
    final fetchedAt = entry == null ? null : DateTime.parse(entry['fetchedAt'] as String);
    final fresh = fetchedAt != null && _clock.now().difference(fetchedAt) < maxAge;
    if (fresh && !force) return cached();

    try {
      final stations = await _api.fetchStations();
      // Plain compareTo would put "Àngel Guimerà" after "Z".
      stations.sort((a, b) => normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)));
      await _store.write(_key, {
        'fetchedAt': _clock.now().toIso8601String(),
        'items': stations.map((s) => s.toJson()).toList(),
      });
      return stations;
    } on FgvApiException {
      final old = cached();
      if (old.isNotEmpty) return old;
      rethrow;
    }
  }
}
