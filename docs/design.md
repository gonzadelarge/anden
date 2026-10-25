# Design

Simple, sober, modern. **Deliberately far from the official look:** no FGV, Metrovalencia or
Generalitat logos, images or colours, no red, no official line colours (line badges are
neutral).

## Tokens

All colours come from `AppTokens` (`lib/app/theme/app_theme.dart`), read with
`AppTokens.of(context)`. Never hard-code a colour in a widget.

| Token | Use |
|---|---|
| `background` / `surface` / `border` | page, cards, 1 px card border |
| `text` / `muted` / `faint` | main text, secondary text, hints and past trains |
| `accent` / `accentSoft` / `onAccent` | only the next departure, location highlight, primary actions |

Light and dark follow the system. Android launch background and launcher icon colours are in
`android/app/src/main/res/values*/colors.xml` and must match the tokens.

## Rules

- Cards: flat, `radius` (20) corners, 1 px `border`, no shadow. Highlighted card: 1.5 px
  `accent` border.
- Times use `fontFeatures: tabular` so digits line up.
- Screen header: `SectionHeader` (small overline + 26 pt title), from `lib/shared/`.
- Primary button: `FilledButton` (near-black on light). Text actions: `TextButton` (accent).
- Bottom sheets: `showModalBottomSheet` (themed). Messages: `showMessage()`.
- Edge to edge: screens without an `AppBar` use `SafeArea`; lists add
  `MediaQuery.paddingOf(context).bottom`.
- Launcher icon: three timetable rows, first one with an accent dot
  (`res/drawable/ic_launcher_foreground.xml`, monochrome variant for themed icons).
