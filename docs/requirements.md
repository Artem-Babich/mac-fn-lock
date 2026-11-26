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
- FnLock never asks for Input Monitoring by itself at launch. It asks only from the Welcome window.
- Once Input Monitoring is allowed, FnLock restarts itself within a few seconds and starts working. The user doesn't need "Quit & Reopen", and choosing "Later" doesn't leave it broken.
- A restarted copy waits for the old one to exit, so a restart never leaves FnLock stopped.
- Only one listener runs at a time. Running `fnlock` while one is already running prints a message and exits.

## Welcome window
- Opens at launch until setup has been finished once, and on every launch while Input Monitoring is missing.
- Opening FnLock again (Finder, Launchpad, Spotlight) while it runs brings the window back.
- The window is in English and shows two steps:
  1. Allow Input Monitoring.
  2. Try it: hold fn. The window shows the current mode.
- Step 2 is locked until step 1 is done.
- FnLock doesn't ask the user to change "Press 🌐 key to". A long press doesn't trigger Change Input Source (checked on macOS 27).
- The first click on "Allow…" shows only the macOS permission prompt, which has its own "Open System Settings" button. After that, the button reads "Open System Settings" and opens Input Monitoring itself.
- Step 1 explains that either "Quit & Reopen" or "Later" works, because FnLock restarts by itself.
- Each step ticks itself off: step 1 when Input Monitoring is allowed, step 2 after the first switch.
- "Done" is available once Input Monitoring is allowed.
- Setup is finished only when the user clicks Done or closes the window. The window closing because FnLock quits or restarts ("Quit & Reopen") doesn't finish setup, so the window comes back after the restart.
