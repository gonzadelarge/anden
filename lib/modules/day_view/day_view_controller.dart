import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../data/models/day_timetable.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/repositories/timetable_repository.dart';

class DayViewController extends GetxController {
  DayViewController(TripDirection initial, this._timetables, this._clock) : direction = initial.obs;

  /// Fixed row height, so the list can jump straight to the next train.
  static const rowExtent = 60.0;

  final TimetableRepository _timetables;
  final Clock _clock;

  final Rx<TripDirection> direction;

  /// 0 = today, 1 = tomorrow.
  final dayOffset = 0.obs;
  final timetable = Rxn<DayTimetable>();
  final loading = false.obs;
  final failed = false.obs;
  late final Rx<DateTime> now;
  final scroll = ScrollController();

  Timer? _ticker;
  int _requestId = 0;

  DateTime get date {
    final today = _clock.today();
    return DateTime(today.year, today.month, today.day + dayOffset.value);
  }

  /// Index of the next train, or -1 when all trains of the shown day have left.
  int get nextIndex {
    final departures = timetable.value?.departures ?? const [];
    final n = now.value;
    final from = DateTime(n.year, n.month, n.day, n.hour, n.minute);
    return departures.indexWhere((t) => !t.isBefore(from));
  }

  @override
  void onInit() {
    super.onInit();
    now = _clock.now().obs;
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => now.value = _clock.now());
    load();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    scroll.dispose();
    super.onClose();
  }

  void selectDay(int offset) {
    if (offset == dayOffset.value) return;
    dayOffset.value = offset;
    load();
  }

  void swap() {
    direction.value = direction.value.reversed;
    load();
  }

  Future<void> load({bool force = false}) async {
    final request = ++_requestId;
    final d = direction.value;
    final day = date;
    timetable.value = _timetables.cached(d.originId, d.destinationId, day);
    final hadCache = timetable.value != null;
    failed.value = false;
    loading.value = true;
    if (hadCache && !force) _scrollToNext();

    try {
      final result = await _timetables.get(d.originId, d.destinationId, day, force: force);
      if (request != _requestId) return;
      timetable.value = result;
      // Do not move the list again if the user is already looking at it.
      if (!hadCache) _scrollToNext();
    } catch (_) {
      if (request != _requestId) return;
      failed.value = timetable.value == null;
    } finally {
      if (request == _requestId) loading.value = false;
    }
  }

  void _scrollToNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final index = dayOffset.value == 0 ? max(nextIndex, 0) : 0;
      // Keep two past trains visible above the next one.
      final target = max(0, index - 2) * rowExtent;
      scroll.jumpTo(min(target, scroll.position.maxScrollExtent));
    });
  }
}
