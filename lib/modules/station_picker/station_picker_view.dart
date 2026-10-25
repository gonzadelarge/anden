import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import 'station_picker_controller.dart';

/// The picker is opened twice in a row (origin, then destination) and the
/// first page is still closing when the second opens. So each page owns its
/// controller instead of sharing one registered instance.
class StationPickerView extends StatefulWidget {
  const StationPickerView({super.key});

  @override
  State<StationPickerView> createState() => _StationPickerViewState();
}

class _StationPickerViewState extends State<StationPickerView> {
  late final StationPickerController controller;

  @override
  void initState() {
    super.initState();
    controller = StationPickerController(Get.arguments as StationPickerArgs, Get.find())..onStart();
  }

  @override
  void dispose() {
    controller.onDelete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final subtitle = controller.args.subtitle;
    return Scaffold(
      appBar: AppBar(title: Text(controller.args.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(subtitle, style: TextStyle(color: t.muted), overflow: TextOverflow.ellipsis),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => controller.query.value = v,
              decoration: InputDecoration(
                hintText: 'Buscar estación',
                prefixIcon: Icon(Icons.search_rounded, color: t.faint),
              ),
            ),
          ),
          Expanded(child: Obx(() => _results(context, t))),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, AppTokens t) {
    final results = controller.results;
    if (controller.stations.isEmpty) {
      if (controller.failed.value) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo cargar la lista de estaciones.', style: TextStyle(color: t.muted)),
              const SizedBox(height: 8),
              TextButton(onPressed: controller.load, child: const Text('Reintentar')),
            ],
          ),
        );
      }
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Ninguna estación coincide.', style: TextStyle(color: t.muted)),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final station = results[i];
        return InkWell(
          onTap: () => controller.select(station),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
            alignment: Alignment.centerLeft,
            child: Text(station.name, style: TextStyle(fontSize: 16, color: t.text)),
          ),
        );
      },
    );
  }
}
