import 'dart:convert';
import 'dart:io';

import 'package:anden/app/routes/app_pages.dart';
import 'package:anden/app/routes/app_routes.dart';
import 'package:anden/app/theme/app_theme.dart';
import 'package:anden/core/clock.dart';
import 'package:anden/core/geo.dart';
import 'package:anden/core/time_format.dart';
import 'package:anden/data/api/fgv_api.dart';
import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/models/station.dart';
import 'package:anden/data/repositories/favorites_repository.dart';
import 'package:anden/data/repositories/favorite_stations_repository.dart';
import 'package:anden/data/repositories/home_station_repository.dart';
import 'package:anden/data/repositories/incident_repository.dart';
import 'package:anden/data/repositories/learned_places_repository.dart';
import 'package:anden/data/repositories/line_repository.dart';
import 'package:anden/data/repositories/live_train_repository.dart';
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/services/location_service.dart';
import 'package:anden/data/services/next_departures.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:anden/modules/day_view/day_view_controller.dart';
import 'package:anden/modules/home/go_to_controller.dart';
import 'package:anden/modules/home/home_controller.dart';
import 'package:anden/modules/home/nearby_controller.dart';
import 'package:anden/modules/incidents/incidents_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeLocation implements LocationService {
  FakeLocation(this.state, [this.point]);

  LocationAccess state;
  GeoPoint? point;
  bool requested = false;
  bool preciseAsked = false;
  int upgradeCalls = 0;

  @override
  Future<LocationAccess> access() async => state;

  @override
  Future<bool> request() async {
    requested = true;
    state = LocationAccess.granted;
    return true;
  }

  @override
  Future<GeoPoint?> lastKnown({required Duration maxAge}) async => point;

  @override
  Future<GeoPoint?> current({required Duration timeout, bool precise = false}) async {
    if (precise) preciseAsked = true;
    return point;
  }

  @override
  Future<void> upgradeToPrecise() async => upgradeCalls++;
}

void main() {
  String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
  final timetable = fixture('horarios_online2_amistat_colon.json');
  final incidents = fixture('incidencias.json');
  final lines = fixture('lineas.json');
  final stations = fixture('estaciones_sample.json');
  final live = fixture('horarios_prevision_amistat.json');
  // 50 m north of Colón, about 1.8 km from Amistat.
  const nearColon = GeoPoint(39.4705958, -0.3709277809);
  final clock = FixedClock(DateTime(2026, 10, 27, 8, 0));
  const trip = FavoriteTrip(aId: 560, aName: 'Amistat', bId: 552, bName: 'Colón');

  Future<void> pumpApp(
    WidgetTester tester, {
    List<FavoriteTrip> trips = const [],
    LocationService? location,
    Station? home,
    List<Station> favoriteStations = const [],
    bool liveOnline = true,
    String? timetableBody,
  }) async {
    final store = MemoryStore();
    final api = FgvApi(
      MockClient((request) async {
        final path = request.url.path;
        if (path.contains('horarios-prevision')) {
          return liveOnline ? http.Response.bytes(utf8.encode(live), 200) : http.Response('down', 500);
        }
        final body = path.endsWith('incidencias')
            ? incidents
            : path.endsWith('lineas')
                ? lines
                : path.endsWith('estaciones')
                    ? stations
                    : timetableBody ?? timetable;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
      now: clock.now,
    );
    final favorites = FavoritesRepository(store);
    for (final t in trips) {
      await favorites.add(t);
    }
    Get.put<Clock>(clock);
    final stationRepo = Get.put(StationRepository(api, store, clock));
    Get.put(TimetableRepository(api, store, clock));
    final lineRepo = Get.put(LineRepository(api, store, clock));
    Get.put(LiveTrainRepository(api, stationRepo, lineRepo, clock));
    final homeRepo = Get.put(HomeStationRepository(store));
    if (home != null) await homeRepo.set(home);
    final favoriteRepo = Get.put(FavoriteStationsRepository(store));
    for (final s in favoriteStations) {
      await favoriteRepo.add(s);
    }
    Get.put(IncidentRepository(api, store, clock));
    Get.put(favorites);
    Get.put(LearnedPlacesRepository(store, clock));
    Get.put<LocalStore>(store);
    Get.put<LocationService>(location ?? FakeLocation(LocationAccess.denied));

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light(),
      initialRoute: Routes.home,
      getPages: AppPages.pages,
    ));
    await tester.pump();
    await tester.pump();
  }

  tearDown(() {
    // Stops the tickers and lifecycle observers.
    Get.delete<HomeController>(force: true);
    Get.delete<IncidentsController>(force: true);
    Get.delete<NearbyController>(force: true);
    Get.delete<GoToController>(force: true);
    Get.delete<DayViewController>(force: true);
    Get.reset();
  });

  testWidgets('shows the empty state without trips', (tester) async {
    await pumpApp(tester);

    expect(find.text('Aún no tienes trayectos'), findsOneWidget);
    expect(find.text('Añadir trayecto'), findsOneWidget);
  });

  testWidgets('shows both directions with the next departure', (tester) async {
    await pumpApp(tester, trips: [trip]);

    final today = DayTimetable.fromApi(
      jsonDecode(timetable) as Map<String, dynamic>,
      originId: 560,
      destinationId: 552,
      date: clock.today(),
      fetchedAt: clock.now(),
    );
    final first = nextDepartures([today], clock.now()).first;

    // One route line per card, in both directions.
    final routes = find.textContaining(RegExp('^(Amistat|Colón)￼(Amistat|Colón)\$'), findRichText: true);
    expect(routes, findsNWidgets(2));
    // The fixture serves both directions, so both cards show the same time.
    expect(find.text(formatTime(first)), findsNWidgets(2));
    expect(find.text(formatUntil(first, clock.now())), findsNWidgets(2));
  });

  testWidgets('the x on a card deletes the trip after confirming', (tester) async {
    await pumpApp(tester, trips: [trip]);

    await tester.tap(find.byTooltip('Eliminar trayecto').first);
    await tester.pumpAndSettle();
    expect(find.text('Se eliminarán los dos sentidos del trayecto.'), findsOneWidget);
    // The sheet must be opaque, or the bottom bar shows through it.
    final sheet = tester.widget<Material>(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first,
    );
    expect(sheet.color, AppTokens.light.surface);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar trayecto'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes trayectos'), findsOneWidget);
  });

  testWidgets('incidents tab shows the count and the line of each incident', (tester) async {
    await pumpApp(tester);

    // Badge on the bottom bar.
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Incidencias'));
    await tester.pumpAndSettle();
    expect(find.text('L4'), findsNWidgets(2));
    expect(find.text('L6'), findsOneWidget);
    expect(find.textContaining('Empalme y Dr. Lluch'), findsOneWidget);
  });

  group('line and destination', () {
    testWidgets('a matched train shows its line and destination', (tester) async {
      await pumpApp(tester, trips: [trip]);
      await tester.pumpAndSettle();

      // Real times from the fixture: an L5 to Aeroport about 10 min after 08:00.
      expect(find.text('L5'), findsWidgets);
      expect(find.text('Aeroport'), findsWidgets);
    });

    testWidgets('without real time the card shows the general line', (tester) async {
      await pumpApp(tester, trips: [trip], liveOnline: false);
      await tester.pumpAndSettle();

      expect(find.text('L5, L7 hacia Aeroport, Av. del Cid, Torrent Avinguda'), findsWidgets);
    });
  });

  group('go home', () {
    const colon = Station(id: 552, fgvId: 15, name: 'Colón', latitude: 39.47, longitude: -0.37, interchange: true);
    const amistat =
        Station(id: 560, fgvId: 23, name: 'Amistat', latitude: 39.47, longitude: -0.35, interchange: false);
    // About 40 m from Amistat, and more than 400 m from the other sample stations.
    const nearAmistat = GeoPoint(39.4707, -0.3504);

    testWidgets('one nearby station goes straight to the next trains', (tester) async {
      final location = FakeLocation(LocationAccess.granted, nearAmistat);
      await pumpApp(tester, location: location, home: colon);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Llévame a casa'));
      await tester.pumpAndSettle();

      expect(location.preciseAsked, isTrue);
      expect(location.upgradeCalls, 1);
      expect(find.text('Amistat  →  Colón'), findsOneWidget);
      expect(find.text('Ver todo el horario'), findsOneWidget);
    });

    testWidgets('two stations about as close are offered before any trains', (tester) async {
      // Halfway between Colón and Àngel Guimerà. Casa is Amistat.
      await pumpApp(tester, location: FakeLocation(LocationAccess.granted, const GeoPoint(39.4702243805, -0.3779819459)), home: amistat);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Llévame a casa'));
      await tester.pumpAndSettle();

      expect(find.text('¿Desde qué parada sales?'), findsOneWidget);
      expect(find.text('Ver todo el horario'), findsNothing);

      await tester.tap(find.text('Colón'));
      await tester.pumpAndSettle();

      expect(find.text('Colón  →  Amistat'), findsOneWidget);
      expect(find.text('Ver todo el horario'), findsOneWidget);
    });

    testWidgets('being at the home station says so', (tester) async {
      await pumpApp(tester, location: FakeLocation(LocationAccess.granted, nearAmistat), home: amistat);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Llévame a casa'));
      await tester.pumpAndSettle();

      expect(find.text('Ya estás en tu parada de casa'), findsOneWidget);
    });

    testWidgets('without a home station it opens the picker first', (tester) async {
      await pumpApp(tester, location: FakeLocation(LocationAccess.granted, nearAmistat));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Llévame a casa'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cuál es tu parada de casa?'), findsOneWidget);
    });
  });

  testWidgets('the day view shows the second train of a trip with a change', (tester) async {
    await pumpApp(tester, timetableBody: fixture('horarios_online2_sant_isidre_ribaroja.json'));
    await tester.pumpAndSettle();

    Get.toNamed(
      Routes.dayView,
      arguments: const TripDirection(
        originId: 565,
        originName: 'Sant Isidre',
        destinationId: 593,
        destinationName: 'Riba-roja de Túria',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Transbordo en Àngel Guimerà'), findsOneWidget);
    expect(find.textContaining('Riba-roja de Túria', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('favourite stations', () {
    const benimaclet =
        Station(id: 226, fgvId: 12, name: 'Benimaclet', latitude: 39.48, longitude: -0.36, interchange: true);
    // About 40 m from Amistat.
    const nearAmistat = GeoPoint(39.4707, -0.3504);

    Future<void> openFavorites(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Estaciones favoritas'));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a favourite shows trains from the nearest station', (tester) async {
      await pumpApp(
        tester,
        location: FakeLocation(LocationAccess.granted, nearAmistat),
        favoriteStations: [benimaclet],
      );
      await openFavorites(tester);

      await tester.tap(find.text('Benimaclet'));
      await tester.pumpAndSettle();

      expect(find.text('Amistat  →  Benimaclet'), findsOneWidget);
      expect(find.text('Cambiar casa'), findsNothing);
    });

    testWidgets('the small button changes the origin in the open card', (tester) async {
      await pumpApp(
        tester,
        location: FakeLocation(LocationAccess.granted, nearAmistat),
        favoriteStations: [benimaclet],
      );
      await openFavorites(tester);
      await tester.tap(find.text('Benimaclet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cambiar origen'));
      await tester.pumpAndSettle();
      expect(find.text('¿Desde dónde sales?'), findsOneWidget);
      await tester.tap(find.text('Colón'));
      await tester.pumpAndSettle();

      expect(find.text('Colón  →  Benimaclet'), findsOneWidget);
    });

    testWidgets('a favourite can be added and removed, up to three', (tester) async {
      await pumpApp(tester, location: FakeLocation(LocationAccess.granted, nearAmistat));
      await openFavorites(tester);
      expect(find.text('Añadir estación'), findsOneWidget);

      await tester.tap(find.text('Añadir estación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colón'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar Colón'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Colón'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar Colón'), findsNothing);

      final repo = Get.find<FavoriteStationsRepository>();
      for (final (i, id) in [1, 2, 3, 4].indexed) {
        final added = await repo.add(Station(id: id, fgvId: id, name: '$id', latitude: 0, longitude: 0, interchange: false));
        expect(added, i < 3);
      }
      await tester.pump();
      expect(find.text('Añadir estación'), findsNothing);
    });
  });

  group('location', () {
    Finder route(String from, String to) =>
        find.textContaining(RegExp('^$from￼$to\$'), findRichText: true);

    testWidgets('without location the saved order stays and nothing is marked', (tester) async {
      await pumpApp(tester, trips: [trip]);

      expect(tester.getTopLeft(route('Amistat', 'Colón')).dy, lessThan(tester.getTopLeft(route('Colón', 'Amistat')).dy));
      expect(find.text('Cerca de ti'), findsNothing);
      expect(find.text('Activar'), findsNothing);
    });

    testWidgets('near Colón the Colón card moves to the top and is marked', (tester) async {
      await pumpApp(tester, trips: [trip], location: FakeLocation(LocationAccess.granted, nearColon));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(route('Colón', 'Amistat')).dy, lessThan(tester.getTopLeft(route('Amistat', 'Colón')).dy));
      expect(find.text('Cerca de ti'), findsOneWidget);
    });

    testWidgets('asks once with an in-app card before the system dialog', (tester) async {
      final location = FakeLocation(LocationAccess.notAsked, nearColon);
      await pumpApp(tester, trips: [trip], location: location);
      await tester.pumpAndSettle();
      expect(find.text('Destacar el trayecto según dónde estés'), findsOneWidget);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();

      expect(location.requested, isTrue);
      expect(find.text('Destacar el trayecto según dónde estés'), findsNothing);
      expect(find.text('Cerca de ti'), findsOneWidget);
    });

    testWidgets('"Ahora no" hides the card for good', (tester) async {
      await pumpApp(tester, trips: [trip], location: FakeLocation(LocationAccess.notAsked));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Activar'), findsNothing);

      await Get.find<NearbyController>().locate(trip.directions);
      await tester.pump();
      expect(find.text('Activar'), findsNothing);
    });

    testWidgets('opening a card far from saved stations learns the place', (tester) async {
      const office = GeoPoint(39.50, -0.42);
      await pumpApp(tester, trips: [trip], location: FakeLocation(LocationAccess.granted, office));
      await tester.pumpAndSettle();
      expect(find.text('Cerca de ti'), findsNothing);

      await Get.find<NearbyController>().onCardOpened(trip.directions.last);
      await Get.find<NearbyController>().locate(trip.directions);
      await tester.pump();

      expect(find.text('Lo sueles mirar aquí'), findsOneWidget);
      expect(tester.getTopLeft(route('Colón', 'Amistat')).dy, lessThan(tester.getTopLeft(route('Amistat', 'Colón')).dy));
    });
  });
}
