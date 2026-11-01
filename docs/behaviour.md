# Behaviour

What each screen does. UI text is Spanish. Code in `lib/modules/<name>/`.

## Shell (bottom bar)

Three tabs: **Inicio** (train icon), **Horarios**, **Incidencias**. The Incidencias icon shows a badge with
the number of incidents.

## Inicio (`home`)

- A saved trip ("Amistat ⇄ Colón") shows **two cards**, one per direction.
- Card: route, next departure (large) with "en N min", then the next two. When today's trains
  run out it continues with tomorrow's ("mañana" tag).
- Line and destination: each departure that matches a real-time train shows them ("L5 Aeroport").
  If none matches (offline, or too far ahead), one line says what serves the trip ("L5, L7 hacia
  Aeroport, Torrent Avinguda"). If only some match, the others show just the time. Times always
  come from the timetable. Rules in `data/services/train_match.dart`.
- Change of line: the time on the card stays the first train. Small and grey beside each time, the
  train to take at the change station ("08:28 L9 Riba-roja de Túria"), cut at the end if it does
  not fit, plus "Transbordo en X" once. Rule in `data/services/connections.dart`: first train at or
  after departure + first-leg ride + **1 min**. Only the second train is shown if there are three.
- Tap → day view. "x" or long press → confirmation sheet; deleting removes both directions.
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
5. Sheet: next 3 trains with line and destination. Tap or "Ver todo el horario" opens the day
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
  marked.
- Hoy / Mañana / "Otro día" (date picker, up to 60 days ahead).
- Top bar: bookmark (save to / remove from Inicio) and swap direction.
- Trips with a change of line: each row is a first-leg departure plus the train it connects to at
  the change station (same rule as the cards). The header names the change station.

## Incidencias (`incidents`)

- List of current incidents with a line badge (L1…L10), Spanish text.
- Refreshes on tab open and app resume, at most every 2 min; pull to refresh.
- No start time is shown: FGV recreates every incident with a new id and timestamp each time
  it publishes the list.
