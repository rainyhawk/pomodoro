# Pomodoro

A macOS menu bar pomodoro timer with website + app blocking. Swift / SwiftUI / SwiftData.

- Fixed presets: 25/5, 35/7, 50/10 (long break every N focus blocks).
- Blocks distracting sites by editing `/etc/hosts` (both IPv4 and IPv6).
- Quits distracting apps via `NSRunningApplication.terminate()`.
- Stats tab tracks completed focus blocks per day via SwiftData.

## Requirements

- macOS 14 or later
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Setup

The site blocker edits `/etc/hosts`, which requires root. A one-time setup
installs a small helper script and a sudoers rule so the app can call it
without prompting for a password every focus block.

```bash
git clone <this repo> pomodoro
cd pomodoro
bash setup-sudoers.sh   # one-time: installs /usr/local/bin/pomodoro-hosts + /etc/sudoers.d/pomodoro
bash install.sh         # builds Release and installs to /Applications/Pomodoro.app
open /Applications/Pomodoro.app
```

To launch at login: System Settings → General → Login Items → add Pomodoro.

### Security note

`setup-sudoers.sh` grants your user passwordless `sudo` access to
`/usr/local/bin/pomodoro-hosts` only. That helper is restricted to applying
or clearing a marked block in `/etc/hosts`. Review `Resources/update-hosts.sh`
and `setup-sudoers.sh` before running them.

To undo:

```bash
sudo rm /etc/sudoers.d/pomodoro /usr/local/bin/pomodoro-hosts
```

## Development

```bash
xcodegen generate        # regenerate Pomodoro.xcodeproj
open Pomodoro.xcodeproj  # then Cmd-R in Xcode
```

`install.sh` re-runs `xcodegen generate` automatically.

The bundle ID defaults to `com.example.Pomodoro` — change it in `project.yml`
if you want something else.

## Layout

- `project.yml` — xcodegen spec.
- `Sources/PomodoroApp.swift` — `@main` + `MenuBarExtra`.
- `Sources/Models/` — SwiftData models (`Session`, `BlockedSite`, `BlockedApp`).
- `Sources/Services/` — `TimerEngine`, `Blocker`, `HostsManager`, `AppBlocker`.
- `Sources/Views/` — `PopoverView`, `TimerView`, `StatsView`, `BlockListView`.
- `Resources/update-hosts.sh` — privileged hosts-file editor.
- `setup-sudoers.sh` — installs the helper + sudoers rule.
- `install.sh` — Release build → `/Applications/Pomodoro.app`.
