# Plan: app 2.0, data from the own server only

Status: **A1 to A8 built** (2026-11-25), version set to 2.0.0+8; publishing (A9) waits for the
user's test on the phones. Written 2026-11-25, after server milestone S5 (v2 endpoints
deployed). Decisions V1-V6 and the API shapes live in the server plan:
[../../anden_server/docs/plan-v2.md](../../anden_server/docs/plan-v2.md). This file covers the
app only.

## Goal

The app makes **no FGV call**. Stations, timetables and incidents come from
`https://anden.gonzadelarge.com/v2/`. The testers then test what would go to Google Play.

What the user loses compared with 1.5.0:

| Today | In 2.0 |
|---|---|
| Line and destination only for trains matched with real time | Line and destination for **every** train, from the timetable |
| FGV picks the change station; server is the fallback | Server only; a few pairs may differ from FGV (server plan, section 2) |
| `no_route` / `date_not_covered` -> ask FGV | A message on the card |
| Incidents from the FGV app API | Notices from metrovalencia.es, through the server |
| Saved trips, casa, favourite stations | **Reset once** (new station ids, V2) |

## Steps

| # | What | Notes |
|---|---|---|
| A1 | `AndenServerApi`: `fetchStations()`, `fetchTimetable()` (v2), `fetchIncidents()` | Same base URL and token (`--dart-define-from-file=config/anden_server.json`). Without the defines the app has **no data source**: tests use `MockClient`, `flutter run` needs the config file |
| A2 | Models: `Station.id` = GTFS id, drop `fgvId` and `interchange`; `Departure {time, line, destination}` in `DayTimetable` and its connection; `Incident {category, priority, title, lines}` | New JSON in the cache, see A3 |
| A3 | One-time reset: a `schema` key in the box. If it is missing or below 2, erase the box except `location_prompt` and `precise_prompt`, then write `schema: 2` | Removes `favorites`, `home_station`, `favorite_stations`, `learned_places`, `stations`, `lines`, `tt:*`, `incidents`: all hold FGV ids or the old shapes |
| A4 | `TimetableRepository`: server only. Remove the D4 order (FGV first for change trips). `no_route` and `date_not_covered` become states the card and the day view show | Texts to agree, for example "Sin horarios para este trayecto" and "Horario aún no publicado para este día" |
| A5 | Cards, day view, "Llévame a casa": show line and destination from the timetable for every train. Delete `LiveTrainRepository`, `live_train.dart`, `train_match.dart`, `LineRepository`, `line.dart` and their tests | The fallback line "L5, L7 hacia ..." in behaviour.md is no longer needed |
| A6 | Incidencias tab from `/v2/incidents`: category as a label, line badges by public number, priority notices first. `ok: false` or empty list: "No hay avisos" / "Avisos no disponibles ahora". A note at the bottom: "Fuente: metrovalencia.es" | Refresh rule stays (tab open, resume, at most every 2 min) |
| A7 | "Acerca de" screen (info icon in the Inicio top bar) | Content below |
| A8 | Delete `FgvApi`, `FgvApiException`, `test/fixtures/` of FGV; new fixtures = real v2 answers | `fgv-api.md` stays: the server's verify tool still uses that API |
| A9 | Version **2.0.0+8**, publish to the phones and the testers' page | Tell testers: uninstall not needed, but saved trips must be added again |

### "Acerca de" content (A7)

Spanish UI text, from the NAP licence duties ([public-release.md](../../anden_server/docs/public-release.md#duties-from-the-nap-licence-in-the-app)):

- App name and version.
- "App no oficial. No tiene relación con FGV ni con Metrovalencia."
- Horarios: "Datos del Punto de Acceso Nacional de transporte (NAP), tratados por esta app.
  Powered by MITRAMS" with a link to `https://www.transportes.gob.es/`.
- "Datos de horarios actualizados el <feedDate>" (from the last timetable or `/v2/stations`).
- "Los horarios son programados y pueden variar."
- Avisos: "Avisos de metrovalencia.es" with a link to `https://www.metrovalencia.es/`.

Links need a new package (`url_launcher`); add it in A7.

## Docs to change with the code

- [architecture.md](architecture.md): layers (no `fgv_api.dart`), DI, cache table (`schema`,
  no `lines`), timetable sources, error handling.
- [behaviour.md](behaviour.md): line and destination per train, change trips, Incidencias,
  "Acerca de", error states.
- [fgv-api.md](fgv-api.md): first line says the app no longer calls it; the server's verify tool
  does.
- [../AGENTS.md](../AGENTS.md): summary line, rules 1 and 2 (they apply to the verify tool
  only), this plan's row.
- [publishing-homepi.md](publishing-homepi.md): the config file is now required for any build.

## Done when

`flutter analyze` + `flutter test` pass; `grep -r fgv lib/` finds nothing; the user tests on the
phones with the VPS as the only source; then the server plan's S6 removes `/v1/`.

## Not in this plan

Rename to "Horarios Metro VLC", new `applicationId`, release key, AAB and the Play listing: see
[public-release.md](../../anden_server/docs/public-release.md#google-play).
