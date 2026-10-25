import 'dart:convert';
import 'dart:io';

import 'package:anden/data/models/day_timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 27);
  final fetchedAt = DateTime(2026, 10, 25, 9);

  // Real response of horarios-online2 for Amistat (560) -> Colón (552), 27/10/2026.
  Map<String, dynamic> fixture() => jsonDecode(
        File('test/fixtures/horarios_online2_amistat_colon.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  DayTimetable parse(Map<String, dynamic> json) =>
      DayTimetable.fromApi(json, originId: 560, destinationId: 552, date: date, fetchedAt: fetchedAt);

  test('parses the real API response', () {
    final t = parse(fixture());

    expect(t.departures, hasLength(130));
    expect(t.departures.first, DateTime(2026, 10, 27, 5, 49));
    expect(t.departures.last, DateTime(2026, 10, 27, 22, 49));
    expect(t.durationMinutes, 5);
    expect(t.legs, 1);
    expect(t.destinations, ['Aeroport', 'Av. del Cid', 'Torrent Avinguda']);
  });

  test('departures are sorted', () {
    final departures = parse(fixture()).departures;
    expect([...departures]..sort(), departures);
  });

  test('survives a cache round trip', () {
    final original = parse(fixture());
    final copy = DayTimetable.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

    expect(copy.departures, original.departures);
    expect(copy.date, original.date);
    expect(copy.fetchedAt, original.fetchedAt);
    expect(copy.destinations, original.destinations);
    expect(copy.durationMinutes, original.durationMinutes);
  });

  test('empty result gives no departures', () {
    expect(parse({'status': 200, 'error': 0, 'resultado': []}).departures, isEmpty);
  });

  test('hours sent as an empty list give no departures', () {
    final t = parse({
      'resultado': [
        {
          'transbordos': [
            {'horas': [], 'destinos': []},
          ],
        },
      ],
    });
    expect(t.departures, isEmpty);
  });

  test('night service under hour 00 belongs to the same date', () {
    final t = parse({
      'resultado': [
        {
          'transbordos': [
            {
              'horas': {
                '00': ['00:03'],
                '23': ['23:43'],
              },
            },
          ],
        },
      ],
    });
    expect(t.departures, [DateTime(2026, 10, 27, 0, 3), DateTime(2026, 10, 27, 23, 43)]);
  });
}
