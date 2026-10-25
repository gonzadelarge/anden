# Metrovalencia schedules: data source research

Date of research: 2026-10-25. All calls below were tested live on that day.

## Verdict

The idea is feasible. Metrovalencia has no public API, but its own mobile app talks to a JSON
API on `fgv.es` that needs no key, no login and no token. With it you can get:

- the list of lines and stations (with coordinates),
- real-time arrivals at a station (seconds until each train),
- the full day timetable between two stations,
- service incidents.

That covers everything a "when is my next metro" app needs. The main risk is that the API is
undocumented. FGV can change or block it at any time, so the app must be built to survive that
(see [Risks](#risks-and-how-to-reduce-them)).

## Sources compared

| Source | What it is | Auth | Real time | Timetable | Verdict |
|---|---|---|---|---|---|
| **A. FGV app API** `https://www.fgv.es/fgv/app/es/api/v1/V/` | Backend of the official app | None | Yes | Yes | **Use as main source** |
| B. Website AJAX `.../functions/ajax-no-wp.php` | Backend of the web planner | None in practice | Partly (HTML only) | Yes | Fallback |
| C. GTFS feed (Spanish National Access Point, NAP) | Official open data, static | Free API key | No | Yes | Offline fallback |
| D. metroapi.alexbadi.es | Third-party wrapper over A | User-Agent rule from 2026-01-01 | Yes | Yes | Reference only |

### A. FGV app API (recommended)

Found in the source code of the open-source Android app
[Valencia Transit Reloaded](https://codeberg.org/albertodiaz/valencia-transit-reloaded)
(GPLv3, file `services/fgv/FgvService.kt`). It is the same API the official app uses.

Base URL: `https://www.fgv.es/fgv/app/es/api/v1/V/` (`V` = Valencia, `A` = TRAM d'Alacant).
The server is Laravel on Apache. It sets session cookies, but the calls work without them.
Send `Accept: application/json`. Response times were 0.2 s to 0.8 s.

| Method | Path | What it returns | Size |
|---|---|---|---|
| GET | `lineas` | 10 lines: id, name, color, ordered list of stop ids | 3 KB |
| GET | `estaciones` | 144 stations: two ids, name, lat/lon, address, interchange flag | 44 KB |
| GET | `horarios-prevision-3/{estacion_id_FGV}` | Real-time arrivals at a station | 3 KB |
| POST | `horarios-online2` | Full day timetable between two stations | 3-4 KB |
| GET | `incidencias` | Current incidents per line | 3 KB |
| GET | `tarjetas-transporte/{id}` | Transport card balance (not needed now) | - |

Real-time arrivals:

```sh
curl -H "Accept: application/json" \
  https://www.fgv.es/fgv/app/es/api/v1/V/horarios-prevision-3/17
```

```json
{"previsiones":[{"line":9,"line_id":9,"linea_id_interna":50,
  "trains":[{"destino":"Riba-roja de Túria","seconds":102,"vehicle":9010,
             "capacity":506,"cabecera":false,"meters":null,"latitude":null}]}, ...],
 "aforo_bloqueado":{"desde":null,"hasta":null},
 "configuracion_aforo":{"es":[...],"en":[...],"ca":[...]}}
```

Timetable between two stations:

```sh
curl -H "Content-Type: application/json" \
  -d '{"estacion_origen_id":554,"estacion_destino_id":552,"fecha":"27/10/2026"}' \
  https://www.fgv.es/fgv/app/es/api/v1/V/horarios-online2
```

```json
{"status":200,"error":0,"resultado":[{
  "titulo":{"ES":"Alternativa 1","VL":"Alternativa 1","EN":"Alternative 1"},
  "tarifas":"A","duracion_minutos":4,"distancia":1547,
  "transbordos":[{"destinos":["Alboraia Peris Aragó","Machado","Marítim","Rafelbunyol"],
                  "horas":{"08":["08:01","08:07","08:10","08:16", ...], ...}}]}]}
```

Things that are easy to get wrong:

- `fecha` must be `DD/MM/YYYY`. `2026-10-27` and `27-10-2026` return `400 "Error obteniendo horarios"`.
- `horarios-online2` takes the internal `id` (554). `horarios-prevision-3` takes `estacion_id_FGV` (17).
  Using the wrong one returns `422 "The selected estacion origen id is invalid."`
- One entry in `transbordos` is one leg. A trip with a change of line has more than one leg.

### B. Website AJAX endpoint (fallback)

The planner page at metrovalencia.es posts its three forms to
`https://www.metrovalencia.es/wp-content/themes/metrovalencia/functions/ajax-no-wp.php`
with `action=formularios_ajax` and the form fields URL-encoded inside a `data` field
(see `library/js/validate-forms.js` on the site).

| Form `action` | Fields | Result |
|---|---|---|
| `horarios-ruta` | `origen`, `destino`, `dia=YYYY-MM-DD`, `horaDesde`, `horaHasta` | JSON with times per hour, plus HTML |
| `planificar-ruta` | `origen`, `destino`, `dia`, `salida` (0 = leave at, 1 = arrive by), `hora` | JSON with every stop, its time and coordinates |
| `horarios-estacion` | `estacion`, `dia` | HTML only: real-time arrivals and the station timetable per destination (100 KB) |

The forms carry an `auth_token`, but the server ignores it: a call with no token, no cookie and
a fake token gave the same result. `horarios-estacion` returns `"error":true` and
`"No tiene permiso..."`, yet still sends the full HTML. This endpoint uses a third ID scheme
(see below) and returns HTML for station views, so it is only a backup if A goes away.

### C. Official GTFS feed (offline fallback)

FGV publishes a GTFS feed for Metro de Valencia on the Spanish National Access Point:
`https://nap.transportes.gob.es/api/Fichero/download/1168`
([MobilityData entry mdb-2830](https://mobilitydatabase.org/feeds/gtfs/mdb-2830)).
It covers 125 routes. The current file runs from 2026-10-22 to 2026-12-27. Without a key the
download returns `401`; you need a free NAP account. There is no GTFS-Realtime feed.

GTFS is the only legal, documented source. It is good for: a station list bundled in the app,
an offline timetable when the network is bad (underground stations), and a check against A.

### D. metroapi.alexbadi.es (reference only)

The repo [sayborduu/metroapi-metrovalencia-api](https://github.com/sayborduu/metroapi-metrovalencia-api)
holds only a README. The code is private. The
[docs](https://docs.metroapi.alexbadi.es/) are a Postman collection. The API is a wrapper over
source A: `/prevision/:id/def` returns exactly what `horarios-prevision-3` returns, and
`/prevision/:id/parse` flattens it into a sorted list with a clock time per train.

Do not build on it:

- It adds one more server, run by one person, between the app and FGV.
- From 2026-01-01 it requires a `User-Agent` in the form `app/version (platform; contact=email)`
  and may block generic clients.
- One endpoint (`/paradas/buscar`) returned `500` during testing.

Its parsed format is a good model for our own data layer.

## Station IDs: three schemes

The same station has different numbers in each source. The app needs one mapping table.

| Station | Website form (B) | `estacion_id_FGV` (A, real time) | `id` (A, timetable) |
|---|---|---|---|
| Àngel Guimerà | 25 | 17 | 554 |
| Colón | 70 | 15 | 552 |
| Benimaclet | 67 | 12 | 226 |

`GET estaciones` gives both A ids for every station, so A alone is enough. The website ids only
matter if we fall back to B. Website id 15 is Realón, not Colón, so mixing schemes gives wrong
results with no error.

## Proposed approach

1. **Data source:** call API A directly from the app. A native app has no CORS limits, so no
   backend is needed for a first version.
2. **Cache:** store `lineas` and `estaciones` on the device and refresh once a day. Cache each
   day's timetable per route. Only real-time arrivals need a live call.
3. **Bundle a GTFS snapshot** so the app shows planned times when there is no network or when
   API A fails.
4. **Optional thin backend later**, if needed: one place to fix a broken endpoint without an app
   store release, plus shared caching to keep load on FGV low.
5. **UX goal:** the home screen shows the user's saved trips with the next 3 departures, in one
   tap or zero. A home-screen widget fits this well.

## Risks and how to reduce them

| Risk | Impact | Mitigation |
|---|---|---|
| FGV changes or removes API A | App stops showing data | GTFS fallback; isolate all calls in one adapter module; optional backend proxy |
| FGV blocks unknown clients (User-Agent, rate limit) | Same | Low call volume through caching; honest User-Agent with contact email |
| Terms of use | Legal or app store complaint | Read the metrovalencia.es legal notice; do not use FGV logos or the name "Metrovalencia" as the app name; state that the app is unofficial; ask FGV for permission if the app grows |
| Real time shows `meters`, `latitude` as `null` | No train map | Use only `seconds`, which was always filled |
| Encoding | Broken accents | Responses are UTF-8 JSON with `\u` escapes; parse as JSON, do not scrape text |

## Open questions

- How often does the real-time data update? Poll the same station every 15 s for a few minutes.
- Does `horarios-online2` return more than one alternative for trips with a line change? Test a
  route like Empalme to Marítim.
- What do the `lineas` ids (42, 43...) map to in `incidencias.linea_id`? It looks like the same
  internal id.
- Platform choice for the app (Flutter, React Native, native) is still open.
