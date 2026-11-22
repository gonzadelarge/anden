import '../../core/clock.dart';
import '../../core/time_format.dart';
import '../api/anden_server_api.dart';
import '../api/fgv_api.dart';
import '../models/day_timetable.dart';
import '../storage/local_store.dart';

/// Timetables come from three places, in this order (anden_server docs/plan.md, section 9):
///
/// 1. the own server on the VPS (5 s timeout), when the build has its URL and token;
/// 2. the FGV API (25 s);
/// 3. this cache, which callers keep on screen when [get] throws.
///
/// Trips with a change of line ask FGV first and use the server only when FGV fails
/// (decision D4): FGV picks the change station by rules the server copies only in part.
/// The app knows a pair needs a change from the cache or from the server's answer.
class TimetableRepository {
  TimetableRepository(this._api, this._store, this._clock, {AndenServerApi? server}) : _server = server; // ignore: prefer_initializing_formals

  static const _prefix = 'tt:';
  static const maxAge = Duration(hours: 12);

  final FgvApi _api;
  final AndenServerApi? _server;
  final LocalStore _store;
  final Clock _clock;

  String _key(int originId, int destinationId, DateTime date) =>
      '$_prefix$originId:$destinationId:${formatDateKey(date)}';

  DayTimetable? cached(int originId, int destinationId, DateTime date) {
    final json = _store.read<Map<String, dynamic>>(_key(originId, destinationId, date));
    return json == null ? null : DayTimetable.fromJson(json);
  }

  /// Returns the cached timetable while it is fresh, downloads it otherwise.
  /// Throws [FgvApiException] when every source fails; callers keep showing
  /// [cached] in that case and tell the user they are offline.
  Future<DayTimetable> get(int originId, int destinationId, DateTime date, {bool force = false}) async {
    final old = cached(originId, destinationId, date);
    if (!force && old != null && old.complete && _clock.now().difference(old.fetchedAt) < maxAge) return old;

    final fresh = await _download(originId, destinationId, date, knownChange: (old?.legs ?? 1) > 1);
    await _store.write(_key(originId, destinationId, date), fresh.toJson());
    return fresh;
  }

  Future<DayTimetable> _download(int originId, int destinationId, DateTime date, {required bool knownChange}) async {
    final server = _server;
    if (server == null || !server.enabled) return _api.fetchTimetable(originId, destinationId, date);

    if (knownChange) {
      try {
        return await _api.fetchTimetable(originId, destinationId, date);
      } on FgvApiException {
        final answer = await _fromServer(server, originId, destinationId, date);
        if (answer == null) rethrow;
        return answer;
      }
    }

    final answer = await _fromServer(server, originId, destinationId, date);
    if (answer == null) return _api.fetchTimetable(originId, destinationId, date);
    if (answer.legs <= 1) return answer;
    try {
      return await _api.fetchTimetable(originId, destinationId, date);
    } on FgvApiException {
      return answer;
    }
  }

  /// The server's answer, or null on any error (no_route, date_not_covered, network...).
  Future<DayTimetable?> _fromServer(AndenServerApi server, int originId, int destinationId, DateTime date) async {
    try {
      return await server.fetchTimetable(originId, destinationId, date);
    } on AndenServerException {
      return null;
    }
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
