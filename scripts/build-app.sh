#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) build/FnLock.app, signed.
#   scripts/build-app.sh                                         local build (Apple Development if present, else ad-hoc)
#   VERSION=1.2.3 SIGN_ID="Developer ID Application: …" scripts/build-app.sh   release build (called by release.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

# A stable identity keeps the Input Monitoring grant across rebuilds.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')}"
SIGN_ID="${SIGN_ID:--}"
# Notarization needs a secure timestamp; local builds skip the network round-trip.
if [[ "$SIGN_ID" == Developer\ ID* ]]; then TIMESTAMP=--timestamp; else TIMESTAMP=--timestamp=none; fi

# One build per arch, then lipo: `--arch arm64 --arch x86_64` switches SwiftPM to the Xcode build
# system, which fails inside sandboxed shells. SWIFTPM_FLAGS="" drops --disable-sandbox.
for arch in arm64 x86_64; do
  swift build -c release --product fnlock --arch "$arch" ${SWIFTPM_FLAGS---disable-sandbox}
done

APP=build/FnLock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create .build/arm64-apple-macosx/release/fnlock .build/x86_64-apple-macosx/release/fnlock \
  -output "$APP/Contents/MacOS/fnlock"
cp resources/Info.plist "$APP/Contents/Info.plist"
cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-$VERSION}" "$APP/Contents/Info.plist"
fi

# No entitlements: a listen-only event tap needs only the Input Monitoring grant.
codesign --force --options runtime $TIMESTAMP --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=1 "$APP"
echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/fnlock"); signed with: $SIGN_ID)"
