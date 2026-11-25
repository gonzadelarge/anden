import '../../core/time_format.dart';

/// One train leaving a station: when, which line and where it goes.
class Departure {
  const Departure({required this.at, required this.line, required this.destination});

  final DateTime at;

  /// Public line number, 5 for L5. 0 when the timetable has no number for it.
  final int line;

  /// Final stop of the train (GTFS `trip_headsign`).
  final String destination;

  /// "L5", or "" when the line is not known.
  String get lineName => line > 0 ? 'L$line' : '';

  /// Reads `{"time": "08:01", "line": 5, "destination": "Aeroport"}` on service date [day].
  /// "00:xx" after the last evening train is night service of the same service date, and
  /// "24:10" rolls over on its own.
  factory Departure.fromJson(Map<String, dynamic> json, DateTime day) {
    final parts = (json['time'] as String).split(':');
    return Departure(
      at: DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1])),
      line: (json['line'] as num?)?.toInt() ?? 0,
      destination: ((json['destination'] as String?) ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {'time': formatTime(at), 'line': line, 'destination': destination};

  /// Sorts by time, then by line.
  static int compare(Departure a, Departure b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.line.compareTo(b.line);
  }

  @override
  bool operator ==(Object other) =>
      other is Departure && other.at == at && other.line == line && other.destination == destination;

  @override
  int get hashCode => Object.hash(at, line, destination);

  @override
  String toString() => '${formatTime(at)} $lineName $destination';
}
