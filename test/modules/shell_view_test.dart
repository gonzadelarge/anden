import 'dart:convert';
import 'dart:io';

import 'package:anden/app/routes/app_pages.dart';
import 'package:anden/app/routes/app_routes.dart';
import 'package:anden/app/theme/app_theme.dart';
import 'package:anden/core/clock.dart';
import 'package:anden/core/time_format.dart';
import 'package:anden/data/api/fgv_api.dart';
import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/repositories/favorites_repository.dart';
import 'package:anden/data/repositories/incident_repository.dart';
import 'package:anden/data/repositories/line_repository.dart';
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/services/next_departures.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:anden/modules/home/home_controller.dart';
import 'package:anden/modules/incidents/incidents_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
  final timetable = fixture('horarios_online2_amistat_colon.json');
  final incidents = fixture('incidencias.json');
  final lines = fixture('lineas.json');
  final clock = FixedClock(DateTime(2026, 10, 27, 8, 0));
  const trip = FavoriteTrip(aId: 560, aName: 'Amistat', bId: 552, bName: 'Colón');

  Future<void> pumpApp(WidgetTester tester, {List<FavoriteTrip> trips = const []}) async {
    final store = MemoryStore();
    final api = FgvApi(
      MockClient((request) async {
        final path = request.url.path;
        final body = path.endsWith('incidencias')
            ? incidents
            : path.endsWith('lineas')
                ? lines
                : timetable;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
      now: clock.now,
    );
    final favorites = FavoritesRepository(store);
    for (final t in trips) {
      await favorites.add(t);
    }
    Get.put<Clock>(clock);
    Get.put(StationRepository(api, store, clock));
    Get.put(TimetableRepository(api, store, clock));
    Get.put(LineRepository(api, store, clock));
    Get.put(IncidentRepository(api, store, clock));
    Get.put(favorites);

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
}
