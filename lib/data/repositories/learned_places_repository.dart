import '../../core/clock.dart';
import '../../core/geo.dart';
import '../models/learned_place.dart';
import '../storage/local_store.dart';

class LearnedPlacesRepository {
  LearnedPlacesRepository(this._store, this._clock);

  static const _key = 'learned_places';

  /// Two positions closer than this are the same place.
  static const samePlaceRadius = 300.0;

  /// Oldest places are dropped beyond this number.
  static const maxPlaces = 30;

  final LocalStore _store;
  final Clock _clock;

  List<LearnedPlace> all() {
    final list = _store.read<List>(_key) ?? const [];
    return list.map((p) => LearnedPlace.fromJson(Map<String, dynamic>.from(p as Map))).toList();
  }

  /// Remembers [directionKey] for [here]. A place already known within
  /// [samePlaceRadius] gets the new direction (the latest choice wins).
  Future<void> record(GeoPoint here, String directionKey) async {
    final places = all().where((p) => p.point.distanceTo(here) > samePlaceRadius).toList()
      ..add(LearnedPlace(point: here, directionKey: directionKey, updatedAt: _clock.now()))
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _store.write(_key, places.take(maxPlaces).map((p) => p.toJson()).toList());
  }
}
