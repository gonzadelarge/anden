# Behaviour

What each screen does. UI text is Spanish. Code in `lib/modules/<name>/`.

## Shell (bottom bar)

Three tabs: **Inicio**, **Horarios**, **Incidencias**. The Incidencias icon shows a badge with
the number of incidents.

## Inicio (`home`)

- A saved trip ("Amistat ⇄ Colón") shows **two cards**, one per direction.
- Card: route, next departure (large) with "en N min", then the next two. When today's trains
  run out it continues with tomorrow's ("mañana" tag).
- Tap → day view. "x" or long press → confirmation sheet; deleting removes both directions.
- "+" → pick origin, then destination (back from destination returns to origin).
- Pull to refresh forces a download.

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
4. Permission: approximate location only (`ACCESS_COARSE_LOCATION`), asked through an in-app
   card ("Activar" / "Ahora no") shown once. Without permission nothing is marked and the
   saved order stays. Nothing leaves the phone.

## Horarios (`lookup`)

Pick origin and destination (swap button), "Ver horarios" opens the day view. Nothing is
saved.

## Day view (`day_view`)

- Full list for one direction, scrolled to the current time; past trains dimmed, next one
  marked.
- Hoy / Mañana / "Otro día" (date picker, up to 60 days ahead).
- Top bar: bookmark (save to / remove from Inicio) and swap direction.
- Trips with a change of line show the first leg's departures and a note.

## Incidencias (`incidents`)

- List of current incidents with a line badge (L1…L10), Spanish text.
- Refreshes on tab open and app resume, at most every 2 min; pull to refresh.
- No start time is shown: FGV recreates every incident with a new id and timestamp each time
  it publishes the list.
