import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import '../../core/time_format.dart';
import '../../data/models/incident.dart';
import '../../shared/open_link.dart';
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

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SectionHeader(overline: 'Avisos', title: 'Incidencias')),
                SliverToBoxAdapter(child: _Status(updated: updated, offline: controller.offline.value)),
                if (items.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _emptyState())
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _IncidentCard(incident: items[i], t: t),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + MediaQuery.paddingOf(context).bottom),
                      child: Text('Fuente: metrovalencia.es', style: TextStyle(fontSize: 12, color: t.faint)),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _emptyState() {
    if (controller.updatedAt.value == null) {
      return _Empty(
        icon: Icons.cloud_off_rounded,
        title: controller.loading.value ? 'Cargando…' : 'Sin datos',
        text: controller.loading.value ? '' : 'No se pudieron cargar los avisos.',
      );
    }
    if (!controller.sourceOk.value) {
      return const _Empty(
        icon: Icons.cloud_off_rounded,
        title: 'Avisos no disponibles ahora',
        text: 'Fuente: metrovalencia.es',
      );
    }
    return const _Empty(
      icon: Icons.check_circle_outline_rounded,
      title: 'No hay avisos',
      text: 'Fuente: metrovalencia.es',
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
  const _IncidentCard({required this.incident, required this.t});

  final Incident incident;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final url = incident.url;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url.isEmpty ? null : () => openLink(url),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incident.categoryLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: incident.priority ? t.accent : t.faint,
                ),
              ),
              if (incident.lines.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final line in incident.lines) _LineBadge(number: line, t: t)],
                ),
              ],
              const SizedBox(height: 10),
              Text(incident.title, style: TextStyle(fontSize: 15, height: 1.4, color: t.text)),
              if (url.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Ver en metrovalencia.es',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.accent)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new_rounded, size: 14, color: t.accent),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "L4". Neutral: no official line colours.
class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.number, required this.t});

  final int number;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(
        'L$number',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.background, fontFeatures: tabular),
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
