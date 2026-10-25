import 'package:anden/data/models/day_timetable.dart';
import 'package:anden/data/services/next_departures.dart';
import 'package:flutter_test/flutter_test.dart';

DayTimetable day(DateTime date, List<String> times) => DayTimetable(
      originId: 1,
      destinationId: 2,
      date: date,
      fetchedAt: date,
      departures: [
        for (final t in times)
          DateTime(date.year, date.month, date.day, int.parse(t.split(':')[0]), int.parse(t.split(':')[1])),
      ],
    );

void main() {
  final today = day(DateTime(2026, 10, 27), ['05:49', '08:01', '08:07', '08:10', '22:19', '22:49']);
  final tomorrow = day(DateTime(2026, 10, 28), ['05:49', '06:11', '06:19']);

  test('returns the next three trains of today', () {
    final next = nextDepartures([today, tomorrow], DateTime(2026, 10, 27, 8, 0));
    expect(next, [DateTime(2026, 10, 27, 8, 1), DateTime(2026, 10, 27, 8, 7), DateTime(2026, 10, 27, 8, 10)]);
  });

  test('a train leaving this minute still counts', () {
    final next = nextDepartures([today], DateTime(2026, 10, 27, 8, 7, 40), count: 1);
    expect(next, [DateTime(2026, 10, 27, 8, 7)]);
  });

  test('continues into tomorrow late in the evening', () {
    final next = nextDepartures([today, tomorrow], DateTime(2026, 10, 27, 22, 30));
    expect(next, [DateTime(2026, 10, 27, 22, 49), DateTime(2026, 10, 28, 5, 49), DateTime(2026, 10, 28, 6, 11)]);
  });

  test('after the last train only tomorrow is left', () {
    final next = nextDepartures([today, tomorrow], DateTime(2026, 10, 27, 23, 30));
    expect(next.first, DateTime(2026, 10, 28, 5, 49));
  });

  test('night service after midnight comes from the next date', () {
    final saturday = day(DateTime(2026, 10, 31), ['23:18', '23:43']);
    final sunday = day(DateTime(2026, 11, 1), ['00:03', '00:23', '07:00']);
    final next = nextDepartures([saturday, sunday], DateTime(2026, 10, 31, 23, 50));
    expect(next, [DateTime(2026, 11, 1, 0, 3), DateTime(2026, 11, 1, 0, 23), DateTime(2026, 11, 1, 7, 0)]);
  });

  test('missing days are ignored', () {
    expect(nextDepartures([null, null], DateTime(2026, 10, 27)), isEmpty);
    expect(nextDepartures([null, tomorrow], DateTime(2026, 10, 27, 12)).first, DateTime(2026, 10, 28, 5, 49));
  });
}
