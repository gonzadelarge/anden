import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/clock.dart';
import '../../data/api/anden_server_api.dart';
import '../../data/api/fgv_api.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/favorite_stations_repository.dart';
import '../../data/repositories/home_station_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/learned_places_repository.dart';
import '../../data/repositories/line_repository.dart';
import '../../data/repositories/live_train_repository.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../data/services/location_service.dart';
import '../../data/storage/local_store.dart';

/// App-wide services. They live for the whole app session.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    const clock = Clock();
    final store = GetStorageStore();
    final client = http.Client();
    final api = FgvApi(client, now: clock.now);
    // Off unless the build passes ANDEN_URL and ANDEN_TOKEN (scripts/publish-homepi.sh).
    final server = AndenServerApi(client, now: clock.now);

    Get.put<Clock>(clock, permanent: true);
    Get.put<LocalStore>(store, permanent: true);
    Get.put<FgvApi>(api, permanent: true);
    final stations = Get.put(StationRepository(api, store, clock), permanent: true);
    Get.put(TimetableRepository(api, store, clock, server: server), permanent: true);
    Get.put(FavoritesRepository(store), permanent: true);
    final lines = Get.put(LineRepository(api, store, clock), permanent: true);
    Get.put(LiveTrainRepository(api, stations, lines, clock), permanent: true);
    Get.put(HomeStationRepository(store), permanent: true);
    Get.put(FavoriteStationsRepository(store), permanent: true);
    Get.put(IncidentRepository(api, store, clock), permanent: true);
    Get.put(LearnedPlacesRepository(store, clock), permanent: true);
    Get.put<LocationService>(GeolocatorLocationService(), permanent: true);
  }
}
