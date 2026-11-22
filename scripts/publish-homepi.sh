#!/usr/bin/env bash
# Builds the release APK and publishes it to HomePi (the two phones) and to the VPS (the
# testers' download page, anden_server milestone 7b).
# Usage: scripts/publish-homepi.sh [--no-build]
# See docs/publishing-homepi.md.
set -euo pipefail

HOST=gonza@192.168.1.195
VPS=gonza@82.165.18.227
# Owned by gonza, read-only for the anden service (anden_server/docs/deploy.md).
VPS_DIR=/opt/anden/releases
# Absolute path: "~" does not work with scp in Git Bash.
DIR=/home/gonza/homepi-docker/homepi/data/apps
# Name the phones show. Never change it: the new file must replace the old one.
NAME=Anden
APK=build/app/outputs/flutter-apk/app-release.apk

cd "$(dirname "$0")/.."

# URL and token of the own timetable server (gitignored). Without the file the app
# asks FGV only, as before. Template: config/anden_server.example.json.
DEFINES=config/anden_server.json

if [[ "${1:-}" != "--no-build" ]]; then
  if [[ -f "$DEFINES" ]]; then
    flutter build apk --release --dart-define-from-file="$DEFINES"
  else
    echo "Warning: $DEFINES missing, building without the own server." >&2
    flutter build apk --release
  fi
fi

version=$(grep '^version:' pubspec.yaml | cut -d' ' -f2)
echo "Publishing $NAME $version to $HOST"

ssh "$HOST" "mkdir -p $DIR"
# Copy under a .part name first: the hub lists only *.apk, so phones never
# see a half-copied file.
scp "$APK" "$HOST:$DIR/$NAME.apk.part"
ssh "$HOST" "mv $DIR/$NAME.apk.part $DIR/$NAME.apk"

local_sum=$(sha256sum "$APK" | cut -d' ' -f1)
remote_sum=$(ssh "$HOST" "sha256sum $DIR/$NAME.apk" | cut -d' ' -f1)
if [[ "$local_sum" != "$remote_sum" ]]; then
  echo "Checksum mismatch: the file on HomePi is not the one just built." >&2
  exit 1
fi

echo "HomePi: $DIR/$NAME.apk ($version)"

# Testers: the same APK on the VPS. The APK goes first and version.json last, so the page
# never offers a version whose file is not there yet.
echo "Publishing $NAME $version to $VPS"
version_name=${version%%+*}
version_code=${version##*+}
size=$(stat -c %s "$APK")
version_file=build/version.json
printf '{"versionCode":%d,"versionName":"%s","sha256":"%s","size":%d}\n' \
  "$version_code" "$version_name" "$local_sum" "$size" > "$version_file"
ssh "$VPS" "mkdir -p $VPS_DIR" # /opt/anden is gonza's, so no sudo
scp "$APK" "$VPS:$VPS_DIR/$NAME.apk.part"
ssh "$VPS" "mv $VPS_DIR/$NAME.apk.part $VPS_DIR/$NAME.apk"
vps_sum=$(ssh "$VPS" "sha256sum $VPS_DIR/$NAME.apk" | cut -d' ' -f1)
if [[ "$local_sum" != "$vps_sum" ]]; then
  echo "Checksum mismatch: the APK on the VPS is not the one just built. version.json not changed." >&2
  exit 1
fi
scp "$version_file" "$VPS:$VPS_DIR/version.json.part"
ssh "$VPS" "mv $VPS_DIR/version.json.part $VPS_DIR/version.json"

echo "Done: $version on HomePi and on https://anden.gonzadelarge.com/download"
