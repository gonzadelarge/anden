import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/clock.dart';
import '../../data/models/day_timetable.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../data/services/next_departures.dart';

/// What the home knows about one direction of a trip.
class DirectionState {
  const DirectionState({this.today, this.tomorrow, this.loading = false, this.failed = false});

  final DayTimetable? today;
  final DayTimetable? tomorrow;
  final bool loading;

  /// The last download failed and there is nothing cached to show.
  final bool failed;

  bool get hasData => today != null || tomorrow != null;
}

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController(this._favorites, this._timetables, this._clock);

  static const tickInterval = Duration(seconds: 20);

  final FavoritesRepository _favorites;
  final TimetableRepository _timetables;
  final Clock _clock;

  final trips = <FavoriteTrip>[].obs;
  final states = <String, DirectionState>{}.obs;
  late final Rx<DateTime> now;

  /// True when the last refresh could not reach the server.
  final offline = false.obs;

  Timer? _ticker;
  late DateTime _serviceDay;

  DateTime get _today => _clock.today();
  DateTime get _tomorrow => DateTime(_today.year, _today.month, _today.day + 1);

  @override
  void onInit() {
    super.onInit();
    now = _clock.now().obs;
    _serviceDay = _today;
    _loadTrips();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  @override
  void onReady() {
    super.onReady();
    _timetables.prunePastDays();
    refreshAll();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      refreshAll();
    }
  }

  DirectionState stateOf(TripDirection d) => states[d.key] ?? const DirectionState();

  List<DateTime> nextOf(TripDirection d, {int count = 3}) {
    final s = stateOf(d);
    return nextDepartures([s.today, s.tomorrow], now.value, count: count);
  }

  /// Fresh cache entries are not downloaded again unless [force] is true.
  Future<void> refreshAll({bool force = false}) async {
    final directions = trips.expand((t) => t.directions).toList();
    final results = await Future.wait(directions.map((d) => _refresh(d, force: force)));
    offline.value = results.contains(false);
  }

  Future<void> openDay(TripDirection d) async {
    await Get.toNamed(Routes.dayView, arguments: d);
    // The day view may have downloaded newer data.
    _loadFromCache();
  }

  Future<void> addTrip() async {
    final added = await Get.toNamed(Routes.addTrip);
    if (added == true) {
      _loadTrips();
      await refreshAll();
    }
  }

  Future<void> deleteTrip(FavoriteTrip trip) async {
    await _favorites.remove(trip.id);
    _loadTrips();
  }

  void _tick() {
    now.value = _clock.now();
    if (_today != _serviceDay) {
      _serviceDay = _today;
      _loadFromCache();
      refreshAll();
    }
  }

  void _loadTrips() {
    trips.assignAll(_favorites.all());
    _loadFromCache();
  }

  void _loadFromCache() {
    final next = <String, DirectionState>{};
    for (final d in trips.expand((t) => t.directions)) {
      next[d.key] = DirectionState(
        today: _timetables.cached(d.originId, d.destinationId, _today),
        tomorrow: _timetables.cached(d.originId, d.destinationId, _tomorrow),
        loading: stateOf(d).loading,
      );
    }
    states.assignAll(next);
  }

  /// Returns false when a download failed.
  Future<bool> _refresh(TripDirection d, {required bool force}) async {
    final before = stateOf(d);
    states[d.key] = DirectionState(today: before.today, tomorrow: before.tomorrow, loading: true);

    var ok = true;
    Future<DayTimetable?> load(DateTime date, DayTimetable? fallback) async {
      try {
        return await _timetables.get(d.originId, d.destinationId, date, force: force);
      } catch (_) {
        ok = false;
        return fallback;
      }
    }

    final days = await Future.wait([load(_today, before.today), load(_tomorrow, before.tomorrow)]);
    // The trip may have been deleted while downloading.
    if (!trips.any((t) => t.directions.any((x) => x.key == d.key))) return ok;
    states[d.key] = DirectionState(
      today: days[0],
      tomorrow: days[1],
      failed: !ok && days[0] == null && days[1] == null,
    );
    return ok;
  }
}
