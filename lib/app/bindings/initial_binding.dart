import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/clock.dart';
import '../../data/api/fgv_api.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/line_repository.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../data/storage/local_store.dart';

/// App-wide services. They live for the whole app session.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    const clock = Clock();
    final store = GetStorageStore();
    final api = FgvApi(http.Client(), now: clock.now);

    Get.put<Clock>(clock, permanent: true);
    Get.put<LocalStore>(store, permanent: true);
    Get.put<FgvApi>(api, permanent: true);
    Get.put(StationRepository(api, store, clock), permanent: true);
    Get.put(TimetableRepository(api, store, clock), permanent: true);
    Get.put(FavoritesRepository(store), permanent: true);
    Get.put(LineRepository(api, store, clock), permanent: true);
    Get.put(IncidentRepository(api, store, clock), permanent: true);
  }
}
