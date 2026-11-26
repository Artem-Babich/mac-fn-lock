#!/bin/bash
# Removes a FnLock built with install.sh. For Homebrew: brew uninstall --zap --cask fn-lock.
set -uo pipefail
pkill -x fnlock 2>/dev/null
for LABEL in rs.babich.fnlock ai.fnlock; do # LaunchAgents written by older versions of install.sh
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
    rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
done
rm -rf "$HOME/Applications/FnLock.app"
echo "Uninstalled. You can remove FnLock from Input Monitoring in System Settings."
