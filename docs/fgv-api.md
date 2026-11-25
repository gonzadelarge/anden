# FGV app API

> **The app no longer calls this API** (since 2.0, [plan-server-only.md](plan-server-only.md)).
> Only the server's verify tool uses it (anden_server). The client `lib/data/api/fgv_api.dart`
> was deleted; this page is kept for the verify tool and as history. Ids here are FGV ids, not
> the GTFS ids the app uses now.

Undocumented JSON API behind the official Metrovalencia app, found in the open-source app
[Valencia Transit Reloaded](https://codeberg.org/albertodiaz/valencia-transit-reloaded).
No key, no login. It can change or disappear without notice.

Base URL: `https://www.fgv.es/fgv/app/es/api/v1/V/` (`V` = Valencia). Laravel on Apache.
Send `Accept: application/json`. Responses have no charset: decode `bodyBytes` as UTF-8.
Browsers are blocked by CORS (only FGV domains allowed); native apps are fine.

## Endpoints used

| Call | Returns | Notes |
|---|---|---|
| `GET estaciones` | 144 stations | keep `sede == "V"`, `deleted_at == null` |
| `GET lineas` | 10 lines (L1–L10) | `id` 42–50, 57 = internal; `linea_id_FGV` = public number; `stops` = `"107,80,…"` of `estacion_id_FGV` |
| `GET horarios-prevision-3/{estacion_id_FGV}` | real-time trains at a station | see below |
| `POST horarios-online2` | one day's timetable between two stations | see below |
| `GET incidencias` | current incidents | see below |

Not used yet: `GET tarjetas-transporte/{id}`.

`horarios-online2` is now the second source for timetables, after the own server on the VPS,
and the first one for trips with a change of line ([architecture.md](architecture.md#timetable-sources)).
The other calls go only to FGV.

## Station ids — three schemes

| Station | `id` (timetables) | `estacion_id_FGV` (real time) | website form = GTFS `stop_id` |
|---|---|---|---|
| Àngel Guimerà | 554 | 17 | 25 |
| Colón | 552 | 15 | 70 |
| Amistat | 560 | 23 | 121 |

The website form id is also the `stop_id` of the official GTFS feed, which the planned
timetable server uses: [../../anden_server/docs/gtfs.md](../../anden_server/docs/gtfs.md).

`Station.id` = `id`, `Station.fgvId` = `estacion_id_FGV`. A wrong id returns
`422 "The selected estacion origen id is invalid."` or, worse, another station.

## `horarios-online2`

```json
{"estacion_origen_id": 560, "estacion_destino_id": 552, "fecha": "27/10/2026"}
```

- `fecha` **must** be `DD/MM/YYYY` (max 10 chars).
- Answer: `resultado[0]` = first alternative; `transbordos[]` = legs (more than one = change
  of line); each leg has `destinos[]` and `horas: {"08": ["08:01", …], …}`.
- `horas` can be `[]` instead of `{}` for a day without service.
- Change of line: each `transbordos[]` leg has its own `horas` and `destinos`, and
  `estacion_origen_transbordo.id` is a `Station.id`. `duracion_minutos` is the total **with the
  wait** (Sant Isidre -> Riba-roja: 52 min; legs alone: 8 + 29), so the ride of the first leg
  needs one more call, origin -> change station.
- Hour `"00"` entries belong to the requested date (night service). Sort the times; don't
  trust key order.
- No line or destination per departure; only the list of destinations for the leg. `lineas` in
  the leg came back empty (checked 2026-11-01).
- Weekday, Saturday, Sunday and night service are handled by the date.

## `horarios-prevision-3`

`previsiones[]` has `line` (public number) and `trains[]` with `destino` and `seconds`. It is the
only source of line and destination per train. It holds about 8 trains **for all directions and
lines together**, so it reaches about 40 min at Amistat and only about 20 min at Colón. Estimates
were under 1 min from the timetable when compared on 2026-11-01. No id links a train to a
timetable time: `data/services/train_match.dart` matches by destination and time (3 min).

## `incidencias`

Two lists: `incidencias[]` (`id`, `linea_id` = internal line id) and
`incidencias_translations[]` (`incidencia_id`, `locale` ES/CA/EN, `titulo` often empty,
`descripcion`). Join by id, prefer `ES`. Ids and `created_at`/`updated_at` are regenerated on
every publish, so they say nothing about when an incident started.

## Speed

Usually 0.2–0.8 s; one call took 17.7 s. Never block the UI on it; client timeout is 25 s.
