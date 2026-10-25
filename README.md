# Andén

Private Android app that shows the next Metrovalencia trains for your saved trips as soon as
you open it. Unofficial; not linked to FGV or Metrovalencia.

- Data source and API notes: [docs/research-metrovalencia-data.md](docs/research-metrovalencia-data.md)
- Scope, design and architecture of v1: [docs/plan-v1.md](docs/plan-v1.md)

## Run

```sh
flutter pub get
flutter run            # with an emulator or a phone connected
flutter test
flutter analyze
```

Publish a new version to the phones (through HomePi):

```sh
scripts/publish-homepi.sh
```

Raise `version` in `pubspec.yaml` first. Full steps, rules and the signing key note:
[docs/publishing-homepi.md](docs/publishing-homepi.md).

## Stack

Flutter 3.44, Android only. GetX (state, routes, dependency injection), `get_storage` (cache and
favourites), `http`.
