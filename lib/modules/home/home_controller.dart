import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/clock.dart';
import '../../data/models/day_timetable.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/models/departure.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../data/services/connections.dart';
import '../../data/services/next_departures.dart';
import '../../shared/messages.dart';
import '../../shared/pick_station.dart';
import '../../shared/timetable_notice.dart';
import 'nearby_controller.dart';

/// What the home knows about one direction of a trip.
class DirectionState {
  const DirectionState({this.today, this.tomorrow, this.loading = false, this.failed = false, this.notice});

  final DayTimetable? today;
  final DayTimetable? tomorrow;
  final bool loading;

  /// The last download failed and there is nothing cached to show.
  final bool failed;

  /// The server has no timetable for this trip or day, for example "Sin horarios para
  /// este trayecto". Shown when there is nothing cached.
  final String? notice;

  bool get hasData => today != null || tomorrow != null;
}

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController(this._favorites, this._timetables, this._clock, this.nearby);

  static const tickInterval = Duration(seconds: 20);

  final FavoritesRepository _favorites;
  final TimetableRepository _timetables;
  final Clock _clock;
  final NearbyController nearby;

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
    // Trips can also be saved or removed from the day view.
    ever(_favorites.revision, (_) => _onTripsChanged());
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  @override
  void onReady() {
    super.onReady();
    _timetables.prunePastDays();
    refreshAll();
    nearby.locate(_directions);
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
      nearby.locate(_directions);
    }
  }

  List<TripDirection> get _directions => trips.expand((t) => t.directions).toList();

  /// Saved order, except that the trip with a highlighted card comes first.
  List<FavoriteTrip> get orderedTrips {
    final marked = nearby.highlighted;
    if (marked.isEmpty) return trips;
    bool hit(FavoriteTrip t) => t.directions.any((d) => marked.contains(d.key));
    return [...trips.where(hit), ...trips.where((t) => !hit(t))];
  }

  /// Both directions of [trip], the highlighted one first.
  List<TripDirection> directionsOf(FavoriteTrip trip) {
    final marked = nearby.highlighted;
    return [...trip.directions]..sort((a, b) => (marked.contains(a.key) ? 0 : 1) - (marked.contains(b.key) ? 0 : 1));
  }

  DirectionState stateOf(TripDirection d) => states[d.key] ?? const DirectionState();

  List<Departure> nextOf(TripDirection d, {int count = 3}) {
    final s = stateOf(d);
    return nextDepartures([s.today, s.tomorrow], now.value, count: count);
  }

  /// The train to take at the change station, for trips with a change of line.
  Map<Departure, Departure> connectionsOf(TripDirection d, List<Departure> departures) {
    final s = stateOf(d);
    return findConnections(departures, [s.today, s.tomorrow]);
  }

  /// Name of the change station, if the trip has one.
  String? transferAtOf(TripDirection d) {
    final s = stateOf(d);
    return (s.today?.connection ?? s.tomorrow?.connection)?.stationName;
  }

  /// Fresh cache entries are not downloaded again unless [force] is true.
  Future<void> refreshAll({bool force = false}) async {
    final directions = trips.expand((t) => t.directions).toList();
    final results = await Future.wait(directions.map((d) => _refresh(d, force: force)));
    offline.value = results.contains(false);
  }

  Future<void> openDay(TripDirection d) async {
    nearby.onCardOpened(d);
    await Get.toNamed(Routes.dayView, arguments: d);
    // The day view may have downloaded newer data.
    _loadFromCache();
  }

  Future<void> addTrip() async {
    final trip = await pickTrip();
    if (trip == null) return;
    final (origin, destination) = trip;
    final added = await _favorites.add(
      FavoriteTrip(aId: origin.id, aName: origin.name, bId: destination.id, bName: destination.name),
    );
    if (!added) showMessage('Ese trayecto ya estaba guardado');
  }

  Future<void> deleteTrip(FavoriteTrip trip) => _favorites.remove(trip.id);

  void _onTripsChanged() {
    final known = states.keys.toSet();
    _loadTrips();
    final added = trips.expand((t) => t.directions).where((d) => !known.contains(d.key));
    for (final d in added) {
      _refresh(d, force: false);
    }
    nearby.reevaluate(_directions);
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
        notice: stateOf(d).notice,
      );
    }
    states.assignAll(next);
  }

  /// Returns false when the server could not be reached. A timetable the server does
  /// not have (`no_route`, `date_not_covered`) is a [DirectionState.notice], not a failure.
  Future<bool> _refresh(TripDirection d, {required bool force}) async {
    final before = stateOf(d);
    states[d.key] = DirectionState(
      today: before.today,
      tomorrow: before.tomorrow,
      loading: true,
      notice: before.notice,
    );

    var ok = true;
    final notices = <String?>[null, null];
    Future<DayTimetable?> load(int i, DateTime date, DayTimetable? fallback) async {
      try {
        return await _timetables.get(d.originId, d.destinationId, date, force: force);
      } catch (e) {
        notices[i] = timetableNotice(e);
        if (notices[i] == null) ok = false;
        return fallback;
      }
    }

    final days = await Future.wait([load(0, _today, before.today), load(1, _tomorrow, before.tomorrow)]);
    // The trip may have been deleted while downloading.
    if (!trips.any((t) => t.directions.any((x) => x.key == d.key))) return ok;
    states[d.key] = DirectionState(
      today: days[0],
      tomorrow: days[1],
      failed: !ok && days[0] == null && days[1] == null,
      // Today's notice first: it is the one that matters when nothing is shown.
      notice: notices[0] ?? notices[1],
    );
    return ok;
  }
}
