import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/models/station.dart';
import '../../../data/services/nearby_stations.dart';
import '../go_to_controller.dart';
import '../home_controller.dart';
import 'departures.dart';

/// Floating buttons of Inicio: favourite stations and "Llévame a casa".
/// Long press on the second one changes the station marked as casa.
class GoToButtons extends GetView<GoToController> {
  const GoToButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TapRegion(
      onTapOutside: (_) => controller.favoritesOpen.value = false,
      child: Obx(() {
        final searching = controller.searchingFor.value;
        final homeId = controller.homeStation?.id;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (controller.favoritesOpen.value) ...[
              for (final station in controller.favorites) ...[
                _FavoritePill(
                  station: station,
                  onTap: () => _goToFavorite(context, station),
                  onRemove: () => controller.removeFavorite(station),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.canAddFavorite) ...[
                _AddFavoritePill(onTap: controller.addFavorite),
                const SizedBox(height: 8),
              ],
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'favorites',
                  tooltip: 'Estaciones favoritas',
                  onPressed: controller.favoritesOpen.toggle,
                  backgroundColor: t.surface,
                  foregroundColor: t.text,
                  shape: CircleBorder(side: BorderSide(color: t.border)),
                  child: searching != null && searching != homeId
                      ? _Spinner(color: t.text)
                      : Icon(controller.favoritesOpen.value ? Icons.close_rounded : Icons.star_rounded),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onLongPress: controller.changeHome,
                  child: FloatingActionButton(
                    heroTag: 'home',
                    tooltip: 'Llévame a casa',
                    onPressed: () => _goHome(context),
                    backgroundColor: t.accent,
                    foregroundColor: t.onAccent,
                    child: searching != null && searching == homeId
                        ? _Spinner(color: t.onAccent)
                        : const Icon(Icons.home_rounded),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Future<void> _goHome(BuildContext context) async {
    controller.favoritesOpen.value = false;
    final origins = await controller.findOriginsHome();
    final home = controller.homeStation;
    if (origins == null || origins.isEmpty || home == null || !context.mounted) return;
    final origin = origins.length == 1 ? origins.first : await _chooseOrigin(context, origins);
    if (origin == null || !context.mounted) return;
    await _showTrains(context, origin.station, home);
  }

  /// No choice step here: the sheet has a button to change the origin.
  Future<void> _goToFavorite(BuildContext context, Station station) async {
    controller.favoritesOpen.value = false;
    final origins = await controller.findOrigins(station);
    if (origins == null || origins.isEmpty || !context.mounted) return;
    await _showTrains(context, origins.first.station, station);
  }

  Future<void> _showTrains(BuildContext context, Station origin, Station destination) {
    controller.load(origin, destination);
    return showModalBottomSheet<void>(context: context, builder: (_) => const _TrainsSheet());
  }

  Future<NearbyStation?> _chooseOrigin(BuildContext context, List<NearbyStation> origins) {
    final t = AppTokens.of(context);
    return showModalBottomSheet<NearbyStation>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text('¿Desde qué parada sales?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
              ),
              for (final origin in origins)
                ListTile(
                  title: Text(origin.station.name, style: TextStyle(color: t.text)),
                  trailing: Text(formatDistance(origin.distance), style: TextStyle(color: t.muted)),
                  onTap: () => Navigator.pop(sheet, origin),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "350 m", "1,2 km"
String formatDistance(double metres) {
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color));
  }
}

class _FavoritePill extends StatelessWidget {
  const _FavoritePill({required this.station, required this.onTap, required this.onRemove});

  final Station station;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return _Pill(
      onTap: onTap,
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              station.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Quitar ${station.name}',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 16, color: t.faint),
          ),
        ],
      ),
    );
  }
}

class _AddFavoritePill extends StatelessWidget {
  const _AddFavoritePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return _Pill(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 18, color: t.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Añadir estación',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: t.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.onTap, required this.padding, required this.child});

  final VoidCallback onTap;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        color: t.surface,
        shape: StadiumBorder(side: BorderSide(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _TrainsSheet extends GetView<GoToController> {
  const _TrainsSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final home = Get.find<HomeController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Obx(() {
          final d = controller.direction.value;
          if (d == null) return const SizedBox.shrink();
          final now = home.now.value;
          final next = controller.next(now);

          void openDay() {
            Navigator.pop(context);
            Get.toNamed(Routes.dayView, arguments: d);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${d.originName}  →  ${d.destinationName}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
                  ),
                  IconButton(
                    onPressed: controller.changeOrigin,
                    tooltip: 'Cambiar origen',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_location_alt_outlined, size: 20, color: t.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (next.isNotEmpty) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openDay,
                  child: Departures(
                    next: next,
                    now: now,
                    connections: controller.connections(next),
                    transferAt: controller.transferAt,
                  ),
                ),
              ] else
                _status(t),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (controller.goingHome)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        controller.changeHome();
                      },
                      style: TextButton.styleFrom(foregroundColor: t.muted, padding: EdgeInsets.zero),
                      child: const Text('Cambiar casa'),
                    ),
                  const Spacer(),
                  if (next.isNotEmpty) TextButton(onPressed: openDay, child: const Text('Ver todo el horario')),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _status(AppTokens t) {
    if (controller.loading.value) {
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
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          controller.notice.value ??
              (controller.failed.value ? 'No se pudieron cargar los horarios' : 'No hay más trenes hoy'),
          style: TextStyle(color: t.muted),
        ),
      ),
    );
  }
}
