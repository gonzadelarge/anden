import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../core/time_format.dart';
import '../data/services/connections.dart';

/// "> 08:28 L9 Riba-roja de Túria", small and grey. One text, so it is cut at
/// the end: the time and the line stay visible when the width is short.
class ConnectionLabel extends StatelessWidget {
  const ConnectionLabel({super.key, required this.connection, required this.maxLines, this.fontSize = 12});

  final Connection connection;
  final int maxLines;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(Icons.subdirectory_arrow_right_rounded, size: fontSize, color: t.faint),
            ),
          ),
          TextSpan(
            text: formatTime(connection.at),
            style: TextStyle(fontWeight: FontWeight.w600, color: t.muted, fontFeatures: tabular),
          ),
          if (connection.line.isNotEmpty)
            TextSpan(text: ' ${connection.line}', style: TextStyle(fontWeight: FontWeight.w600, color: t.muted)),
          TextSpan(text: ' ${connection.destination}'),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, height: 1.25, color: t.faint),
    );
  }
}
