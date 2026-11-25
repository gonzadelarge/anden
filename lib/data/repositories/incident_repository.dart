import '../../core/clock.dart';
import '../api/anden_server_api.dart';
import '../models/incident.dart';
import '../storage/local_store.dart';

/// Last known service notices. Not cached for long: they change during the day.
class IncidentRepository {
  IncidentRepository(this._api, this._store, this._clock);

  static const _key = 'incidents';

  final AndenServerApi _api;
  final LocalStore _store;
  final Clock _clock;

  /// The last successful download, or null if there was none.
  ({IncidentsAnswer answer, DateTime fetchedAt})? cached() {
    final entry = _store.read<Map<String, dynamic>>(_key);
    if (entry == null) return null;
    final readAt = entry['readAt'] as String?;
    return (
      answer: IncidentsAnswer(
        ok: entry['ok'] == true,
        items: (entry['items'] as List).map((i) => Incident.fromJson(Map<String, dynamic>.from(i as Map))).toList(),
        readAt: readAt == null ? null : DateTime.parse(readAt),
      ),
      fetchedAt: DateTime.parse(entry['fetchedAt'] as String),
    );
  }

  /// Always downloads. Throws [AndenServerException] when the server cannot be reached.
  Future<IncidentsAnswer> fetch() async {
    final answer = await _api.fetchIncidents();
    await _store.write(_key, {
      'fetchedAt': _clock.now().toIso8601String(),
      'ok': answer.ok,
      'readAt': answer.readAt?.toIso8601String(),
      'items': answer.items.map((i) => i.toJson()).toList(),
    });
    return answer;
  }
}
