# Publishing a new version to HomePi

The phones install Andén from **HomePi**, the home server (`192.168.1.195`), in the HomePi app
under **Settings → Apps**. Publishing means copying the release APK into one folder on the hub.
The hub reads that folder on every request, so it needs no restart or rebuild.

| | |
|---|---|
| Hub | `gonza@192.168.1.195` (SSH key login) |
| Folder | `/home/gonza/homepi-docker/homepi/data/apps` |
| File name | `Anden.apk` (always the same) |
| Script | [scripts/publish-homepi.sh](../scripts/publish-homepi.sh) |

## Release checklist

1. **Raise the version** in `pubspec.yaml`. Both parts must go up:

   ```yaml
   version: 1.2.0+3   # versionName+versionCode
   ```

   The hub shows the version from the APK itself. Android **refuses the update** if the new
   `versionCode` (the number after `+`) is not higher than the installed one.

2. **Check the code:**

   ```sh
   flutter analyze
   flutter test
   ```

3. **Build and publish** (Git Bash, from the project folder):

   ```sh
   scripts/publish-homepi.sh
   ```

   The script builds the release APK, copies it, renames it and checks that the file on the hub
   matches the local build. Use `--no-build` to publish the APK you already built.

4. **Install:** on each phone, open HomePi → Settings → Apps and update Andén.

5. **Commit** the version change.

## What the script does

These are the manual steps, in case the script cannot be used:

```sh
ssh gonza@192.168.1.195 'mkdir -p /home/gonza/homepi-docker/homepi/data/apps'
scp build/app/outputs/flutter-apk/app-release.apk \
    gonza@192.168.1.195:/home/gonza/homepi-docker/homepi/data/apps/Anden.apk.part
ssh gonza@192.168.1.195 'mv /home/gonza/homepi-docker/homepi/data/apps/Anden.apk.part /home/gonza/homepi-docker/homepi/data/apps/Anden.apk'
```

Rules behind these steps:

- **One file per app, same name every time.** The new `Anden.apk` replaces the old one. A
  different name would show up as a second app on the phones.
- **Name:** only letters, digits, dot, dash and underscore. No spaces, no `+`, no accents (that
  is why the file is `Anden`, not `Andén`). The app itself still shows "Andén" once installed.
- **Copy to `.part` first, then `mv`.** The hub lists only `*.apk`, so phones never see a
  half-copied file. `mv` in the same folder is instant.
- **Path:** `homepi-docker/homepi/data/apps`, not `homepi-docker/data/apps`.
- **Absolute remote path:** in Git Bash, `~` does not work in the `scp` target.

## Signing key (important)

Android also refuses an update when the new APK is signed with a **different key** from the
installed one. The only fix is then to uninstall the app, which deletes the saved trips.

Today the release build is signed with the **debug key of this PC**:

- File: `C:\Users\34617\.android\debug.keystore`
- Certificate SHA-256: `6c589181ed1ec9d5eb1dd872fbe99e23f53feedc886e073f9ca79798d9658971`

Consequences:

- Build releases **only on this PC**. Another PC has a different debug key.
- **Back up** `debug.keystore`. If it is lost (new PC, reinstalled Windows), the next version
  cannot update the installed app.
- To move to a proper release key later, set up a signing config in
  `android/app/build.gradle.kts`. The first build with the new key needs one uninstall and
  reinstall on every phone.

To check which key and version an APK has:

```sh
SDK="$LOCALAPPDATA/Android/Sdk"
BT=$(ls -d "$SDK"/build-tools/* | tail -1)
"$BT/aapt" dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "^package"
"$BT/apksigner.bat" verify --print-certs build/app/outputs/flutter-apk/app-release.apk | grep SHA-256
```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Phone says "App not installed" when updating | `versionCode` not raised, or different signing key | Raise `versionCode`; build on this PC |
| App missing from the HomePi list | File not named `*.apk`, a `.part` file left behind, or wrong folder | Check `ls -la /home/gonza/homepi-docker/homepi/data/apps` |
| Two Andén entries in the list | Published under a different name | Delete the extra file on the hub |
| `scp: No such file or directory` | `~` in the remote path | Use the absolute path |
| `Checksum mismatch` from the script | Copy interrupted or file changed | Run the script again |

## Published versions

| Date | Version | Notes |
|---|---|---|
| 2026-10-25 | 1.2.0 (3) | First publish: Inicio, Horarios, Incidencias, card by location |
