import 'package:get/get.dart';

import '../models/favorite_trip.dart';
import '../storage/local_store.dart';

class FavoritesRepository {
  FavoritesRepository(this._store);

  static const _key = 'favorites';

  final LocalStore _store;

  /// Goes up on every change, so screens can react with `ever(revision, ...)`.
  final revision = 0.obs;

  List<FavoriteTrip> all() {
    final list = _store.read<List>(_key) ?? const [];
    return list.map((f) => FavoriteTrip.fromJson(Map<String, dynamic>.from(f as Map))).toList();
  }

  bool contains(String id) => all().any((f) => f.id == id);

  /// Returns false when the same pair (in any direction) is already saved.
  Future<bool> add(FavoriteTrip trip) async {
    final current = all();
    if (current.any((f) => f.id == trip.id)) return false;
    await _save([...current, trip]);
    return true;
  }

  Future<void> remove(String id) => _save(all().where((f) => f.id != id).toList());

  Future<void> _save(List<FavoriteTrip> trips) async {
    await _store.write(_key, trips.map((f) => f.toJson()).toList());
    revision.value++;
  }
}
