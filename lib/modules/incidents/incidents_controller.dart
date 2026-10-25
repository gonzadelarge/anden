import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../data/models/incident.dart';
import '../../data/models/line.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/line_repository.dart';

class IncidentsController extends GetxController with WidgetsBindingObserver {
  IncidentsController(this._incidents, this._lines, this._clock);

  /// Do not download again when the tab is opened within this time.
  static const minRefreshGap = Duration(minutes: 2);

  final IncidentRepository _incidents;
  final LineRepository _lines;
  final Clock _clock;

  final items = <Incident>[].obs;
  final lines = <int, Line>{}.obs;
  final updatedAt = Rxn<DateTime>();
  final loading = false.obs;

  /// The last download failed. Old data, if any, is still shown.
  final offline = false.obs;

  String lineName(int lineId) => lines[lineId]?.name ?? '';

  @override
  void onInit() {
    super.onInit();
    lines.assignAll({for (final l in _lines.cached()) l.id: l});
    final cached = _incidents.cached();
    if (cached != null) {
      items.assignAll(_sorted(cached.items));
      updatedAt.value = cached.fetchedAt;
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshIfOld();
  }

  void refreshIfOld() {
    final last = updatedAt.value;
    if (last == null || _clock.now().difference(last) > minRefreshGap) load();
  }

  Future<void> load() async {
    if (loading.value) return;
    loading.value = true;
    try {
      try {
        lines.assignAll({for (final l in await _lines.getLines()) l.id: l});
      } catch (_) {
        // Without line names the incidents are still useful.
      }
      final fresh = await _incidents.fetch();
      items.assignAll(_sorted(fresh));
      updatedAt.value = _clock.now();
      offline.value = false;
    } catch (_) {
      offline.value = true;
    } finally {
      loading.value = false;
    }
  }

  List<Incident> _sorted(List<Incident> list) {
    int number(Incident i) => lines[i.lineId]?.number ?? 999;
    return [...list]..sort((a, b) => number(a).compareTo(number(b)));
  }
}
