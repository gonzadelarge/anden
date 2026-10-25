import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';

/// Top of each tab: small overline plus a large title, with an optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.overline, required this.title, this.action});

  final String overline;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overline.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: t.faint),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: t.text),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
