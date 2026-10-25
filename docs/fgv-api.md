# FGV app API

Undocumented JSON API behind the official Metrovalencia app, found in the open-source app
[Valencia Transit Reloaded](https://codeberg.org/albertodiaz/valencia-transit-reloaded).
No key, no login. It can change or disappear without notice. Client: `lib/data/api/fgv_api.dart`.

Base URL: `https://www.fgv.es/fgv/app/es/api/v1/V/` (`V` = Valencia). Laravel on Apache.
Send `Accept: application/json`. Responses have no charset: decode `bodyBytes` as UTF-8.
Browsers are blocked by CORS (only FGV domains allowed); native apps are fine.

## Endpoints used

| Call | Returns | Notes |
|---|---|---|
| `GET estaciones` | 144 stations | keep `sede == "V"`, `deleted_at == null` |
| `GET lineas` | 10 lines (L1–L10) | `id` 42–50, 57 = internal; `linea_id_FGV` = public number |
| `POST horarios-online2` | one day's timetable between two stations | see below |
| `GET incidencias` | current incidents | see below |

Not used yet: `GET horarios-prevision-3/{estacion_id_FGV}` (real-time arrivals, `seconds`
until each train), `GET tarjetas-transporte/{id}`.

## Station ids — three schemes

| Station | `id` (timetables) | `estacion_id_FGV` (real time) | website form |
|---|---|---|---|
| Àngel Guimerà | 554 | 17 | 25 |
| Colón | 552 | 15 | 70 |
| Amistat | 560 | 23 | – |

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
- Hour `"00"` entries belong to the requested date (night service). Sort the times; don't
  trust key order.
- No line or destination per departure; only the list of destinations for the leg.
- Weekday, Saturday, Sunday and night service are handled by the date.

## `incidencias`

Two lists: `incidencias[]` (`id`, `linea_id` = internal line id) and
`incidencias_translations[]` (`incidencia_id`, `locale` ES/CA/EN, `titulo` often empty,
`descripcion`). Join by id, prefer `ES`. Ids and `created_at`/`updated_at` are regenerated on
every publish, so they say nothing about when an incident started.

## Speed

Usually 0.2–0.8 s; one call took 17.7 s. Never block the UI on it; client timeout is 25 s.
