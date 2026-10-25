import 'package:get/get.dart';

import '../home/home_controller.dart';
import '../home/nearby_controller.dart';
import '../incidents/incidents_controller.dart';
import '../lookup/lookup_controller.dart';
import 'shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);
    Get.lazyPut(() => NearbyController(Get.find(), Get.find(), Get.find(), Get.find(), Get.find()));
    Get.lazyPut(() => HomeController(Get.find(), Get.find(), Get.find(), Get.find()));
    Get.lazyPut(LookupController.new);
    Get.lazyPut(() => IncidentsController(Get.find(), Get.find(), Get.find()));
  }
}
