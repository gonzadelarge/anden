import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/models/station.dart';
import '../../shared/pick_station.dart';

/// "Horarios" tab: look up any trip without saving it.
class LookupController extends GetxController {
  final origin = Rxn<Station>();
  final destination = Rxn<Station>();

  bool get ready => origin.value != null && destination.value != null;

  Future<void> pickOrigin() async {
    final s = await pickStation(title: 'Origen', excludeId: destination.value?.id);
    if (s != null) origin.value = s;
  }

  Future<void> pickDestination() async {
    final from = origin.value;
    final s = await pickStation(
      title: 'Destino',
      subtitle: from == null ? null : 'Desde ${from.name}',
      excludeId: from?.id,
    );
    if (s != null) destination.value = s;
  }

  void swap() {
    final o = origin.value;
    origin.value = destination.value;
    destination.value = o;
  }

  void open() {
    final o = origin.value;
    final d = destination.value;
    if (o == null || d == null) return;
    Get.toNamed(
      Routes.dayView,
      arguments: TripDirection(originId: o.id, originName: o.name, destinationId: d.id, destinationName: d.name),
    );
  }
}
