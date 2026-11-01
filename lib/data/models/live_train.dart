/// One train from the real-time endpoint, with its estimated arrival.
class LiveTrain {
  const LiveTrain({required this.line, required this.destination, required this.at});

  /// Public line number, 5 for L5.
  final int line;
  final String destination;
  final DateTime at;

  String get lineName => 'L$line';

  /// Parses the body of `GET horarios-prevision-3/{estacion_id_FGV}`.
  static List<LiveTrain> listFromApi(Map<String, dynamic> json, DateTime now) {
    final trains = <LiveTrain>[];
    for (final group in (json['previsiones'] as List).cast<Map<String, dynamic>>()) {
      for (final train in (group['trains'] as List).cast<Map<String, dynamic>>()) {
        final seconds = train['seconds'] as num?;
        final destination = train['destino'] as String?;
        if (seconds == null || destination == null) continue;
        trains.add(LiveTrain(
          line: group['line'] as int,
          destination: destination.trim(),
          at: now.add(Duration(seconds: seconds.toInt())),
        ));
      }
    }
    return trains;
  }
}
