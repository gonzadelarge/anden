import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/section_header.dart';
import 'lookup_controller.dart';

class LookupView extends GetView<LookupController> {
  const LookupView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const SectionHeader(overline: 'Horarios', title: 'Consultar horarios'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Obx(() => Material(
                    color: t.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius),
                      side: BorderSide(color: t.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            _StationField(
                              label: 'Origen',
                              value: controller.origin.value?.name,
                              onTap: controller.pickOrigin,
                            ),
                            Divider(color: t.border, indent: 20, endIndent: 72),
                            _StationField(
                              label: 'Destino',
                              value: controller.destination.value?.name,
                              onTap: controller.pickDestination,
                            ),
                          ],
                        ),
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              onPressed: controller.swap,
                              tooltip: 'Intercambiar',
                              style: IconButton.styleFrom(
                                backgroundColor: t.background,
                                side: BorderSide(color: t.border),
                              ),
                              icon: Icon(Icons.swap_vert_rounded, color: t.text),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Obx(() => FilledButton(
                    onPressed: controller.ready ? controller.open : null,
                    child: const Text('Ver horarios'),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationField extends StatelessWidget {
  const _StationField({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 72, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.faint)),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Elige estación',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                      color: value == null ? t.muted : t.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
