import 'local_store.dart';

/// Version of what the box holds. 2 = app 2.0: GTFS station ids and the server's shapes.
const storeSchema = 2;
const _schemaKey = 'schema';

/// Kept across the reset: they hold no station ids.
const _keptOnReset = {'location_prompt', 'precise_prompt'};

/// One-time reset for app 2.0 (docs/plan-server-only.md, A3). Older boxes hold FGV station
/// ids and old shapes (saved trips, casa, favourite stations, learned places, stations,
/// lines, timetables, incidents), so everything except the two prompt flags is erased.
/// Run it before any repository reads the box.
Future<void> migrateStore(LocalStore store) async {
  final schema = store.read<int>(_schemaKey) ?? 0;
  if (schema >= storeSchema) return;
  for (final key in store.keys.where((k) => !_keptOnReset.contains(k)).toList()) {
    await store.remove(key);
  }
  await store.write(_schemaKey, storeSchema);
}
