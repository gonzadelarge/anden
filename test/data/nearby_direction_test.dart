import 'package:anden/core/clock.dart';
import 'package:anden/core/geo.dart';
import 'package:anden/data/models/favorite_trip.dart';
import 'package:anden/data/models/learned_place.dart';
import 'package:anden/data/repositories/learned_places_repository.dart';
import 'package:anden/data/services/nearby_direction.dart';
import 'package:anden/data/storage/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

// Real coordinates from GET estaciones (internal ids).
const campanar = GeoPoint(39.4846305847, -0.3950361013); // 569
const aeroport = GeoPoint(39.4923667908, -0.4749194384); // 591
const colon = GeoPoint(39.4701461792, -0.3709277809); // 552
const xativa = GeoPoint(39.4671859741, -0.3773750067); // 553
const beniferri = GeoPoint(39.4910316467, -0.3993369341);

const points = {569: campanar, 591: aeroport, 552: colon, 553: xativa};

const campanarAeroport = FavoriteTrip(aId: 569, aName: 'Campanar', bId: 591, bName: 'Aeroport');
const colonXativa = FavoriteTrip(aId: 552, aName: 'Colón', bId: 553, bName: 'Xàtiva');

GeoPoint north(GeoPoint p, double metres) => GeoPoint(p.latitude + metres / 111195, p.longitude);

GeoPoint middle(GeoPoint a, GeoPoint b) =>
    GeoPoint((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

NearbyResult? pick(GeoPoint here, List<FavoriteTrip> trips, {List<LearnedPlace> learned = const []}) =>
    pickNearbyDirections(
      here: here,
      directions: trips.expand((t) => t.directions).toList(),
      stationPoints: points,
      learned: learned,
    );

void main() {
  test('distance matches the real network', () {
    expect(campanar.distanceTo(aeroport), closeTo(6909, 5));
    expect(colon.distanceTo(xativa), closeTo(644, 5));
    expect(campanar.distanceTo(beniferri), closeTo(802, 5));
  });

  group('station rule', () {
    test('near Campanar marks Campanar → Aeroport', () {
      final r = pick(north(campanar, 200), [campanarAeroport]);
      expect(r?.directionKeys, {'569-591'});
      expect(r?.reason, NearbyReason.station);
    });

    test('near Aeroport marks the other direction', () {
      expect(pick(north(aeroport, 300), [campanarAeroport])?.directionKeys, {'591-569'});
    });

    test('farther than 1 km marks nothing', () {
      expect(pick(north(campanar, 1100), [campanarAeroport]), isNull);
    });

    test('two saved origins about as close marks nothing', () {
      expect(pick(middle(colon, xativa), [colonXativa]), isNull);
    });

    test('a clearly nearer origin wins even with another within 1 km', () {
      // About 50 m from Colón and about 600 m from Xàtiva.
      expect(pick(north(colon, 50), [colonXativa])?.directionKeys, {'552-553'});
    });

    test('works across several trips', () {
      final r = pick(north(colon, 100), [campanarAeroport, colonXativa]);
      expect(r?.directionKeys, {'552-553'});
    });

    test('two trips from the same origin are both marked', () {
      const campanarColon = FavoriteTrip(aId: 569, aName: 'Campanar', bId: 552, bName: 'Colón');
      final r = pick(north(campanar, 100), [campanarAeroport, campanarColon]);
      expect(r?.directionKeys, {'569-591', '569-552'});
    });
  });

  group('learned places', () {
    final work = north(campanar, 3000);
    final learned = [LearnedPlace(point: work, directionKey: '591-569', updatedAt: DateTime(2026, 10, 1))];

    test('used when no saved station is near', () {
      final r = pick(north(work, 100), [campanarAeroport], learned: learned);
      expect(r?.directionKeys, {'591-569'});
      expect(r?.reason, NearbyReason.learnedPlace);
    });

    test('ignored beyond 300 m', () {
      expect(pick(north(work, 400), [campanarAeroport], learned: learned), isNull);
    });

    test('ignored when the trip is no longer saved', () {
      expect(pick(work, [colonXativa], learned: learned), isNull);
    });

    test('the station rule wins over a learned place', () {
      final atStation = [LearnedPlace(point: campanar, directionKey: '591-569', updatedAt: DateTime(2026))];
      expect(pick(campanar, [campanarAeroport], learned: atStation)?.directionKeys, {'569-591'});
    });

    test('resolves the ambiguous spot between two close stations', () {
      final spot = middle(colon, xativa);
      final r = pick(spot, [colonXativa],
          learned: [LearnedPlace(point: spot, directionKey: '553-552', updatedAt: DateTime(2026))]);
      expect(r?.directionKeys, {'553-552'});
    });
  });

  group('LearnedPlacesRepository', () {
    late LearnedPlacesRepository repo;
    late FixedClock clock;

    setUp(() {
      clock = FixedClock(DateTime(2026, 10, 25, 9));
      repo = LearnedPlacesRepository(MemoryStore(), clock);
    });

    test('the latest choice at the same place wins', () async {
      await repo.record(campanar, '569-591');
      clock.value = clock.value.add(const Duration(hours: 1));
      await repo.record(north(campanar, 100), '591-569');

      expect(repo.all().map((p) => p.directionKey), ['591-569']);
    });

    test('keeps separate places and drops the oldest beyond the limit', () async {
      for (var i = 0; i < LearnedPlacesRepository.maxPlaces + 5; i++) {
        clock.value = clock.value.add(const Duration(minutes: 1));
        await repo.record(north(campanar, i * 1000.0), 'k$i');
      }
      final keys = repo.all().map((p) => p.directionKey).toList();
      expect(keys, hasLength(LearnedPlacesRepository.maxPlaces));
      expect(keys.first, 'k${LearnedPlacesRepository.maxPlaces + 4}');
      expect(keys, isNot(contains('k0')));
    });
  });
}
