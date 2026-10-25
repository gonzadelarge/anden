import 'package:get/get.dart';

import '../../core/text_normalize.dart';
import '../../data/models/station.dart';
import '../../data/repositories/station_repository.dart';

class StationPickerArgs {
  const StationPickerArgs({required this.title, this.subtitle, this.excludeId});

  final String title;

  /// Small line under the search field, for example "Desde Amistat".
  final String? subtitle;

  /// Station hidden from the list (the origin when picking a destination).
  final int? excludeId;
}

/// Returns the chosen [Station] with `Get.back(result: ...)`, or null.
/// Created by [StationPickerView] itself, not through a binding.
class StationPickerController extends GetxController {
  StationPickerController(this.args, this._stations);

  final StationPickerArgs args;
  final StationRepository _stations;

  final stations = <Station>[].obs;
  final failed = false.obs;
  final query = ''.obs;

  List<Station> get results {
    final q = query.value;
    return stations.where((s) => s.id != args.excludeId && (q.isEmpty || matchesSearch(s.name, q))).toList();
  }

  @override
  void onInit() {
    super.onInit();
    stations.assignAll(_stations.cached());
    load();
  }

  Future<void> load() async {
    failed.value = false;
    try {
      stations.assignAll(await _stations.getStations());
    } catch (_) {
      failed.value = stations.isEmpty;
    }
  }

  void select(Station station) => Get.back(result: station);
}
