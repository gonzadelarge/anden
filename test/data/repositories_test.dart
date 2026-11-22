import 'dart:convert';
import 'dart:io';

import 'package:anden/core/clock.dart';
import 'package:anden/data/api/anden_server_api.dart';
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

  group('TimetableRepository with the own server', () {
    // What the server sends (anden_server docs/plan.md, section 6).
    Map<String, dynamic> serverBody({int legs = 1}) => {
          'originId': 560,
          'destinationId': 552,
          'date': '2026-10-27',
          'departures': ['05:49', '06:11'],
          'durationMinutes': 5,
          'legs': legs,
          'destinations': ['Aeroport'],
          'connection': legs == 1
              ? null
              : {
                  'stationId': 554,
                  'stationName': 'Àngel Guimerà',
                  'rideMinutes': 8,
                  'departures': ['06:05'],
                  'destinations': ['Riba-roja de Túria'],
                },
          'feedDate': '2026-10-26',
        };

    late int serverStatus;
    late Map<String, dynamic> serverAnswer;

    TimetableRepository repo({String url = 'https://anden.example.com'}) {
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'anden.example.com') {
          if (serverStatus != 200) {
            return http.Response('{"error":"no_route","message":"x"}', serverStatus);
          }
          return http.Response.bytes(utf8.encode(jsonEncode(serverAnswer)), 200);
        }
        if (serverDown) return http.Response('"Error obteniendo horarios"', 400);
        return http.Response.bytes(utf8.encode(timetableBody), 200);
      });
      return TimetableRepository(
        FgvApi(client, now: clock.now),
        store,
        clock,
        server: AndenServerApi(client, baseUrl: url, token: 'secret', now: clock.now),
      );
    }

    List<String> hosts() => requests.map((r) => r.url.host).toList();

    setUp(() {
      serverStatus = 200;
      serverAnswer = serverBody();
    });

    test('asks the server first, with the token and an ISO date', () async {
      final t = await repo().get(560, 552, DateTime(2026, 10, 27));

      final request = requests.single;
      expect(request.url.toString(), 'https://anden.example.com/v1/timetable?from=560&to=552&date=2026-10-27');
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(t.departures, [DateTime(2026, 10, 27, 5, 49), DateTime(2026, 10, 27, 6, 11)]);
      expect(t.fetchedAt, clock.now());
      expect(repo().cached(560, 552, DateTime(2026, 10, 27))?.departures, hasLength(2));
    });

    test('asks FGV when the server fails', () async {
      serverStatus = 404;
      final t = await repo().get(560, 552, DateTime(2026, 10, 27));

      expect(hosts(), ['anden.example.com', 'www.fgv.es']);
      expect(t.departures, hasLength(130));
    });

    test('throws the FGV error when both fail, and keeps the cache', () async {
      final r = repo();
      await r.get(560, 552, DateTime(2026, 10, 27));
      serverStatus = 503;
      serverDown = true;

      await expectLater(
        r.get(560, 552, DateTime(2026, 10, 27), force: true),
        throwsA(isA<FgvApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
      expect(r.cached(560, 552, DateTime(2026, 10, 27))?.departures, hasLength(2));
    });

    test('a change of line asks FGV after the server, and keeps FGV', () async {
      serverAnswer = serverBody(legs: 2);
      final t = await repo().get(560, 552, DateTime(2026, 10, 27));

      expect(hosts(), ['anden.example.com', 'www.fgv.es']);
      expect(t.departures, hasLength(130));
    });

    test('a change of line uses the server when FGV fails', () async {
      serverAnswer = serverBody(legs: 2);
      serverDown = true;
      final t = await repo().get(560, 552, DateTime(2026, 10, 27));

      expect(t.legs, 2);
      expect(t.connection!.stationId, 554);
      expect(t.connection!.rideMinutes, 8);
      expect(t.complete, isTrue);
    });

    test('a cached change of line asks FGV first, the server only if FGV fails', () async {
      serverAnswer = serverBody(legs: 2);
      serverDown = true;
      final r = repo();
      await r.get(560, 552, DateTime(2026, 10, 27));
      requests.clear();

      await r.get(560, 552, DateTime(2026, 10, 27), force: true);
      expect(hosts(), ['www.fgv.es', 'anden.example.com']);

      serverDown = false;
      requests.clear();
      await r.get(560, 552, DateTime(2026, 10, 27), force: true);
      expect(hosts(), ['www.fgv.es']);
    });

    test('without a URL the server is off and FGV is asked alone', () async {
      await repo(url: '').get(560, 552, DateTime(2026, 10, 27));

      expect(hosts(), ['www.fgv.es']);
    });

    test('an answer for another date is not used', () async {
      serverAnswer = {...serverBody(), 'date': '2026-10-28'};
      await repo().get(560, 552, DateTime(2026, 10, 27));

      expect(hosts(), ['anden.example.com', 'www.fgv.es']);
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
