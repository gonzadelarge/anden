# Andén v1: plan and technical design

Private Android app to see the next Metrovalencia trains for saved trips. Working name: **Andén**
(change it in `android/app/src/main/AndroidManifest.xml` and `lib/app/app_info.dart`).
Data source: FGV app API, see [research-metrovalencia-data.md](research-metrovalencia-data.md).

## Scope

In v1:

1. **Home.** One card per direction of every saved trip. A trip "Amistat ⇄ Colón" shows two
   cards: Amistat → Colón and Colón → Amistat. Each card shows the next 3 departures and
   "en 4 min" for the first one. Opening the app is enough; no taps needed.
2. **Day view.** Tap a card to see all departures for that direction, scrolled to the current
   time. Past trains are dimmed, the next one is marked. A switch shows today or tomorrow.
3. **Add a trip.** Pick station A, then station B, from a list with accent-insensitive search.
4. **Delete a trip.** The "x" on a card, or a long press. Both ask for confirmation and remove
   both directions.

Added in v1.1:

5. **Bottom bar** with three tabs: Inicio, Horarios, Incidencias.
6. **Horarios tab.** Pick origin and destination and open the day view, without saving the trip.
   The day view can show any date up to 60 days ahead and has a button to save or remove the
   trip from Inicio.
7. **Incidencias tab.** Current incidents from `GET incidencias`, with the line name from
   `GET lineas`. The tab shows a badge with the number of incidents. FGV recreates every
   incident (new id and timestamp) each time it publishes the list, so the app shows no start
   time.

Added in v1.2:

8. **Card by location.** With approximate location (`ACCESS_COARSE_LOCATION`, asked once
   through an in-app card), Inicio marks the card you most likely want ("Cerca de ti") and puts
   its trip first, that direction on top. Rules, in order:
   - **Station rule:** the nearest saved origin within 1 km wins. If a second saved origin is
     also within 1 km and less than 400 m farther, nothing is marked.
   - **Learned places:** when the station rule cannot decide (far from all saved stations, or
     between two), opening a card stores "this place → this direction". Later, within 300 m of
     that place, that card is marked ("Lo sueles mirar aquí"). The latest choice per place
     wins; at most 30 places are kept.
   - Position: Android's last known position if it is under 2 minutes old (instant), then a
     fresh low-accuracy fix with a 6 s timeout. Cards never wait for it. Nothing leaves the
     phone. Without permission the app behaves as before.

Not in v1: real-time arrivals, widget, smart ordering by time of day, walking time,
trips with a change of line shown leg by leg (they work, but only the first leg's departures
are shown).

## User flow

```
Open app ──> Inicio (cached data shown at once, refresh in background)
               │
               ├── tap card ──> Day view (today | tomorrow | other date)
               ├── "x" or long press ──> confirm delete trip
               └── "+" ──> pick origin ──> pick destination ──> back to Inicio

Horarios ──> pick origin, pick destination ──> Day view ──> optional "save to Inicio"
Incidencias ──> list, pull to refresh
```

## Design

Own visual style, no FGV / Metrovalencia / Generalitat images, logos or colours (no red).

- Neutral palette: near-black and warm off-white, one cool blue accent used only for the next
  departure and primary actions.
- Light and dark themes follow the system setting.
- Flat surfaces with a thin border, no shadows, 20 px corner radius.
- System font (Roboto) with tabular figures so times line up.
- Times are the main content: the next departure is large, the two after it are smaller.

## Architecture

Flutter, Android only, GetX for state, routing and dependency injection. Feature modules keep
each screen self-contained so new screens (incidents, widget settings) can be added later.

```
lib/
  main.dart                     app start, storage init, GetMaterialApp
  app/
    app_info.dart               app name
    routes/                     route names and GetPage list
    theme/                      colours, text styles, ThemeData
    bindings/initial_binding.dart  global services (api, repositories)
  core/
    clock.dart                  injectable "now" (for tests)
    text_normalize.dart         accent-insensitive search
    time_format.dart            "en 4 min", dates
  data/
    api/fgv_api.dart            HTTP client for the FGV app API
    models/                     Station, DayTimetable, Departure, FavoriteTrip
    storage/local_store.dart    get_storage wrapper (cache + favourites)
    repositories/
      station_repository.dart   station list, cached 7 days
      timetable_repository.dart day timetable per direction, cached per date
      favorites_repository.dart saved trips
    services/next_departures.dart  "next N trains" across today and tomorrow
  shared/                       station picking flow, section header, messages
  modules/
    shell/                      bottom bar; binding creates the three tab controllers
    home/                       Inicio tab; nearby_controller.dart picks the card by location
    lookup/                     Horarios tab
    incidents/                  Incidencias tab
    day_view/                   full day for one direction
    station_picker/             station search; owns its controller (opened twice in a row)
```

### Data flow

- **Stations.** `GET estaciones`, keep only `sede == "V"`. Cached on the device and refreshed
  if older than 7 days. Both ids are kept: `id` is used for timetables, `estacion_id_FGV` is kept
  for real-time arrivals later.
- **Timetables.** `POST horarios-online2` with `fecha` as `DD/MM/YYYY`. One cache entry per
  origin, destination and date. An entry is refetched when it is older than 12 hours. Entries
  for past dates are deleted on start.
- **Prefetch.** On start, on resume and on pull to refresh, the home loads today and tomorrow
  for every card. Cached data is shown first; the network never blocks the first frame.
- **Next departures.** Merge today's and tomorrow's departures as real `DateTime` values and
  take the first 3 after "now". This covers the end of the day and the night service after
  midnight, which lives in the next date's file.
- **Ticker.** The home controller rebuilds every 20 seconds so "en X min" and the list move.

### Error handling

| Case | Behaviour |
|---|---|
| No network, cache present | Show cache, small "sin conexión" note |
| No network, no cache | Card shows "Sin datos" and a retry action |
| API slow (seen up to 17.7 s) | Timeout 25 s; cached data stays on screen |
| No trains left today and tomorrow not loaded | Card shows "Sin más trenes hoy" |
| API changes shape | Parsing errors are caught per card; the rest of the home still works |

### Packages

| Package | Use |
|---|---|
| `get` 4.7.3 | State, routing, dependency injection |
| `get_storage` 2.1.1 | Local key-value cache and favourites |
| `http` 1.6.0 | HTTP client (easy to mock in tests) |

### Tests

Unit tests for: timetable parsing (real response saved as a fixture), next-departures logic
across midnight, accent-insensitive search, and the favourites repository.
`flutter analyze` and `flutter test` must pass. No emulator runs in this phase.

## Later versions

- Home-screen widget with the next trains of the first trip.
- Show on a trip card when an incident affects its line.
- Real-time arrivals from `horarios-prevision-3/{estacion_id_FGV}`.
- Reorder trips.
