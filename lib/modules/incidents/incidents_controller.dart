import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/clock.dart';
import '../../data/api/anden_server_api.dart';
import '../../data/models/incident.dart';
import '../../data/repositories/incident_repository.dart';

class IncidentsController extends GetxController with WidgetsBindingObserver {
  IncidentsController(this._incidents, this._clock);

  /// Do not download again when the tab is opened within this time.
  static const minRefreshGap = Duration(minutes: 2);

  final IncidentRepository _incidents;
  final Clock _clock;

  /// In the server's order: priority notices first.
  final items = <Incident>[].obs;

  /// When the app last got an answer from the server.
  final updatedAt = Rxn<DateTime>();

  /// False when the server could not read metrovalencia.es (`ok: false`).
  final sourceOk = true.obs;
  final loading = false.obs;

  /// The last download failed. Old data, if any, is still shown.
  final offline = false.obs;

  @override
  void onInit() {
    super.onInit();
    final cached = _incidents.cached();
    if (cached != null) {
      _show(cached.answer);
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
      _show(await _incidents.fetch());
      updatedAt.value = _clock.now();
      offline.value = false;
    } on AndenServerException {
      offline.value = true;
    } finally {
      loading.value = false;
    }
  }

  void _show(IncidentsAnswer answer) {
    items.assignAll(answer.items);
    sourceOk.value = answer.ok;
  }
}
