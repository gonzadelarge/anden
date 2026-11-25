import 'package:anden/app/routes/app_pages.dart';
import 'package:anden/app/routes/app_routes.dart';
import 'package:anden/app/theme/app_theme.dart';
import 'package:anden/core/clock.dart';
import 'package:anden/core/geo.dart';
import 'package:anden/core/time_format.dart';
import 'package:anden/data/api/anden_server_api.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/models/station.dart';
import 'package:anden/data/repositories/favorites_repository.dart';
import 'package:anden/data/repositories/favorite_stations_repository.dart';
import 'package:anden/data/repositories/home_station_repository.dart';
import 'package:anden/data/repositories/incident_repository.dart';
import 'package:anden/data/repositories/learned_places_repository.dart';
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/services/location_service.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:anden/modules/day_view/day_view_controller.dart';
import 'package:anden/modules/home/go_to_controller.dart';
import 'package:anden/modules/home/home_controller.dart';
import 'package:anden/modules/home/nearby_controller.dart';
import 'package:anden/modules/incidents/incidents_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_server.dart';

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
  // 50 m north of Colón, about 1.8 km from Amistat.
  const nearColon = GeoPoint(39.4705958, -0.3709277809);
  // About 40 m from Amistat, and more than 600 m from any other station.
  const nearAmistat = GeoPoint(39.4707, -0.3504);
  final clock = FixedClock(DateTime(2026, 11, 26, 8, 0));
  const trip = FavoriteTrip(aId: 121, aName: 'Amistat', bId: 70, bName: 'Colón');
  const amistat = Station(id: 121, name: 'Amistat', latitude: 39.4703330994, longitude: -0.3503944576, lines: [5, 7]);
  const colon = Station(id: 70, name: 'Colón', latitude: 39.4701461792, longitude: -0.3709277809, lines: [3, 5, 7, 9]);
  const benimaclet = Station(id: 67, name: 'Benimaclet', latitude: 39.4848518372, longitude: -0.3623333275);

  late FakeServer server;

  Future<void> pumpApp(
    WidgetTester tester, {
    List<FavoriteTrip> trips = const [],
    LocationService? location,
    Station? home,
    List<Station> favoriteStations = const [],
    String timetableFile = 'timetable_amistat_colon.json',
    String? timetableError,
  }) async {
    final store = MemoryStore();
    server = FakeServer(timetableFile: timetableFile)..timetableError = timetableError;
    final api = AndenServerApi(server.client, baseUrl: FakeServer.url, token: FakeServer.token, now: clock.now);
    final favorites = FavoritesRepository(store);
    for (final t in trips) {
      await favorites.add(t);
    }
    Get.put<Clock>(clock);
    Get.put(StationRepository(api, store, clock));
    Get.put(TimetableRepository(api, store, clock));
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

  /// Picks [name] in the open station picker through its search field.
  Future<void> pickInPicker(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
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

  testWidgets('shows both directions with the next departure, its line and destination', (tester) async {
    await pumpApp(tester, trips: [trip]);

    // One route line per card, in both directions.
    final routes = find.textContaining(RegExp('^(Amistat|Colón)￼(Amistat|Colón)\$'), findRichText: true);
    expect(routes, findsNWidgets(2));
    // The fixture serves both directions: next train 08:04 L5 Aeroport, then 08:11 L7, 08:19 L5.
    final first = DateTime(2026, 11, 26, 8, 4);
    expect(find.text(formatTime(first)), findsNWidgets(2));
    expect(find.text(formatUntil(first, clock.now())), findsNWidgets(2));
    expect(find.text('L5'), findsNWidgets(4));
    expect(find.text('L7'), findsNWidgets(2));
    expect(find.text('Torrent Avinguda'), findsNWidgets(2));
  });

  testWidgets('a trip the server has no route for says so instead of failing', (tester) async {
    await pumpApp(tester, trips: [trip], timetableError: AndenServerException.noRoute);
    await tester.pumpAndSettle();

    expect(find.text('Sin horarios para este trayecto'), findsNWidgets(2));
    expect(find.text('Reintentar'), findsNothing);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('a day the feed does not cover says so', (tester) async {
    await pumpApp(tester, trips: [trip], timetableError: AndenServerException.dateNotCovered);
    await tester.pumpAndSettle();

    expect(find.text('Horario aún no publicado para este día'), findsNWidgets(2));
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

  testWidgets('incidents tab shows the count, the category and the lines of each notice', (tester) async {
    // Tall enough for the three notices and the source line.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    // Badge on the bottom bar.
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Incidencias'));
    await tester.pumpAndSettle();
    expect(find.text('INCIDENCIA'), findsOneWidget);
    expect(find.text('SERVICIO ESPECIAL'), findsNWidgets(2));
    expect(find.text('L4'), findsNWidgets(2));
    expect(find.text('L10'), findsOneWidget);
    expect(find.textContaining('Por reorganización del servicio'), findsOneWidget);
    expect(find.text('Ver en metrovalencia.es'), findsNWidgets(2));
    expect(find.text('Fuente: metrovalencia.es'), findsOneWidget);
  });

  testWidgets('"Acerca de" shows the source notes and the feed date', (tester) async {
    await pumpApp(tester, trips: [trip]);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acerca de'));
    await tester.pumpAndSettle();

    expect(find.text('App no oficial. No tiene relación con FGV ni con Metrovalencia.'), findsOneWidget);
    expect(find.textContaining('Powered by MITRAMS'), findsOneWidget);
    expect(find.text('Datos de horarios actualizados el 24/11/2026'), findsOneWidget);
    expect(find.text('Avisos de metrovalencia.es'), findsOneWidget);
  });

  group('go home', () {
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
      // Halfway between Colón and Àngel Guimerà: Xàtiva, Pl. Espanya and Àngel Guimerà are
      // within 400 m of the nearest one. Casa is Amistat.
      await pumpApp(
        tester,
        location: FakeLocation(LocationAccess.granted, const GeoPoint(39.4702243805, -0.3779819459)),
        home: amistat,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Llévame a casa'));
      await tester.pumpAndSettle();

      expect(find.text('¿Desde qué parada sales?'), findsOneWidget);
      expect(find.text('Ver todo el horario'), findsNothing);

      await tester.tap(find.text('Xàtiva'));
      await tester.pumpAndSettle();

      expect(find.text('Xàtiva  →  Amistat'), findsOneWidget);
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
    await pumpApp(tester, timetableFile: 'timetable_sant_isidre_ribaroja.json');
    await tester.pumpAndSettle();

    Get.toNamed(
      Routes.dayView,
      arguments: const TripDirection(
        originId: 78,
        originName: 'Sant Isidre',
        destinationId: 186,
        destinationName: 'Riba-roja de Túria',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Transbordo en Àngel Guimerà'), findsOneWidget);
    expect(find.textContaining('Riba-roja de Túria', findRichText: true), findsWidgets);
    // First leg on its own label, the L9 inside each connection label.
    expect(find.text('L1'), findsWidgets);
    expect(find.textContaining(' L9 ', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('favourite stations', () {
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
      await pickInPicker(tester, 'Colón');

      expect(find.text('Colón  →  Benimaclet'), findsOneWidget);
    });

    testWidgets('a favourite can be added and removed, up to three', (tester) async {
      await pumpApp(tester, location: FakeLocation(LocationAccess.granted, nearAmistat));
      await openFavorites(tester);
      expect(find.text('Añadir estación'), findsOneWidget);

      await tester.tap(find.text('Añadir estación'));
      await tester.pumpAndSettle();
      await pickInPicker(tester, 'Colón');
      expect(find.byTooltip('Quitar Colón'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Colón'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar Colón'), findsNothing);

      final repo = Get.find<FavoriteStationsRepository>();
      for (final (i, id) in [1, 2, 3, 4].indexed) {
        final added = await repo.add(Station(id: id, name: '$id', latitude: 0, longitude: 0));
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
