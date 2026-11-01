import 'package:get/get.dart';

import '../../core/clock.dart';
import '../api/fgv_api.dart';
import '../models/day_timetable.dart';
import '../models/live_train.dart';
import '../models/station.dart';
import '../services/connections.dart';
import 'line_repository.dart';
import 'station_repository.dart';

/// Real-time trains per station. Kept in memory only: they age in a minute.
class LiveTrainRepository {
  LiveTrainRepository(this._api, this._stations, this._lines, this._clock);

  static const maxAge = Duration(seconds: 60);

  final FgvApi _api;
  final StationRepository _stations;
  final LineRepository _lines;
  final Clock _clock;

  final Map<int, List<LiveTrain>> _trains = {};
  final Map<int, DateTime> _fetchedAt = {};

  /// Goes up when new data arrives, so screens can rebuild.
  final revision = 0.obs;

  /// Trains at the station with this [Station.id]. Empty when unknown.
  List<LiveTrain> at(int stationId) => _trains[stationId] ?? const [];

  /// Downloads stations older than [maxAge]. A failure keeps the old trains:
  /// labels are extra information, so it never shows an error.
  Future<void> refresh(Iterable<int> stationIds, {bool force = false}) async {
    final ids = stationIds.toSet();
    if (ids.isEmpty) return;
    await _loadLines();
    final fgvIds = {for (final s in await _loadStations()) s.id: s.fgvId};
    revision.value++;
    await Future.wait(ids.map((id) async {
      final fgvId = fgvIds[id];
      final last = _fetchedAt[id];
      if (fgvId == null) return;
      if (!force && last != null && _clock.now().difference(last) < maxAge) return;
      try {
        _trains[id] = await _api.fetchLiveTrains(fgvId);
        _fetchedAt[id] = _clock.now();
        revision.value++;
      } on FgvApiException {
        // Keep what we have.
      }
    }));
  }

  /// Names of the lines that stop at both stations, from the cached line list.
  /// Empty when a change of line is needed.
  List<String> linesBetween(int originId, int destinationId) {
    final fgvIds = {for (final s in _stations.cached()) s.id: s.fgvId};
    final origin = fgvIds[originId];
    final destination = fgvIds[destinationId];
    if (origin == null || destination == null) return const [];
    return [
      for (final line in _lines.cached())
        if (line.stops.contains(origin) && line.stops.contains(destination)) line.name,
    ];
  }

  /// Lines of the first train: to the change station, or to the destination.
  List<String> firstLegLines(Iterable<DayTimetable?> days, int originId, int destinationId) {
    final change = _changeOf(days);
    return linesBetween(originId, change?.stationId ?? destinationId);
  }

  /// The train to take at the change station for each departure.
  Map<DateTime, Connection> connections(List<DateTime> departures, Iterable<DayTimetable?> days, int destinationId) {
    final change = _changeOf(days);
    if (change == null) return const {};
    return findConnections(
      departures,
      days,
      live: at(change.stationId),
      lines: linesBetween(change.stationId, destinationId),
    );
  }

  ConnectionLeg? _changeOf(Iterable<DayTimetable?> days) => days.map((d) => d?.connection).nonNulls.firstOrNull;

  Future<void> _loadLines() async {
    try {
      await _lines.getLines();
    } on FgvApiException {
      // No line names until the next try.
    }
  }

  Future<List<Station>> _loadStations() async {
    try {
      return await _stations.getStations();
    } on FgvApiException {
      return const [];
    }
  }
}
