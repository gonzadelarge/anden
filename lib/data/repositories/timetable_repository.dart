import '../../core/clock.dart';
import '../../core/time_format.dart';
import '../api/fgv_api.dart';
import '../models/day_timetable.dart';
import '../storage/local_store.dart';

class TimetableRepository {
  TimetableRepository(this._api, this._store, this._clock);

  static const _prefix = 'tt:';
  static const maxAge = Duration(hours: 12);

  final FgvApi _api;
  final LocalStore _store;
  final Clock _clock;

  String _key(int originId, int destinationId, DateTime date) =>
      '$_prefix$originId:$destinationId:${formatDateKey(date)}';

  DayTimetable? cached(int originId, int destinationId, DateTime date) {
    final json = _store.read<Map<String, dynamic>>(_key(originId, destinationId, date));
    return json == null ? null : DayTimetable.fromJson(json);
  }

  /// Returns the cached timetable while it is fresh, downloads it otherwise.
  /// Throws [FgvApiException] when the download fails; callers keep showing
  /// [cached] in that case and tell the user they are offline.
  Future<DayTimetable> get(int originId, int destinationId, DateTime date, {bool force = false}) async {
    final old = cached(originId, destinationId, date);
    if (!force && old != null && _clock.now().difference(old.fetchedAt) < maxAge) return old;

    final fresh = await _api.fetchTimetable(originId, destinationId, date);
    await _store.write(_key(originId, destinationId, date), fresh.toJson());
    return fresh;
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
