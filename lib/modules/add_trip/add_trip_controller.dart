import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/text_normalize.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/models/station.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/station_repository.dart';

class AddTripController extends GetxController {
  AddTripController(this._stations, this._favorites);

  final StationRepository _stations;
  final FavoritesRepository _favorites;

  final stations = <Station>[].obs;
  final loading = false.obs;
  final failed = false.obs;
  final query = ''.obs;
  final origin = Rxn<Station>();

  final search = TextEditingController();
  final searchFocus = FocusNode();

  bool get pickingDestination => origin.value != null;

  List<Station> get results {
    final q = query.value;
    final from = origin.value;
    return stations.where((s) => s.id != from?.id && (q.isEmpty || matchesSearch(s.name, q))).toList();
  }

  @override
  void onInit() {
    super.onInit();
    stations.assignAll(_stations.cached());
    load();
  }

  @override
  void onClose() {
    search.dispose();
    searchFocus.dispose();
    super.onClose();
  }

  Future<void> load() async {
    loading.value = true;
    failed.value = false;
    try {
      stations.assignAll(await _stations.getStations());
    } catch (_) {
      failed.value = stations.isEmpty;
    } finally {
      loading.value = false;
    }
  }

  Future<void> select(Station station) async {
    final from = origin.value;
    if (from == null) {
      origin.value = station;
      _clearSearch();
      return;
    }
    final added = await _favorites.add(
      FavoriteTrip(aId: from.id, aName: from.name, bId: station.id, bName: station.name),
    );
    Get.back(result: true);
    if (!added && Get.context != null) {
      ScaffoldMessenger.maybeOf(Get.context!)
          ?.showSnackBar(const SnackBar(content: Text('Ese trayecto ya estaba guardado')));
    }
  }

  /// Back from the destination step goes to the origin step.
  void back() {
    if (origin.value != null) {
      origin.value = null;
      _clearSearch();
    } else {
      Get.back();
    }
  }

  void _clearSearch() {
    search.clear();
    query.value = '';
    searchFocus.requestFocus();
  }
}
