import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home/home_view.dart';
import '../incidents/incidents_controller.dart';
import '../incidents/incidents_view.dart';
import '../lookup/lookup_view.dart';
import 'shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final incidents = Get.find<IncidentsController>();
    return Obx(() {
      final count = incidents.items.length;
      return Scaffold(
        // All tabs stay alive, so switching keeps their state and data.
        body: IndexedStack(
          index: controller.tab.value.index,
          children: const [HomeView(), LookupView(), IncidentsView()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.tab.value.index,
          onDestinationSelected: controller.select,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            const NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule_rounded),
              label: 'Horarios',
            ),
            NavigationDestination(
              icon: Badge.count(count: count, isLabelVisible: count > 0, child: const Icon(Icons.info_outline_rounded)),
              selectedIcon:
                  Badge.count(count: count, isLabelVisible: count > 0, child: const Icon(Icons.info_rounded)),
              label: 'Incidencias',
            ),
          ],
        ),
      );
    });
  }
}
