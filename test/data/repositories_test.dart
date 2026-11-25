import 'package:anden/core/clock.dart';
import 'package:anden/data/api/anden_server_api.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/repositories/favorites_repository.dart';
import 'package:anden/data/repositories/incident_repository.dart';
import 'package:anden/data/repositories/station_repository.dart';
import 'package:anden/data/repositories/timetable_repository.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:anden/data/storage/schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  late MemoryStore store;
  late FixedClock clock;
  late FakeServer server;

  AndenServerApi api({String url = FakeServer.url}) =>
      AndenServerApi(server.client, baseUrl: url, token: FakeServer.token, now: clock.now);

  setUp(() {
    store = MemoryStore();
    clock = FixedClock(DateTime(2026, 11, 26, 8));
    server = FakeServer();
  });

  group('TimetableRepository', () {
    final day = DateTime(2026, 11, 26);

    test('asks /v2/timetable with GTFS ids, the token and an ISO date', () async {
      final t = await TimetableRepository(api(), store, clock).get(121, 70, day);

      final request = server.requests.single;
      expect(request.url.toString(), 'https://anden.example.com/v2/timetable?from=121&to=70&date=2026-11-26');
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(t.departures, hasLength(130));
      expect(t.departures.first.lineName, 'L5');
      expect(t.fetchedAt, clock.now());
    });

    test('uses a fresh cache entry without a request', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(121, 70, day);
      clock.value = clock.value.add(const Duration(hours: 11));
      await repo.get(121, 70, day);

      expect(server.requests, hasLength(1));
    });

    test('downloads again when the entry is old or forced', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(121, 70, day);
      await repo.get(121, 70, day, force: true);
      clock.value = clock.value.add(const Duration(hours: 13));
      await repo.get(121, 70, day);

      expect(server.requests, hasLength(3));
    });

    test('throws when offline, and keeps the cache', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(121, 70, day);
      server.down = true;

      await expectLater(
        repo.get(121, 70, day, force: true),
        throwsA(isA<AndenServerException>().having((e) => e.isNoTimetable, 'isNoTimetable', isFalse)),
      );
      expect(repo.cached(121, 70, day)?.departures, hasLength(130));
    });

    test('no_route and date_not_covered come out as such', () async {
      final repo = TimetableRepository(api(), store, clock);
      for (final code in [AndenServerException.noRoute, AndenServerException.dateNotCovered]) {
        server.timetableError = code;
        await expectLater(
          repo.get(121, 70, day),
          throwsA(isA<AndenServerException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.isNoTimetable, 'isNoTimetable', isTrue)),
        );
      }
      expect(repo.cached(121, 70, day), isNull);
    });

    test('without a URL every call fails', () async {
      await expectLater(TimetableRepository(api(url: ''), store, clock).get(121, 70, day), throwsA(isA<AndenServerException>()));
      expect(server.requests, isEmpty);
    });

    test('keeps the change of line with its ride time', () async {
      server.timetableFile = 'timetable_sant_isidre_ribaroja.json';
      final t = await TimetableRepository(api(), store, clock).get(78, 186, day);

      expect(t.legs, 2);
      expect(t.connection!.stationId, 25);
      expect(t.connection!.rideMinutes, 8);
      expect(t.complete, isTrue);
    });

    test('knows the newest feed date of its cache', () async {
      final repo = TimetableRepository(api(), store, clock);
      expect(repo.newestFeedDate(), isNull);
      await repo.get(121, 70, day);
      expect(repo.newestFeedDate(), '2026-11-24');
    });

    test('prunes past days only', () async {
      final repo = TimetableRepository(api(), store, clock);
      await repo.get(121, 70, DateTime(2026, 11, 25));
      await repo.get(121, 70, day);
      await repo.prunePastDays();

      expect(repo.cached(121, 70, DateTime(2026, 11, 25)), isNull);
      expect(repo.cached(121, 70, day), isNotNull);
    });
  });

  group('StationRepository', () {
    test('downloads, sorts and caches stations with their feed date', () async {
      final repo = StationRepository(api(), store, clock);
      final stations = await repo.getStations();

      expect(stations, hasLength(144));
      expect(stations.first.name, 'À Punt');
      final colon = stations.firstWhere((s) => s.name == 'Colón');
      expect(colon.id, 70);
      expect(colon.lines, [3, 5, 7, 9]);
      expect(repo.feedDate(), '2026-11-24');

      await repo.getStations();
      expect(server.requests, hasLength(1));
      expect(repo.cached(), hasLength(144));
    });

    test('"Àngel Guimerà" sorts with the A', () async {
      final names = (await StationRepository(api(), store, clock).getStations()).map((s) => s.name).toList();
      expect(names.indexOf('Àngel Guimerà'), lessThan(names.indexOf('Benimaclet')));
    });

    test('falls back to an old list when offline', () async {
      final repo = StationRepository(api(), store, clock);
      await repo.getStations();
      clock.value = clock.value.add(const Duration(days: 8));
      server.down = true;

      expect(await repo.getStations(), hasLength(144));
    });
  });

  group('IncidentRepository', () {
    test('downloads and caches the notices in the server order', () async {
      final repo = IncidentRepository(api(), store, clock);
      final answer = await repo.fetch();

      expect(answer.ok, isTrue);
      expect(answer.items.map((i) => i.priority), [true, false, false]);
      expect(answer.readAt, DateTime.utc(2026, 11, 25, 20, 47, 55).toLocal());

      final cached = repo.cached()!;
      expect(cached.fetchedAt, clock.now());
      expect(cached.answer.items, hasLength(3));
      expect(cached.answer.items.first.lines, [4]);
    });

    test('throws when offline', () async {
      server.down = true;
      await expectLater(IncidentRepository(api(), store, clock).fetch(), throwsA(isA<AndenServerException>()));
    });
  });

  group('FavoritesRepository', () {
    const trip = FavoriteTrip(aId: 121, aName: 'Amistat', bId: 70, bName: 'Colón');

    test('saves a trip once, in either direction', () async {
      final repo = FavoritesRepository(store);

      expect(await repo.add(trip), isTrue);
      expect(await repo.add(const FavoriteTrip(aId: 70, aName: 'Colón', bId: 121, bName: 'Amistat')), isFalse);
      expect(repo.all(), hasLength(1));
    });

    test('a trip gives both directions', () {
      expect(trip.directions.map((d) => d.key), ['121-70', '70-121']);
    });

    test('revision goes up on every change', () async {
      final repo = FavoritesRepository(store);
      await repo.add(trip);
      await repo.remove(trip.id);

      expect(repo.revision.value, 2);
      expect(repo.contains(trip.id), isFalse);
    });
  });

  group('migrateStore', () {
    test('erases a 1.x box except the two prompt flags, once', () async {
      for (final key in [
        'favorites',
        'home_station',
        'favorite_stations',
        'learned_places',
        'stations',
        'lines',
        'tt:560:552:20261126',
        'incidents',
      ]) {
        await store.write(key, 'old');
      }
      await store.write('location_prompt', 'accepted');
      await store.write('precise_prompt', true);

      await migrateStore(store);
      expect(store.keys.toSet(), {'location_prompt', 'precise_prompt', 'schema'});
      expect(store.read<int>('schema'), storeSchema);
      expect(store.read<String>('location_prompt'), 'accepted');

      await store.write('favorites', const [
        {'aId': 121, 'aName': 'Amistat', 'bId': 70, 'bName': 'Colón'},
      ]);
      await migrateStore(store);
      expect(FavoritesRepository(store).all(), hasLength(1));
    });
  });
}
