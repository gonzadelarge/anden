import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_theme.dart';
import '../../core/time_format.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/services/nearby_direction.dart';
import '../../shared/section_header.dart';
import 'home_controller.dart';
import 'widgets/trip_card.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refreshAll(force: true),
          child: Obx(() {
            final trips = controller.orderedTrips;
            // Read these so Obx rebuilds on every tick and data change.
            final now = controller.now.value;
            controller.states.length;
            controller.nearby.highlighted.length;
            controller.nearby.reason.value;
            final showPrompt = controller.nearby.promptVisible.value && trips.isNotEmpty;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(context, now)),
                if (controller.offline.value && trips.isNotEmpty) const SliverToBoxAdapter(child: _OfflineNote()),
                if (showPrompt) const SliverToBoxAdapter(child: _LocationPrompt()),
                if (trips.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _EmptyState(onAdd: controller.addTrip))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: trips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 28),
                      itemBuilder: (context, i) => _TripGroup(trip: trips[i], now: now),
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

Widget _header(BuildContext context, DateTime now) {
  final t = AppTokens.of(context);
  final day = formatDayLong(now);
  return SectionHeader(
    overline: appName,
    title: '${day[0].toUpperCase()}${day.substring(1)}',
    action: IconButton(
      onPressed: Get.find<HomeController>().addTrip,
      tooltip: 'Añadir trayecto',
      style: IconButton.styleFrom(
        backgroundColor: t.surface,
        side: BorderSide(color: t.border),
        fixedSize: const Size(48, 48),
      ),
      icon: Icon(Icons.add_rounded, color: t.text),
    ),
  );
}

class _TripGroup extends GetView<HomeController> {
  const _TripGroup({required this.trip, required this.now});

  final FavoriteTrip trip;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, d) in controller.directionsOf(trip).indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          TripCard(
            direction: d,
            highlight: _highlightLabel(d),
            state: controller.stateOf(d),
            next: controller.nextOf(d),
            now: now,
            onTap: () => controller.openDay(d),
            onLongPress: () => _confirmDelete(context),
            onDelete: () => _confirmDelete(context),
            onRetry: () => controller.refreshAll(force: true),
          ),
        ],
      ],
    );
  }

  String? _highlightLabel(TripDirection d) {
    if (!controller.nearby.highlighted.contains(d.key)) return null;
    return controller.nearby.reason.value == NearbyReason.learnedPlace ? 'Lo sueles mirar aquí' : 'Cerca de ti';
  }

  void _confirmDelete(BuildContext context) {
    final t = AppTokens.of(context);
    Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${trip.aName}  ⇄  ${trip.bName}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
              const SizedBox(height: 6),
              Text('Se eliminarán los dos sentidos del trayecto.', style: TextStyle(color: t.muted)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Get.back<void>();
                    controller.deleteTrip(trip);
                  },
                  child: const Text('Eliminar trayecto'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Get.back<void>(), child: const Text('Cancelar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPrompt extends GetView<HomeController> {
  const _LocationPrompt();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final nearby = controller.nearby;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
        decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(radius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.near_me_rounded, size: 20, color: t.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Destacar el trayecto según dónde estés',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                      const SizedBox(height: 4),
                      Text(
                        'Usa tu ubicación aproximada para poner primero la tarjeta que te interesa. '
                        'La ubicación no sale del móvil.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: nearby.dismissPrompt,
                  style: TextButton.styleFrom(foregroundColor: t.muted),
                  child: const Text('Ahora no'),
                ),
                TextButton(onPressed: nearby.enable, child: const Text('Activar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: t.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Sin conexión. Se muestran los horarios guardados.',
                style: TextStyle(fontSize: 13, color: t.muted)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 40, color: t.faint),
          const SizedBox(height: 16),
          Text('Aún no tienes trayectos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: t.text)),
          const SizedBox(height: 8),
          Text(
            'Guarda tu viaje habitual y verás los próximos trenes nada más abrir la app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Añadir trayecto'),
          ),
        ],
      ),
    );
  }
}
