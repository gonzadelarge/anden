import 'package:get/get.dart';

import '../models/station.dart';
import '../storage/local_store.dart';

/// The station marked as "casa".
class HomeStationRepository {
  HomeStationRepository(this._store) {
    final json = _store.read<Map>(_key);
    if (json != null) station.value = Station.fromJson(Map<String, dynamic>.from(json));
  }

  static const _key = 'home_station';

  final LocalStore _store;

  final station = Rxn<Station>();

  Future<void> set(Station value) async {
    await _store.write(_key, value.toJson());
    station.value = value;
  }
}
