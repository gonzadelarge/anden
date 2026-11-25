import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/time_format.dart';
import '../../../data/models/departure.dart';
import '../../../shared/connection_label.dart';
import '../../../shared/train_label.dart';

/// The next departures: the first one large, then the rest, each with its line and
/// destination. [connections] holds the train to take at the change station [transferAt].
class Departures extends StatelessWidget {
  const Departures({
    super.key,
    required this.next,
    required this.now,
    this.connections = const {},
    this.transferAt,
  });

  final List<Departure> next;
  final DateTime now;
  final Map<Departure, Departure> connections;
  final String? transferAt;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final first = next.first;
    final later = next.skip(1);
    final firstConnection = connections[first];
    // The "mañana" tag leaves no room beside the time.
    final connectionBelow = isAfterToday(first.at, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatTime(first.at),
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -1.2,
                color: t.text,
                fontFeatures: tabular,
              ),
            ),
            if (isAfterToday(first.at, now)) ...[
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
            _Tag(label: formatUntil(first.at, now), color: t.accent, background: t.accentSoft),
          ],
        ),
        if (firstConnection != null && connectionBelow) ...[
          const SizedBox(height: 8),
          ConnectionLabel(connection: firstConnection, maxLines: 1),
        ],
        const SizedBox(height: 8),
        TrainLabel(train: first),
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
          // One train per row, because each one has its own label.
          for (final (i, train) in later.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                children: [
                  _LaterTime(time: train.at, now: now, first: first.at),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: TrainLabel(train: train)),
                  if (connections[train] != null) ...[
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: ConnectionLabel(connection: connections[train]!, maxLines: 1)),
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
