import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../data/models/station.dart';
import '../modules/station_picker/station_picker_controller.dart';

Future<Station?> pickStation({required String title, String? subtitle, int? excludeId}) async {
  final result = await Get.toNamed(
    Routes.stationPicker,
    arguments: StationPickerArgs(title: title, subtitle: subtitle, excludeId: excludeId),
  );
  return result is Station ? result : null;
}

/// Origin, then destination. Going back from the destination step returns to
/// the origin step; going back from the origin step cancels.
Future<(Station, Station)?> pickTrip() async {
  while (true) {
    final origin = await pickStation(title: '¿Desde dónde sales?');
    if (origin == null) return null;
    final destination = await pickStation(
      title: '¿A dónde vas?',
      subtitle: 'Desde ${origin.name}',
      excludeId: origin.id,
    );
    if (destination != null) return (origin, destination);
  }
}
