import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../core/geo.dart';
import '../../data/models/day_timetable.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/models/departure.dart';
import '../../data/models/station.dart';
import '../../data/repositories/favorite_stations_repository.dart';
import '../../data/repositories/home_station_repository.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../data/services/connections.dart';
import '../../data/services/location_service.dart';
import '../../data/services/nearby_stations.dart';
import '../../data/services/next_departures.dart';
import '../../data/storage/local_store.dart';
import '../../shared/messages.dart';
import '../../shared/pick_station.dart';
import '../../shared/timetable_notice.dart';

/// "Llévame a casa" and favourite stations: trains from the station nearest to
/// the user to a chosen destination.
class GoToController extends GetxController {
  GoToController(
    this._home,
    this._favorites,
    this._stations,
    this._timetables,
    this._location,
    this._store,
    this._clock,
  );

  static const preciseFixTimeout = Duration(seconds: 10);
  static const lastKnownMaxAge = Duration(minutes: 2);
  static const _precisePromptKey = 'precise_prompt';

  final HomeStationRepository _home;
  final FavoriteStationsRepository _favorites;
  final StationRepository _stations;
  final TimetableRepository _timetables;
  final LocationService _location;
  final LocalStore _store;
  final Clock _clock;

  /// Destination being searched, to show progress on its button.
  final searchingFor = Rxn<int>();

  /// True while the favourite stations are shown above the button.
  final favoritesOpen = false.obs;

  /// The direction shown in the sheet and its data.
  final direction = Rxn<TripDirection>();
  final today = Rxn<DayTimetable>();
  final tomorrow = Rxn<DayTimetable>();
  final loading = false.obs;
  final failed = false.obs;

  /// The server has no timetable for this trip or day. See [timetableNotice].
  final notice = Rxn<String>();

  int _requestId = 0;
  Station? _destination;

  Station? get homeStation => _home.station.value;
  List<Station> get favorites => _favorites.stations;
  bool get canAddFavorite => favorites.length < FavoriteStationsRepository.maxStations;

  /// True when the sheet shows the trip to casa.
  bool get goingHome => direction.value?.destinationId == homeStation?.id;

  List<Departure> next(DateTime now) => nextDepartures([today.value, tomorrow.value], now);

  /// The train to take at the change station, for trips with a change of line.
  Map<Departure, Departure> connections(List<Departure> departures) =>
      findConnections(departures, [today.value, tomorrow.value]);

  ConnectionLeg? get _change => today.value?.connection ?? tomorrow.value?.connection;

  /// Name of the change station, if the trip has one.
  String? get transferAt => _change?.stationName;

  Future<void> changeHome() async {
    final station = await pickStation(title: '¿Cuál es tu parada de casa?', subtitle: 'La usará "Llévame a casa"');
    if (station == null) return;
    await _home.set(station);
    showMessage('Casa: ${station.name}');
  }

  Future<void> addFavorite() async {
    final station = await pickStation(title: 'Añadir estación favorita');
    if (station == null) return;
    if (!await _favorites.add(station)) showMessage('Esa estación ya estaba guardada');
  }

  Future<void> removeFavorite(Station station) => _favorites.remove(station.id);

  /// Lets the user leave from any station. The open sheet updates itself.
  Future<void> changeOrigin() async {
    final d = direction.value;
    final destination = _destination;
    if (d == null || destination == null) return;
    final station = await pickStation(
      title: '¿Desde dónde sales?',
      subtitle: 'Hacia ${d.destinationName}',
      excludeId: d.destinationId,
    );
    if (station != null) await load(station, destination);
  }

  /// [findOrigins] for casa, which is asked for first if it is not set.
  Future<List<NearbyStation>?> findOriginsHome() async {
    if (homeStation == null) await changeHome();
    final home = homeStation;
    return home == null ? null : findOrigins(home);
  }

  /// Stations to leave from to reach [destination], nearest first. Null when
  /// there is nothing to show: the user was already told why.
  Future<List<NearbyStation>?> findOrigins(Station destination) async {
    if (searchingFor.value != null) return null;
    final isHome = destination.id == homeStation?.id;

    searchingFor.value = destination.id;
    try {
      final here = await _position();
      if (here == null) return null;

      final List<Station> stations;
      try {
        stations = await _stations.getStations();
      } catch (_) {
        showMessage('No se pudo cargar la lista de paradas');
        return null;
      }
      final nearby = nearbyStations(here, stations);
      if (nearby.isEmpty) {
        showMessage('No se pudo cargar la lista de paradas');
        return null;
      }
      if (nearby.first.station.id == destination.id) {
        showMessage(isHome ? 'Ya estás en tu parada de casa' : 'Ya estás en ${destination.name}');
        return null;
      }
      return nearby.where((s) => s.station.id != destination.id).toList();
    } finally {
      searchingFor.value = null;
    }
  }

  /// Loads the trains from [origin] to [destination]. Cached data appears at once.
  Future<void> load(Station origin, Station destination) async {
    _destination = destination;
    final request = ++_requestId;
    final d = TripDirection(
      originId: origin.id,
      originName: origin.name,
      destinationId: destination.id,
      destinationName: destination.name,
    );
    final day = _clock.today();
    final nextDay = DateTime(day.year, day.month, day.day + 1);

    direction.value = d;
    today.value = _timetables.cached(d.originId, d.destinationId, day);
    tomorrow.value = _timetables.cached(d.originId, d.destinationId, nextDay);
    failed.value = false;
    notice.value = null;
    loading.value = true;

    var ok = true;
    final notices = <String?>[null, null];
    Future<DayTimetable?> fetch(int i, DateTime date, DayTimetable? fallback) async {
      try {
        return await _timetables.get(d.originId, d.destinationId, date);
      } catch (e) {
        notices[i] = timetableNotice(e);
        if (notices[i] == null) ok = false;
        return fallback;
      }
    }

    final days = await Future.wait([fetch(0, day, today.value), fetch(1, nextDay, tomorrow.value)]);
    if (request != _requestId) return;
    today.value = days[0];
    tomorrow.value = days[1];
    failed.value = !ok && days[0] == null && days[1] == null;
    // With data, an empty list means "no more trains today", not a missing timetable.
    notice.value = days[0] == null && days[1] == null ? notices[0] ?? notices[1] : null;
    loading.value = false;
  }

  Future<GeoPoint?> _position() async {
    var access = await _location.access();
    if (access == LocationAccess.notAsked) {
      access = await _location.request() ? LocationAccess.granted : LocationAccess.denied;
    }
    if (access == LocationAccess.serviceOff) {
      showMessage('Activa la ubicación del móvil');
      return null;
    }
    if (access != LocationAccess.granted) {
      showMessage('Permite la ubicación en los ajustes del móvil');
      return null;
    }
    // The phone may have given approximate access before. Ask for more only
    // once: the button also works with approximate.
    if (_store.read<bool>(_precisePromptKey) != true) {
      await _store.write(_precisePromptKey, true);
      await _location.upgradeToPrecise();
    }
    final here = await _location.current(timeout: preciseFixTimeout, precise: true) ??
        await _location.lastKnown(maxAge: lastKnownMaxAge);
    if (here == null) showMessage('No se pudo obtener tu ubicación');
    return here;
  }
}
