import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import 'add_trip_controller.dart';

class AddTripView extends GetView<AddTripController> {
  const AddTripView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Obx(() {
      final from = controller.origin.value;
      return PopScope(
        canPop: from == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(onPressed: controller.back, icon: const Icon(Icons.arrow_back_rounded)),
            title: Text(from == null ? '¿Desde dónde sales?' : '¿A dónde vas?'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (from != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Text('Desde', style: TextStyle(color: t.muted)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(from.name,
                            style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: controller.search,
                  focusNode: controller.searchFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => controller.query.value = v,
                  decoration: InputDecoration(
                    hintText: 'Buscar estación',
                    prefixIcon: Icon(Icons.search_rounded, color: t.faint),
                  ),
                ),
              ),
              Expanded(child: _results(context, t)),
            ],
          ),
        ),
      );
    });
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
