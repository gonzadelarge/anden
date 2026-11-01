import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/time_format.dart';
import '../../../data/models/live_train.dart';
import '../../../data/services/connections.dart';
import '../../../shared/connection_label.dart';

/// The next departures: the first one large, then the rest.
///
/// [trains] holds the line and destination of the departures that matched a
/// real-time train. When none did, [summary] says what serves the trip.
/// [connections] holds the train to take at the change station [transferAt].
class Departures extends StatelessWidget {
  const Departures({
    super.key,
    required this.next,
    required this.now,
    this.trains = const {},
    this.summary,
    this.connections = const {},
    this.transferAt,
  });

  final List<DateTime> next;
  final DateTime now;
  final Map<DateTime, LiveTrain> trains;
  final String? summary;
  final Map<DateTime, Connection> connections;
  final String? transferAt;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final first = next.first;
    final later = next.skip(1);
    final firstTrain = trains[first];
    final firstConnection = connections[first];
    final fallback = trains.isEmpty ? summary : null;
    // The "mañana" tag leaves no room beside the time.
    final connectionBelow = isAfterToday(first, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatTime(first),
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -1.2,
                color: t.text,
                fontFeatures: tabular,
              ),
            ),
            if (isAfterToday(first, now)) ...[
              const SizedBox(width: 10),
              _Tag(label: 'mañana', color: t.muted, background: t.background),
            ],
            if (firstConnection != null && !connectionBelow)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ConnectionLabel(connection: firstConnection, maxLines: 3),
                ),
              )
            else
              const Spacer(),
            _Tag(label: formatUntil(first, now), color: t.accent, background: t.accentSoft),
          ],
        ),
        if (firstConnection != null && connectionBelow) ...[
          const SizedBox(height: 8),
          ConnectionLabel(connection: firstConnection, maxLines: 1),
        ],
        if (firstTrain != null) ...[
          const SizedBox(height: 8),
          _TrainLabel(train: firstTrain),
        ],
        if (fallback != null) ...[
          const SizedBox(height: 8),
          Text(fallback, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.muted)),
        ],
        if (transferAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Transbordo en $transferAt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: t.faint),
          ),
        ],
        if (later.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (trains.isEmpty && connections.isEmpty)
            Row(
              children: [
                Text('Después', style: TextStyle(fontSize: 13, color: t.faint)),
                for (final time in later) ...[
                  const SizedBox(width: 16),
                  _LaterTime(time: time, now: now, first: first),
                ],
              ],
            )
          else
            // One train per row, because each one has its own label.
            for (final (i, time) in later.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: Row(
                  children: [
                    _LaterTime(time: time, now: now, first: first),
                    if (trains[time] != null) ...[
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _TrainLabel(train: trains[time]!)),
                    ],
                    if (connections[time] != null) ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: ConnectionLabel(connection: connections[time]!, maxLines: 1)),
                    ],
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

class _LaterTime extends StatelessWidget {
  const _LaterTime({required this.time, required this.now, required this.first});

  final DateTime time;
  final DateTime now;
  final DateTime first;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatTime(time),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: t.muted, fontFeatures: tabular),
        ),
        if (isAfterToday(time, now) && !isAfterToday(first, now))
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('mañana', style: TextStyle(fontSize: 12, color: t.faint)),
          ),
      ],
    );
  }
}

/// "L5 Aeroport". Neutral text: no official line colours.
class _TrainLabel extends StatelessWidget {
  const _TrainLabel({required this.train});

  final LiveTrain train;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        Text(train.lineName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.text)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            train.destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: t.muted),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFeatures: tabular),
      ),
    );
  }
}
