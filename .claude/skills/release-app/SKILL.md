---
name: release-app
description: Release Andén to the phones - bump the version, check, build the release APK and publish it to HomePi with scripts/publish-homepi.sh. Use when asked to release, publish, ship or deploy the app, build a new APK, or put a new version on HomePi.
---

# Release Andén

Facts, rules and troubleshooting live in [docs/publishing-homepi.md](../../../docs/publishing-homepi.md).
Read it only if a step below fails or the user asks why.

## Steps

1. **Version.** Read `version:` in `pubspec.yaml`. Raise it: patch (`1.2.1`) for fixes, minor
   (`1.3.0`) for features, and **always** `+N` → `+N+1`. Android refuses an update whose
   `versionCode` is not higher. State the new version and continue.
2. **Check.** `flutter analyze` and `flutter test`. Stop and report if either fails. Do not
   launch the emulator.
3. **Publish.** From the project root in Git Bash:

   ```sh
   bash scripts/publish-homepi.sh
   ```

   It builds, copies `Anden.apk.part`, renames it to `Anden.apk` and compares checksums. It
   must end with `Done: /home/gonza/homepi-docker/homepi/data/apps/Anden.apk (<version>)`.
   Build only on this PC: the APK is signed with its debug key.
4. **Log it.** Add a row to "Published versions" in `docs/publishing-homepi.md`.
5. **Report** the version and that the checksum matched. Phones update from HomePi →
   Settings → Apps. Commit only if the user asks.
