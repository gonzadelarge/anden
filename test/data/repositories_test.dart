import 'dart:convert';
import 'dart:io';

import 'package:anden/core/clock.dart';
import 'package:anden/data/api/fgv_api.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/repositories/favorites_repository.dart';
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final timetableBody = File('test/fixtures/horarios_online2_amistat_colon.json').readAsStringSync();
  final stationsBody = File('test/fixtures/estaciones_sample.json').readAsStringSync();

  late MemoryStore store;
  late FixedClock clock;
  late List<http.Request> requests;
  late bool serverDown;

  FgvApi api() => FgvApi(
        MockClient((request) async {
          requests.add(request);
          if (serverDown) return http.Response('"Error obteniendo horarios"', 400);
          final body = request.url.path.endsWith('estaciones') ? stationsBody : timetableBody;
          return http.Response.bytes(utf8.encode(body), 200);
        }),
        now: clock.now,
      );

  setUp(() {
    store = MemoryStore();
    clock = FixedClock(DateTime(2026, 10, 27, 8));
    requests = [];
    serverDown = false;
  });

  group('TimetableRepository', () {
    test('sends ids and a DD/MM/YYYY date', () async {
      await TimetableRepository(api(), store, clock).get(560, 552, DateTime(2026, 10, 27));

      expect(requests.single.url.toString(), 'https://www.fgv.es/fgv/app/es/api/v1/V/horarios-online2');
      expect(jsonDecode(requests.single.body), {
        'estacion_origen_id': 560,
        'estacion_destino_id': 552,
        'fecha': '27/10/2026',
      });
    });

    test('uses a fresh cache entry without a request', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(560, 552, DateTime(2026, 10, 27));
      clock.value = clock.value.add(const Duration(hours: 11));
      await repo.get(560, 552, DateTime(2026, 10, 27));

      expect(requests, hasLength(1));
    });

    test('downloads again when the entry is old or forced', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(560, 552, DateTime(2026, 10, 27));
      await repo.get(560, 552, DateTime(2026, 10, 27), force: true);
      clock.value = clock.value.add(const Duration(hours: 13));
      await repo.get(560, 552, DateTime(2026, 10, 27));

      expect(requests, hasLength(3));
    });

    test('throws when the server fails, and keeps the cache', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(560, 552, DateTime(2026, 10, 27));
      serverDown = true;

      await expectLater(
        repo.get(560, 552, DateTime(2026, 10, 27), force: true),
        throwsA(isA<FgvApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
      expect(repo.cached(560, 552, DateTime(2026, 10, 27))?.departures, hasLength(130));
    });

    test('prunes past days only', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(560, 552, DateTime(2026, 10, 26));
      await repo.get(560, 552, DateTime(2026, 10, 27));
      await repo.prunePastDays();

      expect(repo.cached(560, 552, DateTime(2026, 10, 26)), isNull);
      expect(repo.cached(560, 552, DateTime(2026, 10, 27)), isNotNull);
    });
  });

  group('StationRepository', () {
    test('downloads, sorts and caches stations', () async {
      final repo = StationRepository(api(), store, clock);
      final stations = await repo.getStations();

      expect(stations.map((s) => s.name), ['Amistat', 'Àngel Guimerà', 'Benimaclet', 'Colón']);
      final colon = stations.firstWhere((s) => s.name == 'Colón');
      expect(colon.id, 552);
      expect(colon.fgvId, 15);

      await repo.getStations();
      expect(requests, hasLength(1));
      expect(repo.cached(), hasLength(4));
    });

    test('falls back to an old list when offline', () async {
      final repo = StationRepository(api(), store, clock);
      await repo.getStations();
      clock.value = clock.value.add(const Duration(days: 8));
      serverDown = true;

      expect(await repo.getStations(), hasLength(4));
    });
  });

  group('FavoritesRepository', () {
    const trip = FavoriteTrip(aId: 560, aName: 'Amistat', bId: 552, bName: 'Colón');

    test('saves a trip once, in either direction', () async {
      final repo = FavoritesRepository(store);

      expect(await repo.add(trip), isTrue);
      expect(await repo.add(const FavoriteTrip(aId: 552, aName: 'Colón', bId: 560, bName: 'Amistat')), isFalse);
      expect(repo.all(), hasLength(1));
    });

    test('a trip gives both directions', () {
      expect(trip.directions.map((d) => d.key), ['560-552', '552-560']);
    });

    test('revision goes up on every change', () async {
      final repo = FavoritesRepository(store);
      await repo.add(trip);
      await repo.remove(trip.id);

      expect(repo.revision.value, 2);
      expect(repo.contains(trip.id), isFalse);
    });

    test('removes a trip', () async {
      final repo = FavoritesRepository(store);
      await repo.add(trip);
      await repo.remove(trip.id);

      expect(repo.all(), isEmpty);
    });
  });
}
