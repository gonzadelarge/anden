import 'package:get/get.dart';

import 'add_trip_controller.dart';

class AddTripBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AddTripController(Get.find(), Get.find()));
  }
}
