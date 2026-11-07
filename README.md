# mac-fn-lock

**Fn Lock for macOS: hold the `fn` key for about a second to switch the top row between F1–F12 and media keys.**

Windows laptops have an Fn Lock key. Macs only have a checkbox deep in System Settings
("Use F1, F2, etc. keys as standard function keys"). This tool flips that checkbox when you
hold `fn` (🌐) by itself.

- 🔔 You hear a sound: **Tink** means F1–F12, **Pop** means media keys (brightness, volume, playback).
- ⌨️ Using `fn` with another key (`fn`+arrow, `fn`+F5, …) never switches the mode. Only a long press of `fn` alone does.
- ⚙️ System Settings stays in sync, and the mode survives a reboot.
- 🪶 A single small Swift binary with no dependencies and no menu bar icon.

## Requirements

- macOS 13 Ventura or newer
- Xcode Command Line Tools (`xcode-select --install`) to build

## Install

```bash
git clone https://github.com/Artem-Babich/mac-fn-lock.git
cd mac-fn-lock
./install.sh
```

`install.sh` builds the binary, installs `~/Applications/FnLock.app` and adds a LaunchAgent
so it starts at login.

The first time it runs, macOS asks for **Input Monitoring** permission. Allow FnLock in
**System Settings → Privacy & Security → Input Monitoring**. The app needs this permission
to see the `fn` key, and it only listens to key events without changing or recording them.

**Recommended:** set **System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**.
Otherwise holding `fn` may also open dictation or the emoji picker.

## Uninstall

```bash
./uninstall.sh
```

## Usage

| Action | Result |
|---|---|
| Hold `fn` alone for ~1 s | Switch mode (with a sound) |
| `fnlock status` | Print the current mode |
| `fnlock toggle` | Switch once from the terminal |

The binary is at `~/Applications/FnLock.app/Contents/MacOS/fnlock` (or `.build/release/fnlock`
after building).

### Configuration

To change how long you need to hold `fn`, set `FNLOCK_HOLD_SECONDS` (default `1.0`). For the
login agent, add it under `EnvironmentVariables` in `~/Library/LaunchAgents/rs.babich.fnlock.plist`
and reload the agent:

```bash
launchctl bootout gui/$(id -u)/rs.babich.fnlock
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/rs.babich.fnlock.plist
```

Running `./install.sh` again rewrites the plist and removes this setting.

Logs go to `~/Library/Logs/fnlock.log`.

## How it works

1. A listen-only `CGEventTap` watches modifier changes, key presses and mouse clicks.
2. `FnHoldDetector` reports a "hold" when `fn` stays down for the threshold and nothing else
   is pressed in the meantime.
3. `FnKeyMode` flips the `HIDFKeyMode` parameter of `IOHIDSystem`. This is the same switch the
   System Settings checkbox uses. It also writes `com.apple.keyboard.fnState`, so the checkbox
   shows the new state.

## Development

```bash
swift build
swift test   # the tests describe how hold detection behaves
```

## Related projects

These tools switch the same setting with a shortcut, a script or per app, but none of them uses a long press of `fn`:
[FNSwitcher](https://github.com/jvosloo/FNSwitcher),
[Fluor](https://github.com/Pyroh/Fluor),
[macos-fn-toggle](https://github.com/jkbrzt/macos-fn-toggle),
[fntoggle-core](https://github.com/Edek/fntoggle-core).

## License

[MIT](LICENSE)
