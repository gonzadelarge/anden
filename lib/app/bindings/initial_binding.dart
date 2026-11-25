import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/clock.dart';
import '../../data/api/anden_server_api.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/favorite_stations_repository.dart';
import '../../data/repositories/home_station_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/learned_places_repository.dart';
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
    // The only data source. Needs ANDEN_URL and ANDEN_TOKEN at build time
    // (--dart-define-from-file=config/anden_server.json, see docs/publishing-homepi.md).
    final api = AndenServerApi(http.Client(), now: clock.now);

    Get.put<Clock>(clock, permanent: true);
    Get.put<LocalStore>(store, permanent: true);
    Get.put<AndenServerApi>(api, permanent: true);
    Get.put(StationRepository(api, store, clock), permanent: true);
    Get.put(TimetableRepository(api, store, clock), permanent: true);
    Get.put(FavoritesRepository(store), permanent: true);
    Get.put(HomeStationRepository(store), permanent: true);
    Get.put(FavoriteStationsRepository(store), permanent: true);
    Get.put(IncidentRepository(api, store, clock), permanent: true);
    Get.put(LearnedPlacesRepository(store, clock), permanent: true);
    Get.put<LocationService>(GeolocatorLocationService(), permanent: true);
  }
}
