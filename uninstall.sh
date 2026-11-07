#!/bin/bash
# Stops FnLock, removes the LaunchAgent and the app.
set -uo pipefail
for LABEL in rs.babich.fnlock ai.fnlock; do # ai.fnlock = label used by older versions
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
    rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
done
rm -rf "$HOME/Applications/FnLock.app"
echo "Uninstalled. You can remove FnLock from Input Monitoring in System Settings."
