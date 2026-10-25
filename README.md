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

Install on a phone without the Play Store:

```sh
flutter build apk --release
# then copy build/app/outputs/flutter-apk/app-release.apk to the phone
```

The release build is signed with the debug key (fine for private use). Add a real signing
config in `android/app/build.gradle.kts` before giving the APK to anyone else.

## Stack

Flutter 3.44, Android only. GetX (state, routes, dependency injection), `get_storage` (cache and
favourites), `http`.
