import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_theme.dart';
import '../../core/time_format.dart';
import '../../data/models/day_timetable.dart';
import 'day_view_controller.dart';

class DayViewView extends GetView<DayViewController> {
  const DayViewView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horarios'),
        actions: [
          IconButton(
            onPressed: controller.swap,
            tooltip: 'Cambiar sentido',
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => _Summary(
                origin: controller.direction.value.originName,
                destination: controller.direction.value.destinationName,
                timetable: controller.timetable.value,
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Obx(() {
              final today = controller.now.value;
              final tomorrow = DateTime(today.year, today.month, today.day + 1);
              return SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text('Hoy · ${today.day}/${today.month}')),
                  ButtonSegment(value: 1, label: Text('Mañana · ${tomorrow.day}/${tomorrow.month}')),
                ],
                selected: {controller.dayOffset.value},
                onSelectionChanged: (s) => controller.selectDay(s.first),
              );
            }),
          ),
          Divider(color: t.border),
          Expanded(child: Obx(() => _list(context, t))),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, AppTokens t) {
    final timetable = controller.timetable.value;
    final now = controller.now.value;
    final isToday = controller.dayOffset.value == 0;
    final nextIndex = isToday ? controller.nextIndex : 0;

    if (timetable == null) {
      if (controller.failed.value) {
        return _Message(
          text: 'No se pudieron cargar los horarios.',
          action: TextButton(onPressed: () => controller.load(force: true), child: const Text('Reintentar')),
        );
      }
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (timetable.departures.isEmpty) {
      return const _Message(text: 'No hay trenes este día.');
    }

    return RefreshIndicator(
      onRefresh: () => controller.load(force: true),
      child: ListView.builder(
        controller: controller.scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemExtent: DayViewController.rowExtent,
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        itemCount: timetable.departures.length,
        itemBuilder: (context, i) {
          final time = timetable.departures[i];
          final past = isToday && (nextIndex == -1 || i < nextIndex);
          return _Row(
            time: time,
            now: now,
            past: past,
            isNext: isToday && i == nextIndex,
            showUntil: isToday && !past && time.difference(now).inMinutes < 60,
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.origin, required this.destination, required this.timetable});

  final String origin;
  final String destination;
  final DayTimetable? timetable;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = timetable;
    final details = <String>[
      if (tt?.durationMinutes != null) 'Trayecto ${tt!.durationMinutes} min',
      if (tt != null && tt.destinations.isNotEmpty) 'Trenes hacia ${tt.destinations.join(', ')}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(origin, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: t.text)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 18, color: t.faint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(destination,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: t.muted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(details.join(' · '), style: TextStyle(fontSize: 13, color: t.muted, height: 1.4)),
          ],
          if (tt != null && tt.legs > 1) ...[
            const SizedBox(height: 4),
            Text('Con transbordo. Se muestran las salidas del primer tramo.',
                style: TextStyle(fontSize: 13, color: t.muted)),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.time,
    required this.now,
    required this.past,
    required this.isNext,
    required this.showUntil,
  });

  final DateTime time;
  final DateTime now;
  final bool past;
  final bool isNext;
  final bool showUntil;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = past ? t.faint : (isNext ? t.accent : t.text);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isNext ? t.accentSoft : null,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: isNext ? Icon(Icons.circle, size: 8, color: t.accent) : null,
            ),
            const SizedBox(width: 6),
            Text(
              formatTime(time),
              style: TextStyle(
                fontSize: 20,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: color,
                fontFeatures: tabular,
              ),
            ),
            const Spacer(),
            if (showUntil)
              Text(
                formatUntil(time, now),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                  color: isNext ? t.accent : t.muted,
                  fontFeatures: tabular,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: t.muted)),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
