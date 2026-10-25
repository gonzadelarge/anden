import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import '../../core/time_format.dart';
import '../../data/models/incident.dart';
import '../../shared/section_header.dart';
import 'incidents_controller.dart';

class IncidentsView extends GetView<IncidentsController> {
  const IncidentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: Obx(() {
            final items = controller.items;
            final updated = controller.updatedAt.value;
            controller.lines.length;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SectionHeader(overline: 'Avisos', title: 'Incidencias')),
                SliverToBoxAdapter(child: _Status(updated: updated, offline: controller.offline.value)),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: updated == null
                        ? _Empty(
                            icon: Icons.cloud_off_rounded,
                            title: controller.loading.value ? 'Cargando…' : 'Sin datos',
                            text: controller.loading.value ? '' : 'No se pudieron cargar las incidencias.',
                          )
                        : const _Empty(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Sin incidencias',
                            text: 'El servicio funciona con normalidad.',
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _IncidentCard(incident: items[i], line: controller.lineName(items[i].lineId), t: t),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.updated, required this.offline});

  final DateTime? updated;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final u = updated;
    if (u == null && !offline) return const SizedBox.shrink();
    final text = [
      if (offline) 'Sin conexión',
      if (u != null) 'Actualizado a las ${formatTime(u)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          if (offline) ...[
            Icon(Icons.cloud_off_rounded, size: 16, color: t.muted),
            const SizedBox(width: 8),
          ],
          Text(text, style: TextStyle(fontSize: 13, color: t.muted)),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.line, required this.t});

  final Incident incident;
  final String line;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(
              line.isEmpty ? '—' : line,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.background, fontFeatures: tabular),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (incident.title.isNotEmpty) ...[
                  Text(incident.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                  const SizedBox(height: 4),
                ],
                // No start time: FGV recreates every incident (new id and
                // timestamp) each time it publishes the list.
                Text(incident.text, style: TextStyle(fontSize: 15, height: 1.4, color: t.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: t.faint),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: t.text)),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: t.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
