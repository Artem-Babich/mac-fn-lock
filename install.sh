#!/bin/bash
# Builds FnLock.app into ~/Applications and starts it at login via a LaunchAgent.
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/FnLock.app"
PLIST="$HOME/Library/LaunchAgents/rs.babich.fnlock.plist"
LABEL="rs.babich.fnlock"

swift build -c release
mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp .build/release/fnlock "$APP/Contents/MacOS/fnlock"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>FnLock</string>
  <key>CFBundleExecutable</key><string>fnlock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier "$LABEL" "$APP"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/fnlock</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/fnlock.log</string>
</dict></plist>
PLIST

# Remove the agent from versions that used the old "ai.fnlock" label.
launchctl bootout "gui/$(id -u)/ai.fnlock" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/ai.fnlock.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed. If asked, allow FnLock in System Settings → Privacy & Security → Input Monitoring."
echo "Log: ~/Library/Logs/fnlock.log"
