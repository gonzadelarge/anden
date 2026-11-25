import 'dart:convert';

import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/models/departure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  final fetchedAt = DateTime(2026, 11, 25, 9);

  // Real answers of /v2/timetable for 2026-11-26.
  DayTimetable parse(String file) {
    final json = jsonDecode(fixture(file)) as Map<String, dynamic>;
    return DayTimetable.fromJson({...json, 'date': '20261126', 'fetchedAt': fetchedAt.toIso8601String()});
  }

  test('reads the real server answer with line and destination per train', () {
    final t = parse('timetable_amistat_colon.json');

    expect(t.departures, hasLength(130));
    expect(t.departures.first, Departure(at: DateTime(2026, 11, 26, 5, 49), line: 5, destination: 'Aeroport'));
    expect(t.departures[1].lineName, 'L7');
    expect(t.departures[1].destination, 'Torrent Avinguda');
    expect(t.departures.last.at, DateTime(2026, 11, 26, 22, 49));
    expect(t.durationMinutes, 5);
    expect(t.legs, 1);
    expect(t.destinations, ['Aeroport', 'Av. del Cid', 'Torrent Avinguda']);
    expect(t.feedDate, '2026-11-24');
  });

  test('reads the second leg of a change of line', () {
    final t = parse('timetable_sant_isidre_ribaroja.json');

    expect(t.legs, 2);
    expect(t.connection!.stationId, 25);
    expect(t.connection!.stationName, 'Àngel Guimerà');
    expect(t.connection!.rideMinutes, 8);
    expect(
      t.connection!.departures.first,
      Departure(at: DateTime(2026, 11, 26, 5, 25), line: 9, destination: 'Riba-roja de Túria'),
    );
    expect(t.complete, isTrue);
  });

  test('survives a cache round trip', () {
    for (final file in ['timetable_amistat_colon.json', 'timetable_sant_isidre_ribaroja.json']) {
      final original = parse(file);
      final copy = DayTimetable.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(copy.departures, original.departures);
      expect(copy.date, original.date);
      expect(copy.fetchedAt, original.fetchedAt);
      expect(copy.destinations, original.destinations);
      expect(copy.durationMinutes, original.durationMinutes);
      expect(copy.feedDate, original.feedDate);
      expect(copy.connection?.departures, original.connection?.departures);
      expect(copy.connection?.rideMinutes, original.connection?.rideMinutes);
    }
  });

  DayTimetable day(List<Map<String, dynamic>> departures) => DayTimetable.fromJson({
        'originId': 1,
        'destinationId': 2,
        'date': '20261031',
        'departures': departures,
        'fetchedAt': fetchedAt.toIso8601String(),
      });

  test('night service under hour 00 belongs to the same date and comes first', () {
    final t = day([
      {'time': '23:43', 'line': 5, 'destination': 'Aeroport'},
      {'time': '00:03', 'line': 5, 'destination': 'Aeroport'},
    ]);
    expect(t.departures.map((d) => d.at), [DateTime(2026, 10, 31, 0, 3), DateTime(2026, 10, 31, 23, 43)]);
  });

  test('a line that is not a number has no name', () {
    final t = day([
      {'time': '08:00', 'line': 0, 'destination': 'Aeroport'},
    ]);
    expect(t.departures.single.lineName, isEmpty);
  });
}
