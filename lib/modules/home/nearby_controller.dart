import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../core/geo.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/repositories/learned_places_repository.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/services/location_service.dart';
import '../../data/services/nearby_direction.dart';
import '../../data/storage/local_store.dart';

/// Decides which saved cards to highlight from the phone's position.
class NearbyController extends GetxController {
  NearbyController(this._location, this._stations, this._learned, this._store, this._clock);

  /// Android's last known position is used only if it is this recent.
  static const lastKnownMaxAge = Duration(minutes: 2);
  static const freshFixTimeout = Duration(seconds: 6);

  /// An older position is not trusted for highlighting or learning.
  static const positionMaxAge = Duration(minutes: 10);
  static const _promptKey = 'location_prompt';

  final LocationService _location;
  final StationRepository _stations;
  final LearnedPlacesRepository _learned;
  final LocalStore _store;
  final Clock _clock;

  final highlighted = <String>{}.obs;
  final reason = Rxn<NearbyReason>();

  /// Shows the in-app card that explains and asks for location access.
  final promptVisible = false.obs;

  List<TripDirection> _directions = const [];
  GeoPoint? _here;
  DateTime? _hereAt;
  bool _busy = false;

  GeoPoint? get _freshHere {
    final at = _hereAt;
    if (_here == null || at == null || _clock.now().difference(at) > positionMaxAge) return null;
    return _here;
  }

  /// Gets a position and updates [highlighted]. Never blocks the screen:
  /// the cards are already visible and get marked when the position arrives.
  Future<void> locate(List<TripDirection> directions) async {
    _directions = directions;
    if (directions.isEmpty) {
      _clear();
      return;
    }
    final access = await _location.access();
    if (access == LocationAccess.notAsked) {
      promptVisible.value = _store.read<String>(_promptKey) == null;
      return;
    }
    promptVisible.value = false;
    if (access != LocationAccess.granted) {
      _clear();
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      // Instant if Android has a recent position, then refined.
      final last = await _location.lastKnown(maxAge: lastKnownMaxAge);
      if (last != null) await _apply(last);
      final fresh = await _location.current(timeout: freshFixTimeout);
      if (fresh != null) {
        await _apply(fresh);
      } else if (last == null && _freshHere == null) {
        _clear();
      }
    } finally {
      _busy = false;
    }
  }

  /// Saved trips changed: decide again with the position we already have,
  /// or get one (this also shows the prompt after the first saved trip).
  Future<void> reevaluate(List<TripDirection> directions) async {
    final here = _freshHere;
    if (here == null) return locate(directions);
    _directions = directions;
    await _apply(here);
  }

  /// The user opened [direction]. Where the station rule cannot decide (far
  /// from every saved station, or between two), remember this place.
  Future<void> onCardOpened(TripDirection direction) async {
    final here = _freshHere;
    if (here == null) return;
    final points = await _stationPoints();
    if (nearestOrigin(here: here, directions: _directions, stationPoints: points) != null) return;
    await _learned.record(here, direction.key);
  }

  Future<void> enable() async {
    final granted = await _location.request();
    await _store.write(_promptKey, granted ? 'accepted' : 'declined');
    promptVisible.value = false;
    if (granted) await locate(_directions);
  }

  Future<void> dismissPrompt() async {
    await _store.write(_promptKey, 'declined');
    promptVisible.value = false;
  }

  Future<void> _apply(GeoPoint here) async {
    _here = here;
    _hereAt = _clock.now();
    final result = pickNearbyDirections(
      here: here,
      directions: _directions,
      stationPoints: await _stationPoints(),
      learned: _learned.all(),
    );
    highlighted.assignAll(result?.directionKeys ?? const {});
    reason.value = result?.reason;
  }

  Future<Map<int, GeoPoint>> _stationPoints() async {
    var stations = _stations.cached();
    if (stations.isEmpty) {
      try {
        stations = await _stations.getStations();
      } catch (_) {
        // Without coordinates only learned places can be used.
      }
    }
    return {for (final s in stations) s.id: GeoPoint(s.latitude, s.longitude)};
  }

  void _clear() {
    highlighted.clear();
    reason.value = null;
  }
}
