import '../../core/time_format.dart';
import 'departure.dart';

/// The second train of a trip with a change of line.
class ConnectionLeg {
  const ConnectionLeg({
    required this.stationId,
    required this.stationName,
    required this.rideMinutes,
    required this.departures,
    required this.destinations,
  });

  /// The change station ([Station.id]).
  final int stationId;
  final String stationName;

  /// Minutes on the first train. Null when the server did not send it.
  final int? rideMinutes;

  /// Departures from the change station on the same service date, sorted.
  final List<Departure> departures;
  final List<String> destinations;

  Map<String, dynamic> toJson() => {
        'stationId': stationId,
        'stationName': stationName,
        'rideMinutes': rideMinutes,
        'departures': departures.map((d) => d.toJson()).toList(),
        'destinations': destinations,
      };
}

/// All departures from one station to another on one service date.
///
/// The JSON shape is the server's `/v2/timetable` answer (anden_server docs/plan-v2.md,
/// section 4), with the date as a cache key and a `fetchedAt` added by the app.
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
    this.connection,
    this.feedDate,
  });

  final int originId;
  final int destinationId;

  /// Service date (time part is zero).
  final DateTime date;

  /// Departures from the origin, sorted. They belong to [date], including the night
  /// service after midnight that the server lists as "00:xx".
  final List<Departure> departures;
  final DateTime fetchedAt;
  final int? durationMinutes;

  /// More than 1 when the trip needs a change of line. [departures] are then
  /// the departures of the first leg.
  final int legs;

  /// Final destinations of the trains that serve this trip.
  final List<String> destinations;

  /// Second train when [legs] is more than 1. A third train, if any, is not kept.
  final ConnectionLeg? connection;

  /// Date of the GTFS feed the server used, "2026-11-24". Null in old entries.
  final String? feedDate;

  /// False when a change of line lacks data: a cached copy is downloaded again.
  bool get complete => legs <= 1 || connection?.rideMinutes != null;

  factory DayTimetable.fromJson(Map<String, dynamic> json) {
    final day = parseDateKey(json['date'] as String);
    final leg = json['connection'] as Map?;
    return DayTimetable(
      originId: json['originId'] as int,
      destinationId: json['destinationId'] as int,
      date: day,
      departures: _departures(json['departures'], day),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      legs: (json['legs'] as num?)?.toInt() ?? 1,
      destinations: ((json['destinations'] as List?) ?? const []).cast<String>(),
      connection: leg == null
          ? null
          : ConnectionLeg(
              stationId: leg['stationId'] as int,
              stationName: (leg['stationName'] as String).trim(),
              rideMinutes: (leg['rideMinutes'] as num?)?.toInt(),
              departures: _departures(leg['departures'], day),
              destinations: ((leg['destinations'] as List?) ?? const []).cast<String>(),
            ),
      feedDate: json['feedDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'originId': originId,
        'destinationId': destinationId,
        'date': formatDateKey(date),
        'departures': departures.map((d) => d.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'legs': legs,
        'destinations': destinations,
        'connection': connection?.toJson(),
        'feedDate': feedDate,
      };

  static List<Departure> _departures(Object? list, DateTime day) =>
      ((list as List?) ?? const []).map((d) => Departure.fromJson(Map<String, dynamic>.from(d as Map), day)).toList()
        ..sort(Departure.compare);
}
