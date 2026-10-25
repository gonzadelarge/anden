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
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/services/next_departures.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:anden/modules/home/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = File('test/fixtures/horarios_online2_amistat_colon.json').readAsStringSync();
  final clock = FixedClock(DateTime(2026, 10, 27, 8, 0));

  Future<void> pumpHome(WidgetTester tester, {List<FavoriteTrip> trips = const []}) async {
    final store = MemoryStore();
    final api = FgvApi(MockClient((_) async => http.Response.bytes(utf8.encode(body), 200)), now: clock.now);
    final favorites = FavoritesRepository(store);
    for (final t in trips) {
      await favorites.add(t);
    }
    Get.put<Clock>(clock);
    Get.put(StationRepository(api, store, clock));
    Get.put(TimetableRepository(api, store, clock));
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
    // Stops the controller's ticker.
    Get.delete<HomeController>(force: true);
    Get.reset();
  });

  testWidgets('shows the empty state without trips', (tester) async {
    await pumpHome(tester);

    expect(find.text('Aún no tienes trayectos'), findsOneWidget);
    expect(find.text('Añadir trayecto'), findsOneWidget);
  });

  testWidgets('shows both directions with the next departure', (tester) async {
    await pumpHome(tester, trips: [const FavoriteTrip(aId: 560, aName: 'Amistat', bId: 552, bName: 'Colón')]);

    final today = DayTimetable.fromApi(
      jsonDecode(body) as Map<String, dynamic>,
      originId: 560,
      destinationId: 552,
      date: clock.today(),
      fetchedAt: clock.now(),
    );
    final first = nextDepartures([today], clock.now()).first;

    // Amistat and Colón each appear once as origin and once as destination.
    expect(find.text('Amistat'), findsNWidgets(2));
    expect(find.text('Colón'), findsNWidgets(2));
    // The fixture serves both directions, so both cards show the same time.
    expect(find.text(formatTime(first)), findsNWidgets(2));
    expect(find.text(formatUntil(first, clock.now())), findsNWidgets(2));
  });
}
