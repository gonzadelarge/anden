import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../data/models/departure.dart';

/// "L5 Aeroport". Neutral text: no official line colours.
class TrainLabel extends StatelessWidget {
  const TrainLabel({super.key, required this.train, this.fontSize = 13, this.color});

  final Departure train;
  final double fontSize;

  /// Colour of the destination. The line uses the main text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        if (train.lineName.isNotEmpty) ...[
          Text(train.lineName, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: t.text)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            train.destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: color ?? t.muted),
          ),
        ),
      ],
    );
  }
}
