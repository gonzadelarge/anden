# Architecture

Flutter 3.44, Dart 3.12, Android only (minSdk 24). Packages: `get` (state, routes, DI),
`get_storage` (key-value cache), `http`, `geolocator` (approximate location),
`flutter_localizations` (Spanish date picker).

## Layers

```
modules/  (views + GetX controllers)
   │ uses
data/repositories  ── cache policy, one per data type
   │ uses
data/api/fgv_api.dart  ── HTTP only, throws FgvApiException
data/storage/local_store.dart  ── LocalStore interface (GetStorageStore / MemoryStore)
```

`data/services/` holds pure logic with no Flutter (`next_departures.dart`,
`nearby_direction.dart`) plus `location_service.dart` (wraps `geolocator`). `core/` is pure
helpers. Pure code takes a `Clock` so tests can fix "now".

## Dependency injection

- `app/bindings/initial_binding.dart`: app-wide singletons (`permanent: true`): `Clock`,
  `LocalStore`, `FgvApi`, all repositories, `LocationService`.
- `modules/shell/shell_binding.dart`: the shell route creates the tab controllers
  (`ShellController`, `NearbyController`, `HomeController`, `LookupController`,
  `IncidentsController`). The tabs live in an `IndexedStack`, so they stay alive.
- `day_view` has its own binding (argument: `TripDirection`).
- `station_picker` has **no binding**: `StationPickerView` is a `StatefulWidget` that creates
  and disposes its own controller, because the picker is pushed twice in a row
  (`shared/pick_station.dart`) and a shared instance would keep the first page's arguments.

Routes: `app/routes/app_routes.dart` (`/`, `/day`, `/station`).

## Cache (all in GetStorage box `anden`)

| Key | Content | Policy |
|---|---|---|
| `stations` | station list | 7 days; old list used when offline |
| `lines` | line list | 7 days; old list used when offline |
| `tt:<origin>:<dest>:<yyyymmdd>` | one day's timetable | refetched after 12 h; past days pruned on start |
| `incidents` | last incident list | always refetched; shown when offline |
| `favorites` | saved trips | `FavoritesRepository.revision` (RxInt) goes up on every change |
| `learned_places` | location → direction | max 30, latest choice per 300 m wins |
| `location_prompt` | `accepted` / `declined` | in-app location card shown once |

`TimetableRepository.get()` **throws** when offline; callers keep the cached copy on screen and
set their own offline flag.

## Data flow on Inicio

1. First frame uses only the cache. The network never blocks it.
2. `onReady` and app resume: `refreshAll()` loads today + tomorrow for every direction, then
   `NearbyController.locate()`.
3. A 20 s ticker updates `now`; at midnight the service day changes and data reloads.
4. Other screens change trips through `FavoritesRepository`; Home listens with
   `ever(revision, …)`.

## Error handling

| Case | Behaviour |
|---|---|
| Offline, cache present | Show cache + "Sin conexión" note |
| Offline, no cache | Card shows retry action |
| API slow (seen up to 17.7 s) | `FgvApi.timeout` = 25 s; cache stays on screen |
| Unexpected JSON | `FgvApiException`; one card fails, the rest work |

## Tests

`flutter analyze` + `flutter test`. Fixtures in `test/fixtures/` are real API responses from
2026-10-25. Widget tests (`test/modules/shell_view_test.dart`) build the real shell with a
`MockClient` and a fake `LocationService`; reset GetX in `tearDown` (delete the controllers
with timers/observers first).
