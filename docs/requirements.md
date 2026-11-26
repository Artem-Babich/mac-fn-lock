# Functional requirements

## Mode switching
- Holding `fn` alone for about a second switches the top row between F1–F12 and media keys.
- The hold time defaults to 1.0 s. It can be changed with `defaults write rs.babich.fnlock holdSeconds <s>`, or with `FNLOCK_HOLD_SECONDS`, which takes priority. Values that can't be read, or are ≤ 0, are ignored.
- A short `fn` press, or `fn` used with another key or a mouse click, never switches the mode.
- One long hold switches the mode once.
- System Settings ("Use F1, F2, etc. keys as standard function keys") stays in sync, and the mode survives a reboot.

## Feedback when the mode switches
- A sound plays: Tink for F1–F12, Pop for media keys.
- A light overlay shows for about a second, styled like the macOS volume HUD, at the bottom centre of the screen with the mouse pointer.
- The overlay reads "F1–F12" or "Media keys" (English), with an icon.
- The overlay never takes focus or blocks clicks. It shows on every Space and over full-screen apps.
- `fnlock toggle` from the terminal shows the same overlay and plays the same sound.

## Install and distribution
- Users install without Xcode: `brew install --cask fn-lock` from `Artem-Babich/tap`, or a DMG from GitHub Releases.
- The app is signed with Developer ID and notarized by Apple, and runs on Apple Silicon and Intel with macOS 13 or newer.
- No curl installer.
- Building from source with `./install.sh` keeps working.
- Bundle ID stays `rs.babich.fnlock`.
- The cask puts the `fnlock` command on PATH (`fnlock status`, `fnlock toggle`).
- The app has its own icon.

## Start at login
- On its first launch from an app bundle, the app adds itself to Login Items, once. If the user turns it off in System Settings → Login Items, it stays off.
- On launch, the app removes LaunchAgents left by older versions (`rs.babich.fnlock`, `ai.fnlock`) and stops them, so two copies never run at once.
- On first launch without Input Monitoring, FnLock asks for it and starts working as soon as it is allowed, without a restart.
- Only one listener runs at a time. Running `fnlock` while one is already running prints a message and exits.
