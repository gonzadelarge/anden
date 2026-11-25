import 'package:anden/app/theme/app_theme.dart';
import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/models/departure.dart';
import 'package:anden/data/services/connections.dart';
import 'package:anden/modules/home/widgets/departures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 11, 2);
  DateTime at(int h, int m, [int day = 2]) => DateTime(2026, 11, day, h, m);
  Departure l1(DateTime t) => Departure(at: t, line: 1, destination: 'Seminari - CEU');
  Departure l9(DateTime t) => Departure(at: t, line: 9, destination: 'Riba-roja de Túria');

  DayTimetable day(DateTime date, List<DateTime> times, {int? ride = 8}) => DayTimetable(
        originId: 78,
        destinationId: 186,
        date: date,
        departures: const [],
        fetchedAt: date,
        legs: 2,
        connection: ConnectionLeg(
          stationId: 25,
          stationName: 'Àngel Guimerà',
          rideMinutes: ride,
          departures: times.map(l9).toList(),
          destinations: const ['Riba-roja de Túria'],
        ),
      );

  group('findConnections', () {
    final days = [
      day(date, [at(8, 28), at(9, 8), at(22, 28)]),
      day(DateTime(2026, 11, 3), [at(1, 8, 3)]),
    ];

    DateTime? connect(DateTime t, [List<DayTimetable?>? on]) => findConnections([l1(t)], on ?? days)[l1(t)]?.at;

    test('takes the first train reachable after the ride and the change', () {
      // 08:15 + 8 min + 2 min = 08:25.
      expect(connect(at(8, 15)), at(8, 28));
    });

    test('the limit is inclusive and one minute later is missed', () {
      expect(connect(at(8, 18)), at(8, 28));
      expect(connect(at(8, 19)), at(9, 8));
    });

    test('continues after midnight', () {
      expect(connect(at(22, 25)), at(1, 8, 3));
    });

    test('nothing without a later train or a ride time', () {
      expect(connect(at(8, 15), [day(date, [at(8, 0)])]), isNull);
      expect(connect(at(8, 15), [day(date, [at(9, 0)], ride: null)]), isNull);
      expect(connect(at(8, 15), [null]), isNull);
    });

    test('the connection carries its own line and destination', () {
      final train = findConnections([l1(at(8, 15))], days)[l1(at(8, 15))]!;
      expect(train.lineName, 'L9');
      expect(train.destination, 'Riba-roja de Túria');
    });
  });

  testWidgets('long names fit on a narrow phone and each train shows its connection', (tester) async {
    final long = Departure(at: at(8, 28), line: 9, destination: 'Riba-roja de Túria, Alboraia Peris Aragó');
    final next = [at(8, 15), at(8, 25), at(8, 45)].map(l1).toList();
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
          connections: {for (final t in next) t: long},
          transferAt: 'Àngel Guimerà',
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('08:28', findRichText: true), findsNWidgets(3));
    expect(find.text('L1'), findsNWidgets(3));
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
