# Behaviour

What each screen does. UI text is Spanish. Code in `lib/modules/<name>/`.

## Shell (bottom bar)

Three tabs: **Inicio** (train icon), **Horarios**, **Incidencias**. The Incidencias icon shows a badge with
the number of notices.

## Inicio (`home`)

- A saved trip ("Amistat ⇄ Colón") shows **two cards**, one per direction.
- Card: route, next departure (large) with "en N min", then the next two. When today's trains
  run out it continues with tomorrow's ("mañana" tag).
- Line and destination: every departure shows them ("L5 Aeroport"), from the timetable. The first
  one below the large time, the other two one per row. A line the feed has no number for shows
  only the destination. There is no real time: all times are scheduled.
- Change of line: the time on the card stays the first train. Small and grey beside each time, the
  train to take at the change station ("08:28 L9 Riba-roja de Túria"), cut at the end if it does
  not fit, plus "Transbordo en X" once. Rule in `data/services/connections.dart`: first train at or
  after departure + first-leg ride + **2 min**. Only the second train is shown if there are three.
  The server picks the change station; for a few pairs it may differ from the official planner
  (anden_server docs/fgv-routing.md).
- No timetable on the server: "Sin horarios para este trayecto" (`no_route`) or "Horario aún no
  publicado para este día" (`date_not_covered`), in place of the times. Not an error: no retry
  button, no "Sin conexión".
- Tap → day view. "x" or long press → confirmation sheet; deleting removes both directions.
- Top bar: "i" opens "Acerca de", "+" adds a trip.
- "+" → pick origin, then destination (back from destination returns to origin).
- Pull to refresh forces a download.

### Llévame a casa (`go_to_controller.dart`, `widgets/go_to.dart`)

Floating button on Inicio (house icon only), to the station marked as casa.

1. No casa yet: the first press opens the station picker. Long press on the button or "Cambiar
   casa" in the sheet changes it.
2. Position: precise fix (10 s timeout), then Android's last known position if under 2 min old.
3. Origins (`data/services/nearby_stations.dart`): the nearest station, plus up to two others
   less than **400 m** farther. There is no maximum distance. Casa is removed from the list; if
   casa is the nearest, the app says "Ya estás en tu parada de casa".
4. One origin: straight to the sheet. More: the user picks one first.
5. Sheet: next 3 trains with line and destination (or the no-timetable message, as on cards). Tap or "Ver todo el horario" opens the day
   view. The small button next to the route ("Cambiar origen") opens the station picker; any
   station can be chosen and the sheet updates.

### Favourite stations (same controller and sheet)

Small star button beside "Llévame a casa". Tap: it opens up to **3** saved stations above the
button, plus "Añadir estación" while there is room; the x removes one. A tap outside closes it.
Tapping a station opens the sheet with trains from the station **nearest to the user**, with no
choice step: "Cambiar origen" corrects it. At that same station the app says "Ya estás en X".

### Card by location (`nearby_controller.dart`, rules in `data/services/nearby_direction.dart`)

Highlighted card: accent border + label; its trip moves to the top, that direction first.

1. **Station rule:** the nearest saved origin within **1 km** wins ("Cerca de ti"). If a
   second saved origin is also within 1 km and less than **400 m** farther, nothing is marked.
   Several trips from the same origin are all marked.
2. **Learned places:** when the station rule cannot decide, opening a card stores "this place →
   this direction". Later, within **300 m** of that place, that card is marked ("Lo sueles
   mirar aquí").
3. Position: Android's last known position if under 2 min old (instant), then a fresh
   low-accuracy fix (6 s timeout). Positions older than 10 min are not used.
4. Permission: asked through an in-app card ("Activar" / "Ahora no") shown once. Highlighting
   uses low accuracy only. Without permission nothing is marked and the saved order stays.
   Nothing leaves the phone. The manifest has `ACCESS_COARSE_LOCATION` and
   `ACCESS_FINE_LOCATION` (precise is for "Llévame a casa"; it asks once to upgrade from
   approximate, and also works if the user stays on approximate).

## Horarios (`lookup`)

Pick origin and destination (swap button), "Ver horarios" opens the day view. Nothing is
saved.

## Day view (`day_view`)

- Full list for one direction, scrolled to the current time; past trains dimmed, next one
  marked. Each row: time, line and destination.
- Hoy / Mañana / "Otro día" (date picker, up to 60 days ahead).
- Top bar: bookmark (save to / remove from Inicio) and swap direction.
- Trips with a change of line: each row is a first-leg departure plus, below it, the train it
  connects to at the change station (same rule as the cards). The header names the change station.
- No timetable on the server: the same two messages as the cards, in place of the list.

## Incidencias (`incidents`)

- Service notices from metrovalencia.es, read by the own server (`/v2/incidents`), in the
  server's order: priority notices first.
- Each card: category on top ("INCIDENCIA", "SERVICIO ESPECIAL"; priority ones in the accent
  colour), neutral line badges (L1…L10), the title. A notice with its own link shows "Ver en
  metrovalencia.es" and opens it in the browser.
- "Fuente: metrovalencia.es" under the list.
- Empty list: "No hay avisos". Server answered `ok: false` with no list: "Avisos no disponibles
  ahora". Server not reachable and nothing cached: "Sin datos".
- Refreshes on tab open and app resume, at most every 2 min; pull to refresh.

## Acerca de (`about`)

Opened with the "i" in the Inicio top bar. App name and version, "App no oficial. No tiene
relación con FGV ni con Metrovalencia.", the NAP source line ("Powered by MITRAMS", link to
transportes.gob.es), "Datos de horarios actualizados el <fecha>" (newest feed date from the
cached stations or timetables; hidden before the first download), "Los horarios son programados
y pueden variar." and the notices source with a link to metrovalencia.es. These texts are duties
of the NAP licence (anden_server docs/public-release.md).
