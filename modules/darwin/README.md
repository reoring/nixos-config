
## Layout
```
.
├── dock               # MacOS dock configuration
├── casks.nix          # List of homebrew casks
├── default.nix        # Defines module, system-level config
├── files.nix          # Non-Nix, static configuration files (now immutable!)
├── home-manager.nix   # Defines user programs
├── packages.nix       # List of packages to install for MacOS
```

## OmniWM and Karabiner

- `../shared/config/karabiner/karabiner.edn` is the Goku source. Home Manager
  compiles it after linking the configuration, so rebuilding keeps the OmniWM
  shortcuts rather than replacing them with the old AeroSpace-only rules.
- Right Command supplies Shiftless Hyper (Control + Option + Command).
  Hyper + `qwertasdfgzxcvb` switches workspaces 1–15; adding either Shift moves
  the focused window. Hyper + M toggles the workspace bar, and Left Option +
  H/L focuses columns. The Hyper mapping and OmniWM rules exclude Parallels.
- `../shared/config/karabiner/mistel-devices.json` supplies left/right
  Option ↔ Command simple modifications for both Mistel Air One Wireless
  interfaces (`1241:1360`). They are merged into the Default profile after Goku,
  preserving other devices. With this swap, physical Right Alt supplies Hyper.
- `../shared/config/omniwm/` contains the writable runtime settings and shell
  assets. Activation backs up the existing directory before copying changes.
  A running OmniWM is quit before copying and reopened afterward to prevent it
  from writing its old settings over the restored files.
- OmniWM must already be installed at `/Applications/OmniWM.app`; IPC must stay
  enabled for the Karabiner shell commands. macOS accessibility permissions
  remain machine-local.

Validate Goku output without changing the active configuration:

```sh
GOKU_EDN_CONFIG_FILE="$PWD/modules/shared/config/karabiner/karabiner.edn" goku -A
```

## AquaSKK guard

`tools/aquaskk-guard/main.swift` is a per-user, event-driven macOS helper.
It restores ABC to the most recently selected AquaSKK mode, including AquaSKK
ASCII. It leaves other input sources alone. On first use, with no remembered
mode and ABC selected, it selects AquaSKK Hiragana if available.

Install/update from the repository root (Python 3 and Apple Command Line Tools
required; AquaSKK must already be enabled):

```sh
python3 tools/aquaskk-guard/install.py
~/.local/bin/aquaskk-guard --status
```

The installer compiles and ad-hoc signs `~/.local/bin/aquaskk-guard`, registers
`~/Library/LaunchAgents/local.reoring.aquaskk-guard.plist`, and starts it.
It runs at GUI login without an Accessibility permission request. This is an
explicit installer, not part of `darwin-rebuild`; rerun it after source changes.

The helper observes input-source and app activation notifications. It defers
while macOS Secure Input is enabled or the session is inactive/locked, checking
once per second only while deferred. Password-field protection relies on the
application enabling Secure Input; it does not inspect field contents.
It logs source IDs, frontmost app bundle IDs, notification reasons and selection
results, never keystrokes or document contents.

A failed selection is not retried until another app is activated or AquaSKK is
selected manually. Three restoration attempts in 30 seconds pause restoration
until an app switch (the rolling limit still applies). This prevents fighting
an app that repeatedly forces ABC. A disabled/missing remembered AquaSKK mode
is not silently replaced: select an available AquaSKK mode manually to recover.
Deliberately selecting ABC is also overridden; stop the agent if ABC is needed.

```sh
# Recent transition logs:
log show --last 10m --info --predicate 'subsystem == "local.reoring.aquaskk-guard"'
# Stop until next login:
launchctl bootout "gui/$(id -u)/local.reoring.aquaskk-guard"
# Start again:
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.reoring.aquaskk-guard.plist"
# Disable across logins (installer re-enables it):
launchctl disable "gui/$(id -u)/local.reoring.aquaskk-guard"
```

To uninstall, stop the agent, then remove its LaunchAgent plist and
`~/.local/bin/aquaskk-guard`. Remembered mode preferences are in
`local.reoring.aquaskk-guard`.

Live smoke verification covered ABC restoration to Hiragana and AquaSKK ASCII,
deferral during a real Secure Input session, restoration after its release,
and the three-attempt circuit breaker. Login/lock-screen and application-specific
password fields were not exercised.
