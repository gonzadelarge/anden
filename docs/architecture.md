# Architecture

Flutter 3.44, Dart 3.12, Android only (minSdk 24). Packages: `get` (state, routes, DI),
`get_storage` (key-value cache), `http`, `geolocator` (approximate location),
`url_launcher` (links in Incidencias and "Acerca de"), `flutter_localizations` (Spanish date
picker).

Since 2.0 the app's **only data source** is the own server `https://anden.gonzadelarge.com/v2/`
(repo anden_server, [plan-v2.md](../../anden_server/docs/plan-v2.md)). The app makes no FGV call.

## Layers

```
modules/  (views + GetX controllers)
   │ uses
data/repositories  ── cache policy, one per data type
   │ uses
data/api/anden_server_api.dart  ── own server on the VPS (/v2/), throws AndenServerException
data/storage/local_store.dart  ── LocalStore interface (GetStorageStore / MemoryStore)
data/storage/schema.dart  ── one-time reset of the box for 2.0, run in main() before the binding
```

`data/services/` holds pure logic with no Flutter (`next_departures.dart`, `connections.dart`,
`nearby_direction.dart`, `nearby_stations.dart`) plus `location_service.dart` (wraps `geolocator`). `core/` is pure
helpers. Pure code takes a `Clock` so tests can fix "now".

## Dependency injection

- `app/bindings/initial_binding.dart`: app-wide singletons (`permanent: true`): `Clock`,
  `LocalStore`, `AndenServerApi`, all repositories, `LocationService`.
- `modules/shell/shell_binding.dart`: the shell route creates the tab controllers
  (`ShellController`, `NearbyController`, `HomeController`, `GoToController`,
  `LookupController`, `IncidentsController`). The tabs live in an `IndexedStack`, so they stay alive.
- `day_view` has its own binding (argument: `TripDirection`).
- `about` has no binding and no controller: `AboutView` reads the feed date from
  `StationRepository` and `TimetableRepository`.
- `station_picker` has **no binding**: `StationPickerView` is a `StatefulWidget` that creates
  and disposes its own controller, because the picker is pushed twice in a row
  (`shared/pick_station.dart`) and a shared instance would keep the first page's arguments.

Routes: `app/routes/app_routes.dart` (`/`, `/day`, `/station`, `/about`).

## Cache (all in GetStorage box `anden`)

| Key | Content | Policy |
|---|---|---|
| `schema` | `2` | see "Reset for 2.0" below |
| `stations` | station list (GTFS ids, lines) + `feedDate` | 7 days; old list used when offline |
| `tt:<origin>:<dest>:<yyyymmdd>` | one day's timetable (server shape + `fetchedAt`) | refetched after 12 h; past days pruned on start |
| `incidents` | last `/v2/incidents` answer (`ok`, `readAt`, items) | always refetched; shown when offline |
| `favorites` | saved trips | `FavoritesRepository.revision` (RxInt) goes up on every change |
| `learned_places` | location → direction | max 30, latest choice per 300 m wins |
| `location_prompt` | `accepted` / `declined` | in-app location card shown once |
| `home_station` | station marked as casa | until changed |
| `favorite_stations` | favourite stations, max 3 | until changed |
| `precise_prompt` | `true` | upgrade to precise location asked once |

Station ids everywhere (cache keys, saved trips, casa) are GTFS `stop_id`s (Amistat 121,
Colón 70).

### Reset for 2.0

`migrateStore()` (`data/storage/schema.dart`) runs once in `main()`, before any repository reads
the box. If `schema` is missing or below 2 it erases every key except `location_prompt` and
`precise_prompt`, then writes `schema: 2`. Boxes from 1.x held FGV station ids and old shapes,
so saved trips, casa, favourite stations and learned places must be set up again once.

### Timetables

`TimetableRepository.get()` downloads a day from `/v2/timetable` (`AndenServerApi`, 10 s
timeout) and stores the answer under its `tt:` key. Every departure carries its line and
destination; trips with a change also carry the change station, the usual first-leg ride
(`rideMinutes`) and the second leg's departures.

`get()` **throws** `AndenServerException`; callers keep the cached copy on screen:

- `code` `no_route` or `date_not_covered` (`isNoTimetable`): the server has no timetable for that
  pair or day. Screens show a message (`shared/timetable_notice.dart`), not "Sin conexión".
- anything else (network, timeout, 5xx, bad JSON): could not reach the server; callers set their
  own offline flag.

The server is reachable only when the build passes `ANDEN_URL` and `ANDEN_TOKEN`
(`--dart-define-from-file=config/anden_server.json`, see
[publishing-homepi.md](publishing-homepi.md)). Without them every call throws: `flutter run`
needs the file, tests use a `MockClient` (`test/support/fake_server.dart`).

## Data flow on Inicio

1. First frame uses only the cache. The network never blocks it.
2. `onReady` and app resume: `refreshAll()` loads today + tomorrow for every direction, then
   `NearbyController.locate()`. Line, destination and the connecting train come from the
   timetable; nothing else is downloaded.
3. A 20 s ticker updates `now`; at midnight the service day changes and data reloads.
4. Other screens change trips through `FavoritesRepository`; Home listens with
   `ever(revision, …)`.

## Error handling

| Case | Behaviour |
|---|---|
| Offline, cache present | Show cache + "Sin conexión" note |
| Offline, no cache | Card shows retry action |
| `no_route` / `date_not_covered`, no cache | Card or day view shows the notice; no retry, no offline note |
| Server slow | `AndenServerApi.timeout` = 10 s; cache stays on screen |
| Unexpected JSON | `AndenServerException`; one card fails, the rest work |
| Incidents reader broken on the server (`ok: false`) | Last good list if the server still has one, else "Avisos no disponibles ahora" |

## Tests

`flutter analyze` + `flutter test`. Fixtures in `test/fixtures/` are real `/v2/` answers from
2026-11-25 (feed of 2026-11-24). `test/support/fake_server.dart` serves them through a
`MockClient`, for any pair and date asked, and can answer `no_route`, `date_not_covered` or fail
as offline. Widget tests (`test/modules/shell_view_test.dart`) build the real shell with it and
a fake `LocationService`; reset GetX in `tearDown` (delete the controllers with timers/observers
first). `test/core/app_info_test.dart` checks that `appVersion` matches `pubspec.yaml`.
