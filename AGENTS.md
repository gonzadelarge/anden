# Andén — agent router

Flutter Android app (GetX, Android only) for private use on two phones. Home ("Inicio") shows
each saved trip in both directions with the next 3 trains; tabs for timetable lookup
("Horarios") and notices ("Incidencias"). Since 2.0 all data comes from the own server
(`anden.gonzadelarge.com/v2/`, repo anden_server), cached on the device. No FGV call.
UI strings are Spanish.

> **Router, not a manual.** Read the row that matches the task and stop.

## Route by task

| Your task | Read | Skip |
|---|---|---|
| **Any code change** (layout, GetX patterns, cache, where things go) | [docs/architecture.md](docs/architecture.md) | archive |
| What a screen does, card highlight by location, empty/error states | [docs/behaviour.md](docs/behaviour.md) | |
| Server answers, station ids, no_route / date_not_covered, cache | [docs/architecture.md](docs/architecture.md) | archive |
| The FGV app API (the server's verify tool only; the app does not call it) | [docs/fgv-api.md](docs/fgv-api.md) | archive |
| **New screen or visual change** (colours, cards, typography) | [docs/design.md](docs/design.md) | |
| Why and how app 2.0 dropped FGV (built 2026-11-25) | [docs/plan-server-only.md](docs/plan-server-only.md) | archive |
| The server on the VPS (GTFS, notices, `/v2/` API), testers, a public release, the new name | [../anden_server/AGENTS.md](../anden_server/AGENTS.md) | app docs, unless the task also changes the app |
| **Release / publish a new APK to the phones** | skill `/release-app` → [docs/publishing-homepi.md](docs/publishing-homepi.md) | everything else |
| Why a past decision was made (why this API, original plan) | [docs/archive/](docs/archive/) | historical only, **not** current |

## Layout

```
lib/app/        theme, routes, global binding
lib/core/       pure helpers: clock, geo, search normalisation, time format
lib/data/       api client, models, repositories (cache), services (pure logic + location)
lib/modules/    one folder per screen: shell, home, lookup, incidents, day_view, station_picker, about
lib/shared/     helpers used by several modules
test/           unit + widget tests; test/fixtures/ = real /v2/ answers, test/support/ = fake server
scripts/        publish-homepi.sh
docs/           this documentation
```

## Rules that are easy to break

1. **Station ids are GTFS `stop_id`s** (Amistat 121, Colón 70). FGV ids (Amistat 560) belong
   to the verify tool only. Boxes from 1.x are erased once on start (`data/storage/schema.dart`).
2. **Builds need `config/anden_server.json`** (`--dart-define-from-file`). Without it the app has
   no data source. See docs/publishing-homepi.md.
3. **Next trains = today + tomorrow merged.** Night service after midnight is in the next
   date's timetable. Use `nextDepartures()`, never filter one day.
4. **The station picker owns its controller** (no binding). It opens twice in a row and a
   shared GetX instance would keep the first page's arguments.
5. **Never `Get.bottomSheet` / `Get.snackbar`.** They ignore the theme (transparent sheet).
   Use `showModalBottomSheet` and `showMessage()` (lib/shared/messages.dart).
6. **No FGV / Metrovalencia branding**, no red, no official line colours. See docs/design.md.
7. **Raise `versionCode` (the `+N`) for every release** and build on this PC only: the APK is
   signed with this PC's debug key. See docs/publishing-homepi.md.
8. **Don't launch the emulator.** `flutter analyze` + `flutter test` is the whole automated
   bar. Say plainly when a layout change is untested on a device.

## Keeping this true

Each fact lives in **one** file. If you find a fact copied into a second doc, delete the copy
and link instead. When a change makes a doc wrong, fix that doc in the same change.
