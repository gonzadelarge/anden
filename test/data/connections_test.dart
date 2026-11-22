import 'dart:convert';
import 'dart:io';

import 'package:anden/app/theme/app_theme.dart';
import 'package:anden/data/api/fgv_api.dart';
import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/models/live_train.dart';
import 'package:anden/data/services/connections.dart';
import 'package:anden/modules/home/widgets/departures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final date = DateTime(2026, 11, 2);
  DateTime at(int h, int m, [int day = 2]) => DateTime(2026, 11, day, h, m);

  // Real response of horarios-online2 for Sant Isidre (565) -> Riba-roja (593).
  final body = File('test/fixtures/horarios_online2_sant_isidre_ribaroja.json').readAsStringSync();

  DayTimetable parse() => DayTimetable.fromApi(
        jsonDecode(body) as Map<String, dynamic>,
        originId: 565,
        destinationId: 593,
        date: date,
        fetchedAt: date,
      );

  DayTimetable day(DateTime date, List<DateTime> times, {int? ride = 8}) => DayTimetable(
        originId: 565,
        destinationId: 593,
        date: date,
        departures: const [],
        fetchedAt: date,
        legs: 2,
        connection: ConnectionLeg(
          stationId: 554,
          stationName: 'Àngel Guimerà',
          rideMinutes: ride,
          departures: times,
          destinations: const ['Riba-roja de Túria'],
        ),
      );

  test('reads the second leg of the real response', () {
    final t = parse();
    expect(t.legs, 2);
    expect(t.connection!.stationId, 554);
    expect(t.connection!.stationName, 'Àngel Guimerà');
    expect(t.connection!.destinations, ['Riba-roja de Túria']);
    expect(t.connection!.departures, contains(at(8, 28)));
    expect(t.complete, isFalse);
  });

  test('the second leg survives the cache', () {
    final t = DayTimetable.fromJson(jsonDecode(jsonEncode(parse().withRideMinutes(8).toJson())) as Map<String, dynamic>);
    expect(t.connection!.rideMinutes, 8);
    expect(t.connection!.departures, contains(at(8, 28)));
    expect(t.complete, isTrue);
  });

  test('the API asks for the first leg to get its ride time', () async {
    final asked = <String>[];
    final api = FgvApi(MockClient((request) async {
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      asked.add('${json['estacion_origen_id']}-${json['estacion_destino_id']}');
      final answer = json['estacion_destino_id'] == 554
          ? jsonEncode({
              'resultado': [
                {'duracion_minutos': 8, 'transbordos': []},
              ],
            })
          : body;
      return http.Response.bytes(utf8.encode(answer), 200);
    }));

    final t = await api.fetchTimetable(565, 593, date);

    expect(asked, ['565-593', '565-554']);
    expect(t.connection!.rideMinutes, 8);
  });

  group('findConnections', () {
    final days = [
      day(date, [at(8, 28), at(9, 8), at(22, 28)]),
      day(DateTime(2026, 11, 3), [at(1, 8, 3)]),
    ];

    test('takes the first train reachable after the ride and the change', () {
      // 08:15 + 8 min + 2 min = 08:25.
      expect(findConnections([at(8, 15)], days)[at(8, 15)]!.at, at(8, 28));
    });

    test('the limit is inclusive and one minute later is missed', () {
      expect(findConnections([at(8, 18)], days)[at(8, 18)]!.at, at(8, 28));
      expect(findConnections([at(8, 19)], days)[at(8, 19)]!.at, at(9, 8));
    });

    test('continues after midnight', () {
      expect(findConnections([at(22, 25)], days)[at(22, 25)]!.at, at(1, 8, 3));
    });

    test('nothing without a later train or a ride time', () {
      expect(findConnections([at(8, 15)], [day(date, [at(8, 0)])]), isEmpty);
      expect(findConnections([at(8, 15)], [day(date, [at(9, 0)], ride: null)]), isEmpty);
      expect(findConnections([at(8, 15)], [null]), isEmpty);
    });

    test('uses the real-time line when a train matches, the known lines if not', () {
      final live = [const Duration(minutes: 1)]
          .map((d) => LiveTrain(line: 9, destination: 'Riba-roja de Túria', at: at(8, 28).add(d)))
          .toList();
      final m = findConnections([at(8, 15), at(8, 40)], days, live: live, lines: ['L3', 'L9']);
      expect(m[at(8, 15)]!.line, 'L9');
      expect(m[at(8, 40)]!.line, 'L3, L9');
      expect(m[at(8, 40)]!.destination, 'Riba-roja de Túria');
    });
  });

  testWidgets('long names fit on a narrow phone and each train shows its connection', (tester) async {
    final long = Connection(at: at(8, 28), line: 'L3, L5, L9', destination: 'Riba-roja de Túria, Alboraia Peris Aragó');
    final next = [at(8, 15), at(8, 25), at(8, 45)];
    // The test font is about twice as wide as a real one, so this is narrow.
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Departures(
          next: next,
          now: at(8, 0),
          trains: {for (final t in next) t: LiveTrain(line: 1, destination: 'Seminari - CEU', at: t)},
          connections: {for (final t in next) t: long},
          transferAt: 'Àngel Guimerà',
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('08:28', findRichText: true), findsNWidgets(3));
    expect(find.text('Transbordo en Àngel Guimerà'), findsOneWidget);

    // Tomorrow's first train: the "mañana" tag takes the room beside the time.
    tester.view.physicalSize = const Size(600, 600);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Departures(next: next, now: at(8, 0, 1), connections: {for (final t in next) t: long}),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('08:28', findRichText: true), findsNWidgets(3));
  });
}
