import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../data/models/day_timetable.dart';
import '../../data/models/favorite_trip.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../shared/messages.dart';

class DayViewController extends GetxController {
  DayViewController(TripDirection initial, this._timetables, this._favorites, this._clock)
      : direction = initial.obs;

  /// Fixed row height, so the list can jump straight to the next train.
  static const rowExtent = 60.0;

  /// How far ahead the date picker goes.
  static const maxDaysAhead = 60;

  final TimetableRepository _timetables;
  final FavoritesRepository _favorites;
  final Clock _clock;

  final Rx<TripDirection> direction;
  late final Rx<DateTime> date;
  final timetable = Rxn<DayTimetable>();
  final loading = false.obs;
  final failed = false.obs;
  final saved = false.obs;
  late final Rx<DateTime> now;
  final scroll = ScrollController();

  Timer? _ticker;
  int _requestId = 0;

  DateTime get today => _clock.today();
  DateTime get tomorrow => DateTime(today.year, today.month, today.day + 1);
  DateTime get lastSelectableDay => DateTime(today.year, today.month, today.day + maxDaysAhead);
  bool get isToday => date.value == today;

  /// Index of the next train, or -1 when all trains of the shown day have left.
  int get nextIndex {
    final departures = timetable.value?.departures ?? const [];
    final n = now.value;
    final from = DateTime(n.year, n.month, n.day, n.hour, n.minute);
    return departures.indexWhere((t) => !t.isBefore(from));
  }

  FavoriteTrip get _trip {
    final d = direction.value;
    return FavoriteTrip(aId: d.originId, aName: d.originName, bId: d.destinationId, bName: d.destinationName);
  }

  @override
  void onInit() {
    super.onInit();
    now = _clock.now().obs;
    date = today.obs;
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => now.value = _clock.now());
    _updateSaved();
    load();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    scroll.dispose();
    super.onClose();
  }

  void selectDate(DateTime day) {
    final d = dateOnly(day);
    if (d == date.value) return;
    date.value = d;
    load();
  }

  void swap() {
    direction.value = direction.value.reversed;
    load();
  }

  /// Saves the trip to the home screen, or removes it if it is already there.
  Future<void> toggleSaved() async {
    final trip = _trip;
    if (_favorites.contains(trip.id)) {
      await _favorites.remove(trip.id);
      showMessage('Trayecto quitado de Inicio');
    } else {
      await _favorites.add(trip);
      showMessage('Trayecto guardado en Inicio');
    }
    _updateSaved();
  }

  Future<void> load({bool force = false}) async {
    final request = ++_requestId;
    final d = direction.value;
    final day = date.value;
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

  void _updateSaved() => saved.value = _favorites.contains(_trip.id);

  void _scrollToNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final index = isToday ? max(nextIndex, 0) : 0;
      // Keep two past trains visible above the next one.
      final target = max(0, index - 2) * rowExtent;
      scroll.jumpTo(min(target, scroll.position.maxScrollExtent));
    });
  }
}
