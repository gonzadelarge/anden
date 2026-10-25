import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_theme.dart';
import '../../core/time_format.dart';
import '../../data/models/favorite_trip.dart';
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
            final trips = controller.trips;
            // Read these so Obx rebuilds on every tick and data change.
            final now = controller.now.value;
            controller.states.length;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(now: now, onAdd: controller.addTrip)),
                if (controller.offline.value && trips.isNotEmpty) const SliverToBoxAdapter(child: _OfflineNote()),
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

class _TripGroup extends GetView<HomeController> {
  const _TripGroup({required this.trip, required this.now});

  final FavoriteTrip trip;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, d) in trip.directions.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          TripCard(
            direction: d,
            state: controller.stateOf(d),
            next: controller.nextOf(d),
            now: now,
            onTap: () => controller.openDay(d),
            onLongPress: () => _confirmDelete(context),
            onRetry: () => controller.refreshAll(force: true),
          ),
        ],
      ],
    );
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

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.onAdd});

  final DateTime now;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final day = formatDayLong(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: t.faint),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day[0].toUpperCase()}${day.substring(1)}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: t.text),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAdd,
            tooltip: 'Añadir trayecto',
            style: IconButton.styleFrom(
              backgroundColor: t.surface,
              side: BorderSide(color: t.border),
              fixedSize: const Size(48, 48),
            ),
            icon: Icon(Icons.add_rounded, color: t.text),
          ),
        ],
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
