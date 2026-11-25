import 'package:get/get.dart';

import '../../data/models/favorite_trip.dart';
import 'day_view_controller.dart';

class DayViewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DayViewController(Get.arguments as TripDirection, Get.find(), Get.find(), Get.find()));
  }
}
