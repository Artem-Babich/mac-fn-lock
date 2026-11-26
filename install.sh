#!/bin/bash
# Builds FnLock.app from source into ~/Applications and starts it.
# The app adds itself to Login Items on first launch and removes LaunchAgents left by older versions.
# Most people should install with Homebrew or the DMG instead (see README).
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/FnLock.app"

scripts/build-app.sh
pkill -x fnlock 2>/dev/null || true # restart with the new build
mkdir -p "$HOME/Applications"
rm -rf "$APP"
cp -R build/FnLock.app "$APP"
open "$APP"
echo "Installed $APP. If asked, allow FnLock in System Settings → Privacy & Security → Input Monitoring."
echo "Log: ~/Library/Logs/fnlock.log"
