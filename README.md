# mac-fn-lock

**Fn Lock for macOS: hold the `fn` key for half a second to switch the top row between F1–F12 and media keys.**

Windows laptops have an Fn Lock key. Macs only have a checkbox deep in System Settings
("Use F1, F2, etc. keys as standard function keys"). This tool flips that checkbox when you
hold `fn` (🌐) by itself.

- 👀 A small overlay shows the new mode for a second: **F1–F12** or **Media keys**.
- 🔔 You also hear a sound: **Tink** means F1–F12, **Pop** means media keys (brightness, volume, playback).
- ⌨️ Using `fn` with another key (`fn`+arrow, `fn`+F5, …) never switches the mode. Only a long press of `fn` alone does.
- ⚙️ System Settings stays in sync, and the mode survives a reboot.
- 🪶 A single small Swift app with no dependencies and no menu bar icon. It starts at login.

## Install

Requires macOS 13 Ventura or newer, on Apple Silicon or Intel.

```bash
brew tap artem-babich/tap
brew trust artem-babich/tap     # Homebrew requires trusting third-party taps
brew install --cask fn-lock
open -a FnLock
```

Or download `FnLock-x.y.z.dmg` from [the latest release](https://github.com/Artem-Babich/mac-fn-lock/releases/latest),
drag **FnLock** to Applications and open it. Signed and notarized by Apple.

On first launch, a **Welcome** window walks you through setup:

1. **Allow Input Monitoring.** FnLock needs it to see the `fn` key. It only listens to key events and
   never changes or records them. After you switch FnLock on in **System Settings → Privacy & Security →
   Input Monitoring**, it restarts by itself within a few seconds. "Quit & Reopen" works too.
2. **Try it:** hold `fn`, and the window shows the new mode.

You don't need to change **"Press 🌐 key to"**: a long press of `fn` doesn't switch the input source.

FnLock adds itself to **System Settings → General → Login Items** so it starts at login. If you turn it off
there, it stays off. To see the Welcome window again, open FnLock from Applications.

If you installed an older version with `./install.sh`, the new app removes its LaunchAgent on first launch,
so only one copy runs.

## Uninstall

```bash
brew uninstall --zap --cask fn-lock
```

If you installed from the DMG, quit FnLock (`pkill -x fnlock`) and move it to the Trash.

## Usage

| Action | Result |
|---|---|
| Hold `fn` alone for ~0.6 s | Switch mode (with an overlay and a sound) |
| `fnlock status` | Print the current mode |
| `fnlock toggle` | Switch once from the terminal |

Homebrew puts `fnlock` on your PATH. With the DMG, the command is at
`/Applications/FnLock.app/Contents/MacOS/fnlock`.

### Configuration

To change how long you need to hold `fn` (default `0.6` seconds):

```bash
defaults write rs.babich.fnlock holdSeconds 1.5
pkill -x fnlock && open -a FnLock
```

When you run `fnlock` from a terminal, the `FNLOCK_HOLD_SECONDS` environment variable takes priority.

Logs go to `~/Library/Logs/fnlock.log`.

## How it works

1. A listen-only `CGEventTap` watches modifier changes, key presses and mouse clicks.
2. `FnHoldDetector` reports a "hold" when `fn` stays down for the threshold and nothing else
   is pressed in the meantime.
3. `FnKeyMode` flips the `HIDFKeyMode` parameter of `IOHIDSystem`. This is the same switch the
   System Settings checkbox uses. It also writes `com.apple.keyboard.fnState`, so the checkbox
   shows the new state.

## Development

Needs Xcode Command Line Tools (`xcode-select --install`).

```bash
swift build
swift test             # the tests describe how FnLock behaves
./install.sh           # build FnLock.app from source into ~/Applications and start it
./uninstall.sh         # remove it again
swift scripts/make-icon.swift   # redraw resources/AppIcon.icns
```

Releases (maintainer): `scripts/release.sh 0.1.0` builds, signs, notarizes and checks the DMG. Adding `--publish`
also tags the version, creates the GitHub Release and opens a PR in the Homebrew tap.

## Related projects

These tools switch the same setting with a shortcut, a script or per app, but none of them uses a long press of `fn`:
[FNSwitcher](https://github.com/jvosloo/FNSwitcher),
[Fluor](https://github.com/Pyroh/Fluor),
[macos-fn-toggle](https://github.com/jkbrzt/macos-fn-toggle),
[fntoggle-core](https://github.com/Edek/fntoggle-core).

## License

[MIT](LICENSE)
