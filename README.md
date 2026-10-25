# Andén

Private Android app that shows the next Metrovalencia trains for your saved trips as soon as
you open it. Unofficial; not linked to FGV or Metrovalencia.

Documentation starts at [AGENTS.md](AGENTS.md): a table that says which doc to read for each
task.

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
