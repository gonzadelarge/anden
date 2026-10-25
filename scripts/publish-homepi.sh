#!/usr/bin/env bash
# Builds the release APK and publishes it to HomePi.
# Usage: scripts/publish-homepi.sh [--no-build]
# See docs/publishing-homepi.md.
set -euo pipefail

HOST=gonza@192.168.1.195
# Absolute path: "~" does not work with scp in Git Bash.
DIR=/home/gonza/homepi-docker/homepi/data/apps
# Name the phones show. Never change it: the new file must replace the old one.
NAME=Anden
APK=build/app/outputs/flutter-apk/app-release.apk

cd "$(dirname "$0")/.."

if [[ "${1:-}" != "--no-build" ]]; then
  flutter build apk --release
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

echo "Done: $DIR/$NAME.apk ($version)"
