import '../../core/clock.dart';
import '../../core/time_format.dart';
import '../api/anden_server_api.dart';
import '../models/day_timetable.dart';
import '../storage/local_store.dart';

/// Timetables come from the own server (anden_server docs/plan-v2.md), kept in this cache.
/// Callers keep the cached copy on screen when [get] throws.
class TimetableRepository {
  TimetableRepository(this._api, this._store, this._clock);

  static const _prefix = 'tt:';
  static const maxAge = Duration(hours: 12);

  final AndenServerApi _api;
  final LocalStore _store;
  final Clock _clock;

  String _key(int originId, int destinationId, DateTime date) =>
      '$_prefix$originId:$destinationId:${formatDateKey(date)}';

  DayTimetable? cached(int originId, int destinationId, DateTime date) {
    final json = _store.read<Map<String, dynamic>>(_key(originId, destinationId, date));
    return json == null ? null : DayTimetable.fromJson(json);
  }

  /// Returns the cached timetable while it is fresh, downloads it otherwise.
  ///
  /// Throws [AndenServerException]. With [AndenServerException.isNoTimetable] the server
  /// has no timetable for the pair or the date (`no_route`, `date_not_covered`); any other
  /// error means it could not be reached. Callers keep showing [cached] in both cases.
  Future<DayTimetable> get(int originId, int destinationId, DateTime date, {bool force = false}) async {
    final old = cached(originId, destinationId, date);
    if (!force && old != null && old.complete && _clock.now().difference(old.fetchedAt) < maxAge) return old;

    final fresh = await _api.fetchTimetable(originId, destinationId, date);
    await _store.write(_key(originId, destinationId, date), fresh.toJson());
    return fresh;
  }

  /// Newest GTFS feed date among the cached timetables, "2026-11-24".
  String? newestFeedDate() {
    String? newest;
    for (final key in _store.keys.where((k) => k.startsWith(_prefix))) {
      final date = _store.read<Map<String, dynamic>>(key)?['feedDate'] as String?;
      if (date != null && (newest == null || date.compareTo(newest) > 0)) newest = date;
    }
    return newest;
  }

  /// Deletes cached days before today.
  Future<void> prunePastDays() async {
    final todayKey = formatDateKey(_clock.today());
    final stale = _store.keys.where((k) => k.startsWith(_prefix) && k.split(':').last.compareTo(todayKey) < 0);
    for (final key in stale.toList()) {
      await _store.remove(key);
    }
  }
}
