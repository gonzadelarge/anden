import '../../core/clock.dart';
import '../api/fgv_api.dart';
import '../models/incident.dart';
import '../storage/local_store.dart';

/// Last known incidents. Not cached for long: they change during the day.
class IncidentRepository {
  IncidentRepository(this._api, this._store, this._clock);

  static const _key = 'incidents';

  final FgvApi _api;
  final LocalStore _store;
  final Clock _clock;

  /// Incidents from the last successful download, or null if there was none.
  ({List<Incident> items, DateTime fetchedAt})? cached() {
    final entry = _store.read<Map<String, dynamic>>(_key);
    if (entry == null) return null;
    return (
      items: (entry['items'] as List).map((i) => Incident.fromJson(Map<String, dynamic>.from(i as Map))).toList(),
      fetchedAt: DateTime.parse(entry['fetchedAt'] as String),
    );
  }

  /// Always downloads. Throws [FgvApiException] when offline.
  Future<List<Incident>> fetch() async {
    final items = await _api.fetchIncidents();
    await _store.write(_key, {
      'fetchedAt': _clock.now().toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    });
    return items;
  }
}
