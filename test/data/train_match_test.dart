import 'dart:convert';
import 'dart:io';

import 'package:anden/core/geo.dart';
import 'package:anden/data/models/line.dart';
import 'package:anden/data/models/live_train.dart';
import 'package:anden/data/models/station.dart';
import 'package:anden/data/services/nearby_stations.dart';
import 'package:anden/data/services/train_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 11, 1, h, m, s);
  LiveTrain train(int line, String to, DateTime when) => LiveTrain(line: line, destination: to, at: when);

  group('matchLiveTrains', () {
    const towards = ['Aeroport', 'Torrent Avinguda'];

    test('ignores trains of the other direction even when closer', () {
      final m = matchLiveTrains(
        [at(17, 43)],
        [train(5, 'Marítim', at(17, 43)), train(5, 'Aeroport', at(17, 43, 31))],
        towards,
      );
      expect(m[at(17, 43)]!.destination, 'Aeroport');
    });

    test('leaves a departure without a train inside the tolerance', () {
      expect(matchLiveTrains([at(17, 43)], [train(5, 'Aeroport', at(17, 47))], towards), isEmpty);
    });

    test('uses each train only once', () {
      final m = matchLiveTrains([at(17, 43), at(17, 44)], [train(5, 'Aeroport', at(17, 43))], towards);
      expect(m.keys, [at(17, 43)]);
    });

    test('compares destinations without accents', () {
      expect(matchLiveTrains([at(8, 0)], [train(7, 'Marítim', at(8, 0))], ['Maritim']), hasLength(1));
    });
  });

  test('routeSummary covers missing parts', () {
    expect(routeSummary(['L5', 'L7'], ['Aeroport']), 'L5, L7 hacia Aeroport');
    expect(routeSummary([], ['Aeroport']), 'Hacia Aeroport');
    expect(routeSummary(['L5'], []), 'L5');
    expect(routeSummary([], []), isNull);
  });

  test('LiveTrain parses the real response', () {
    final json = jsonDecode(File('test/fixtures/horarios_prevision_amistat.json').readAsStringSync());
    final trains = LiveTrain.listFromApi(json as Map<String, dynamic>, at(8, 0));
    expect(trains, hasLength(8));
    expect(trains.first.lineName, isNotEmpty);
    expect(trains.first.at.isAfter(at(8, 0)), isTrue);
  });

  test('Line parses stops as estacion_id_FGV', () {
    final line = Line.fromApi(const {'id': 46, 'linea_id_FGV': 5, 'nombre_corto': 'L5', 'stops': '23, 15,x'});
    expect(line.stops, [23, 15]);
    expect(Line.fromJson(line.toJson()).stops, [23, 15]);
    expect(Line.fromJson(const {'id': 46, 'number': 5, 'name': 'L5'}).stops, isEmpty);
  });

  group('nearbyStations', () {
    // At this latitude 0.001 degrees of latitude is about 111 m.
    Station station(int id, double north) =>
        Station(id: id, fgvId: id, name: '$id', latitude: 39.47 + north, longitude: -0.37, interchange: false);
    const here = GeoPoint(39.47, -0.37);
    List<int> ids(List<Station> s) => nearbyStations(here, s).map((n) => n.station.id).toList();

    test('a clear nearest station comes alone', () {
      expect(ids([station(1, 0.001), station(2, 0.01)]), [1]);
    });

    test('stations inside the margin are offered, nearest first', () {
      expect(ids([station(2, 0.003), station(1, 0.001)]), [1, 2]);
    });

    test('at most three', () {
      expect(ids([for (var i = 1; i <= 5; i++) station(i, i * 0.0005)]), [1, 2, 3]);
    });

    test('far from everything it still gives the nearest', () {
      expect(ids([station(1, 0.5), station(2, 0.9)]), [1]);
    });

    test('no stations', () {
      expect(ids([]), isEmpty);
    });
  });
}
