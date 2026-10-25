import '../../core/clock.dart';
import '../../core/time_format.dart';

/// All departures from one station to another on one service date.
class DayTimetable {
  const DayTimetable({
    required this.originId,
    required this.destinationId,
    required this.date,
    required this.departures,
    required this.fetchedAt,
    this.durationMinutes,
    this.legs = 1,
    this.destinations = const [],
  });

  final int originId;
  final int destinationId;

  /// Service date (time part is zero).
  final DateTime date;

  /// Departure times from the origin, sorted. They belong to [date], including
  /// the night service after midnight that the API lists under hour "00".
  final List<DateTime> departures;
  final DateTime fetchedAt;
  final int? durationMinutes;

  /// More than 1 when the trip needs a change of line. [departures] are then
  /// the departures of the first leg.
  final int legs;

  /// Final destinations of the trains that serve this trip.
  final List<String> destinations;

  /// Parses the body of `POST horarios-online2`.
  factory DayTimetable.fromApi(
    Map<String, dynamic> json, {
    required int originId,
    required int destinationId,
    required DateTime date,
    required DateTime fetchedAt,
  }) {
    final day = dateOnly(date);
    final results = json['resultado'];
    if (results is! List || results.isEmpty) {
      return DayTimetable(
        originId: originId,
        destinationId: destinationId,
        date: day,
        departures: const [],
        fetchedAt: fetchedAt,
      );
    }
    final first = results.first as Map<String, dynamic>;
    final legs = (first['transbordos'] as List?) ?? const [];
    final firstLeg = legs.isEmpty ? const <String, dynamic>{} : legs.first as Map<String, dynamic>;

    final departures = <DateTime>[];
    final hours = firstLeg['horas'];
    // An empty day comes back as [] instead of {}.
    if (hours is Map) {
      for (final times in hours.values) {
        for (final value in times as List) {
          departures.add(_atTime(day, value as String));
        }
      }
    }
    departures.sort();

    return DayTimetable(
      originId: originId,
      destinationId: destinationId,
      date: day,
      departures: departures,
      fetchedAt: fetchedAt,
      durationMinutes: (first['duracion_minutos'] as num?)?.toInt(),
      legs: legs.isEmpty ? 1 : legs.length,
      destinations: ((firstLeg['destinos'] as List?) ?? const []).cast<String>(),
    );
  }

  factory DayTimetable.fromJson(Map<String, dynamic> json) {
    final day = parseDateKey(json['date'] as String);
    return DayTimetable(
      originId: json['originId'] as int,
      destinationId: json['destinationId'] as int,
      date: day,
      departures: (json['departures'] as List).map((t) => _atTime(day, t as String)).toList(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      durationMinutes: json['durationMinutes'] as int?,
      legs: json['legs'] as int? ?? 1,
      destinations: ((json['destinations'] as List?) ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'originId': originId,
        'destinationId': destinationId,
        'date': formatDateKey(date),
        'departures': departures.map(formatTime).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'legs': legs,
        'destinations': destinations,
      };

  static DateTime _atTime(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    // DateTime rolls over on its own if the API ever sends "24:10".
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
