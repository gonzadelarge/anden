import 'package:get/get.dart';

import '../incidents/incidents_controller.dart';

enum ShellTab { home, lookup, incidents }

class ShellController extends GetxController {
  final tab = ShellTab.home.obs;

  void select(int index) {
    final next = ShellTab.values[index];
    if (next == ShellTab.incidents) Get.find<IncidentsController>().refreshIfOld();
    tab.value = next;
  }
}
