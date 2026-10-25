import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/time_format.dart';
import '../../../data/models/favorite_trip.dart';
import '../home_controller.dart';

/// One direction of a saved trip with its next departures.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.direction,
    this.highlight,
    required this.state,
    required this.next,
    required this.now,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onRetry,
  });

  final TripDirection direction;

  /// Label shown when the card is highlighted by location ("Cerca de ti").
  final String? highlight;
  final DirectionState state;
  final List<DateTime> next;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: highlight == null ? BorderSide(color: t.border) : BorderSide(color: t.accent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          // Small top/right padding puts the close button in the corner; the
          // body adds the rest back so content keeps a 20 px margin.
          padding: const EdgeInsets.fromLTRB(20, 4, 4, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteLine(direction: direction, highlight: highlight, onDelete: onDelete),
              const SizedBox(height: 2),
              Padding(padding: const EdgeInsets.only(right: 16), child: _body(context, t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppTokens t) {
    if (next.isNotEmpty) {
      return _Departures(next: next, now: now);
    }
    if (state.loading && !state.hasData) {
      return SizedBox(
        height: 52,
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.muted)),
            const SizedBox(width: 12),
            Text('Cargando horarios…', style: TextStyle(color: t.muted)),
          ],
        ),
      );
    }
    if (state.failed) {
      return SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Text('No se pudieron cargar los horarios', style: TextStyle(color: t.muted)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('No hay más trenes hoy', style: TextStyle(color: t.muted)),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.direction, required this.highlight, required this.onDelete});

  final TripDirection direction;
  final String? highlight;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final style = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text, height: 1.2);
    return Row(
      children: [
        // One text for the whole route: it uses all the width up to the close
        // button and is only cut at the end when both names do not fit.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlight != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.near_me_rounded, size: 13, color: t.accent),
                      const SizedBox(width: 4),
                      Text(
                        highlight!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.accent),
                      ),
                    ],
                  ),
                ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: direction.originName),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: t.faint),
                      ),
                    ),
                    TextSpan(text: direction.destinationName),
                  ],
                ),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Eliminar trayecto',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 18, color: t.faint),
        ),
      ],
    );
  }
}

class _Departures extends StatelessWidget {
  const _Departures({required this.next, required this.now});

  final List<DateTime> next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final first = next.first;
    final later = next.skip(1);

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
            const Spacer(),
            _Tag(label: formatUntil(first, now), color: t.accent, background: t.accentSoft),
          ],
        ),
        if (later.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Después', style: TextStyle(fontSize: 13, color: t.faint)),
              for (final time in later) ...[
                const SizedBox(width: 16),
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
            ],
          ),
        ],
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
