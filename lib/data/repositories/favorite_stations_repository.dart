import 'package:get/get.dart';

import '../models/station.dart';
import '../storage/local_store.dart';

/// Stations the user wants to reach quickly from Inicio.
class FavoriteStationsRepository {
  FavoriteStationsRepository(this._store) {
    final list = _store.read<List>(_key) ?? const [];
    stations.assignAll(list.map((s) => Station.fromJson(Map<String, dynamic>.from(s as Map))));
  }

  static const _key = 'favorite_stations';
  static const maxStations = 3;

  final LocalStore _store;

  final stations = <Station>[].obs;

  /// Returns false when the station is already saved or the list is full.
  Future<bool> add(Station station) async {
    if (stations.length >= maxStations || stations.any((s) => s.id == station.id)) return false;
    stations.add(station);
    await _save();
    return true;
  }

  Future<void> remove(int id) async {
    stations.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> _save() => _store.write(_key, stations.map((s) => s.toJson()).toList());
}
