import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_theme.dart';
import '../../data/repositories/station_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../shared/open_link.dart';

/// App, version and the source notes the NAP licence asks for
/// (anden_server docs/public-release.md). No binding: it only reads two repositories.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const napUrl = 'https://www.transportes.gob.es/';
  static const metrovalenciaUrl = 'https://www.metrovalencia.es/';

  /// Newest GTFS feed date known to the app, "24/11/2026". Null before any download.
  static String? feedDate() {
    final dates = [
      Get.find<StationRepository>().feedDate(),
      Get.find<TimetableRepository>().newestFeedDate(),
    ].nonNulls.toList()
      ..sort();
    if (dates.isEmpty) return null;
    final parts = dates.last.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : dates.last;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final date = feedDate();
    final body = TextStyle(fontSize: 15, height: 1.45, color: t.text);
    final note = TextStyle(fontSize: 14, height: 1.45, color: t.muted);

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: t.text)),
          const SizedBox(height: 2),
          Text('Versión $appVersion', style: note),
          const SizedBox(height: 16),
          Text('App no oficial. No tiene relación con FGV ni con Metrovalencia.', style: body),
          _Section(title: 'Horarios', t: t),
          Text(
            'Datos del Punto de Acceso Nacional de transporte (NAP), tratados por esta app. Powered by MITRAMS',
            style: body,
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text('Datos de horarios actualizados el $date', style: note),
          ],
          const SizedBox(height: 8),
          Text('Los horarios son programados y pueden variar.', style: note),
          _Link(label: 'transportes.gob.es', url: napUrl),
          _Section(title: 'Avisos', t: t),
          Text('Avisos de metrovalencia.es', style: body),
          _Link(label: 'metrovalencia.es', url: metrovalenciaUrl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.t});

  final String title;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: t.faint),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => openLink(url),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(label),
      ),
    );
  }
}
