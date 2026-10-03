#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="DeepPeak"
DIST="dist/$APP_NAME.app"
CONTENTS="$DIST/Contents"

# --universal builds arm64 + x86_64 (what the release workflow ships); the default
# is the host architecture.
BUILD_ARGS=(-c release)
if [ "${1:-}" = "--universal" ]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

rm -rf "$DIST"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

swift build "${BUILD_ARGS[@]}"

BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"
cp "$BIN_PATH" "$CONTENTS/MacOS/$APP_NAME"
cp packaging/Info.plist "$CONTENTS/Info.plist"
# The holiday calendar ships with the app; SwiftPM bundles carry no resources for
# a bare executable, so it is copied in by hand.
cp holidays.json "$CONTENTS/Resources/holidays.json"

# Ad-hoc sign so it launches cleanly locally (no Gatekeeper prompt).
codesign --force --sign - "$DIST"

echo "Built $DIST"
