#!/usr/bin/env bash
# Build, sign with Developer ID, notarize and package FnLock as a DMG; optionally publish.
#
#   scripts/release.sh 1.2.3             dry run: tests, build, notarize app + DMG → dist/ (nothing published)
#   scripts/release.sh 1.2.3 --publish   …then tag v1.2.3, GitHub Release with the DMG, PR in the Homebrew tap
#
# One-time machine setup (see the macos-app-release skill): "Developer ID Application" identity
# in the login keychain, a notarytool keychain profile, gh logged in.
# The profile name lives in a git-ignored .release.env (NOTARY_PROFILE=<profile>) — no local names in a public repo.
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- per-app config -------------------------------------------------------------------------
APP_NAME="${APP_NAME:-FnLock}"                      # .app / DMG / volume name
CASK="${CASK:-fn-lock}"                             # Homebrew cask token (lowercase)
REPO="${REPO:-Artem-Babich/mac-fn-lock}"                   # GitHub repo with releases
TAP_REPO="${TAP_REPO:-Artem-Babich/homebrew-tap}"       # shared tap for all apps
[[ -f .release.env ]] && source .release.env      # local, git-ignored: NOTARY_PROFILE=…
NOTARY_PROFILE="${NOTARY_PROFILE:?set NOTARY_PROFILE in .release.env}"
APP="${APP_PATH:-build/$APP_NAME.app}"               # what BUILD produces
TEST() { swift test ${SWIFTPM_FLAGS---disable-sandbox}; }                           # e.g. swift test --disable-sandbox | npm test | true
BUILD() { scripts/build-app.sh; }                         # must produce "$APP" signed with $SIGN_ID, hardened runtime, --timestamp, version $VERSION
# ---------------------------------------------------------------------------------------------

VERSION="${1:?usage: scripts/release.sh <version> [--publish]}"
PUBLISH="${2:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 1; }
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
[[ -n "$SIGN_ID" ]] || { echo "no 'Developer ID Application' identity in the keychain" >&2; exit 1; }
export VERSION SIGN_ID
DIST=dist
DMG="$DIST/$APP_NAME-$VERSION.dmg"

if [[ "$PUBLISH" == "--publish" ]]; then
  [[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean" >&2; exit 1; }
  [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "publish from main" >&2; exit 1; }
  git fetch -q origin
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "main differs from origin/main" >&2; exit 1; }
  ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || { echo "tag v$VERSION already exists" >&2; exit 1; }
elif [[ -n "$PUBLISH" ]]; then
  echo "unknown option: $PUBLISH" >&2; exit 1
fi

# notarytool exits 0 even when Apple rejects the upload — check the final status explicitly.
notarize() {
  local out
  # Usually 1–5 min; a new team's first submission can take an hour.
  out=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --timeout "${NOTARY_TIMEOUT:-2h}" 2>&1) || true
  echo "$out" | grep -E "id:|status:" | tail -3
  if ! echo "$out" | grep -q "status: Accepted"; then
    local id; id=$(echo "$out" | awk '/^ *id:/{print $2; exit}')
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    echo "notarization failed for $1" >&2
    exit 1
  fi
}

echo "▶ tests";  TEST
echo "▶ build $VERSION, signed with: $SIGN_ID"; BUILD
codesign --verify --deep --strict "$APP"
rm -rf "$DIST" && mkdir -p "$DIST"

echo "▶ notarize the app (stapled, so it opens offline after leaving the DMG)"
ditto -c -k --keepParent "$APP" "$DIST/$APP_NAME.zip"
notarize "$DIST/$APP_NAME.zip"
xcrun stapler staple -q "$APP"
rm "$DIST/$APP_NAME.zip"

echo "▶ DMG"
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
notarize "$DMG"
xcrun stapler staple -q "$DMG"

echo "▶ Gatekeeper check"
spctl --assess --type execute -vv "$APP" 2>&1 | head -2
spctl --assess --type open --context context:primary-signature -vv "$DMG" 2>&1 | head -2
SHA256=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
echo "✔ $DMG  sha256=$SHA256"

[[ "$PUBLISH" == "--publish" ]] || { echo "dry run: nothing published (add --publish)"; exit 0; }

echo "▶ GitHub Release v$VERSION"
git tag -a "v$VERSION" -m "$APP_NAME $VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "$APP_NAME $VERSION" --generate-notes

echo "▶ Homebrew tap PR"
TAP=$(mktemp -d)
gh repo clone "$TAP_REPO" "$TAP" -- -q
mkdir -p "$TAP/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA256/" "resources/$CASK.rb.template" > "$TAP/Casks/$CASK.rb"
git -C "$TAP" switch -q -c "$CASK-$VERSION"
git -C "$TAP" add "Casks/$CASK.rb"
# Optional: this app's old cask names → merge into the tap's shared cask_renames.json, drop old files.
if [[ -f resources/cask_renames.json ]]; then
  python3 - "$TAP/cask_renames.json" resources/cask_renames.json <<'PY'
import json, os, sys
tap, mine = sys.argv[1], sys.argv[2]
merged = json.load(open(tap)) if os.path.exists(tap) else {}
merged.update(json.load(open(mine)))
json.dump(merged, open(tap, "w"), indent=2, sort_keys=True); open(tap, "a").write("\n")
PY
  for old in $(python3 -c 'import json; print(" ".join(json.load(open("resources/cask_renames.json"))))'); do
    git -C "$TAP" rm -q --ignore-unmatch "Casks/$old.rb"
  done
  git -C "$TAP" add cask_renames.json
fi
git -C "$TAP" commit -q -m "$CASK $VERSION"
git -C "$TAP" push -q origin "$CASK-$VERSION"
gh pr create --repo "$TAP_REPO" --head "$CASK-$VERSION" --title "$CASK $VERSION" \
  --body "Release: https://github.com/$REPO/releases/tag/v$VERSION"
rm -rf "$TAP"
echo "✔ released v$VERSION — merge the tap PR so 'brew install --cask $CASK' picks it up"
