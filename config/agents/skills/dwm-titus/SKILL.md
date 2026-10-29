---
name: dwm-titus
description: >-
  Install, use, and customize dwm-titus, the Arch Linux X11 desktop built on a
  patched dwm and a managed Quickshell panel. Use when installing dwm-titus on
  a fresh or existing Arch Linux system, or for end-user tasks on an installed
  system: keybindings (hotkeys.toml), window rules, themes, wallpaper, fonts,
  panel widgets, monitors and displays, input devices, power and screen lock,
  the Picom compositor, default apps (browser, terminal, file manager),
  installing or removing apps (pacman, AUR, Flatpak, AppImage, web apps),
  autostart, system and desktop updates, diagnostics, and recovery. Triggers:
  dwm, dwm-titus, Quickshell panel, Super key shortcuts, ~/.config/dwm-titus/.
  Not for developing the dwm-titus source itself; follow the repository
  AGENTS.md for that.
---

# dwm-titus

dwm-titus is a complete X11 desktop for Arch Linux. It has three layers:

- `dwm`, a small C window manager. Hotkeys, window rules, and themes come from
  TOML files that reload live when saved.
- Shell helpers (`dwm-*` commands on `PATH`) that own every desktop policy and
  all system access.
- A Quickshell panel, launcher, Control Center, Settings, and Update Center.
  The UI never touches the system directly; it calls the helpers.

Source: https://github.com/moheladwy/dwm-titus-archlinux

## Topic guides

Read the matching guide before acting. They live next to this file.

- [`install.md`](install.md): install on a fresh or minimal Arch system
  (including servers driven over SSH) or on an existing Arch desktop.
- [`configuration.md`](configuration.md): keybindings, window rules, themes,
  wallpaper, fonts, screenshots, brightness keys, panel, displays, input,
  power, compositor, and compile-time `config.h` options.
- [`apps.md`](apps.md): install, remove, and replace applications; default
  apps; web apps; autostart; launching apps from a key.
- [`maintenance.md`](maintenance.md): system, AUR, and desktop updates,
  diagnostics, logs, recovery, and reinstalling.

## Orient yourself first

Run these read-only checks before changing anything:

```sh
. /etc/os-release && printf '%s\n' "$ID"   # must print exactly: arch
uname -m                                   # must print: x86_64
command -v dwm dwm-diagnostics             # present once installed
pgrep -x dwm >/dev/null && echo "dwm session running"
cat "${XDG_STATE_HOME:-$HOME/.local/state}/dwm-titus/desktop-update/installed.json" 2>/dev/null
```

`installed.json` records the `checkout` directory and Git `revision` the
desktop was installed from. Compile-time changes and reinstalls run from that
checkout. After an update through Settings > Desktop updates, `checkout` is
empty (`""`): the desktop then has no local clone. Ask the user where their
clone is, or make a fresh one (see `maintenance.md`); never `cd ""`.

## Critical safety rules

1. **Arch Linux only.** Continue only when `/etc/os-release` has exactly
   `ID=arch`. `ID_LIKE` does not count. EndeavourOS, CachyOS, Manjaro, Arch
   Linux ARM, and every other system are unsupported, and there is no
   override. Say so and stop; do not patch around the check.
2. **No partial upgrades.** Never run `pacman -Sy` on its own. Never run
   `pacman -S <pkg>` while updates are pending. Install packages together
   with a full upgrade: `sudo pacman -Syu --needed <pkg>...`.
3. **Never pass `--noconfirm`** to pacman, and never use the installer's
   `--non-interactive` mode (which adds it), unless the user explicitly asks
   for an unattended run. Never delete `/var/lib/pacman/db.lck`.
4. **AUR is opt-in.** Use an AUR helper (`paru` or `yay`) only if one is
   already installed and the user asked for an AUR package. Run it as the
   user, never with `sudo` or as root. Never install an AUR helper on your
   own, and never send official packages through it.
5. **Never run the installer, `make install`, or user helpers as root.** The
   installer refuses root and calls `sudo` itself only where needed. Never
   run a plain `sudo make install`; the Makefile refuses it without
   `OWNER`.
6. **Do not edit managed files.** Installs and updates replace them:
   - `~/.config/quickshell/` (the whole directory)
   - `~/.local/share/dwm-titus/` (managed copy of `config/` and `scripts/`)
   - `/usr/local/bin/dwm*` and the other installed helpers
   - `/usr/local/libexec/dwm-titus/` (root-owned privileged helpers)
   - `/etc/lightdm/lightdm.conf.d/50-dwm-titus.conf` and
     `/etc/lightdm/slick-greeter.conf` (when LightDM is in use)

   Reading them is safe and useful. To change the panel or a helper, change
   the source checkout and resync (see `configuration.md`).
7. **Back up user files before editing:**
   `cp -a FILE "FILE.bak.$(date +%s)"`. Prefer a `dwm-*` command over editing
   by hand when one exists, because the commands validate input and keep
   recovery copies.
8. **Ask before** resetting configuration, removing packages, changing the
   display manager, writing Xorg configuration, editing PAM, or anything
   under `/etc`. The project never edits `pacman.conf`, PAM files, the
   bootloader, the firewall, or LSM state, and neither should you without an
   explicit request.

## Privilege escalation

`pacman` and `systemctl` on system units need root. System file
installation needs root only through `./install.sh` or
`./scripts/dev-sync-install.sh`, which call `sudo make install` themselves
with `OWNER` and `USER_HOME` set. Before you run a root command, check
whether `sudo` can work without a password prompt:

```sh
sudo -n true 2>/dev/null && echo "sudo ready" || echo "sudo needs a password"
```

If it needs a password and you cannot answer prompts, do not work around it
(no `pkexec pacman`, no `--noconfirm`, no sudoers edits). Give the user the
exact command and ask them to run it in their own terminal. Then continue
from the result. Settings and System Health use polkit for their own
allowlisted privileged actions; leave those to the UI.

## Where things live

| Path | Owner | Notes |
| --- | --- | --- |
| `~/.config/dwm-titus/hotkeys.toml` | user | Keybindings. Live reload on save. |
| `~/.config/dwm-titus/window-rules.toml` | user | Window rules. Live reload on save. |
| `~/.config/dwm-titus/themes.toml` | user | Active theme, border size, custom themes. Live reload. |
| `~/.config/dwm-titus/*.conf`, `*.json`, `display-profiles/` | helpers | Power, panel widgets, input, fonts, notifications, display profiles. Change these through their commands. |
| `~/.config/alacritty/`, `kitty/`, `starship/` | user | Seeded once if missing, then never overwritten. |
| `~/.config/picom.conf` | user | Not seeded. Settings > Appearance > Compositor > Create user configuration copies the system file (see `configuration.md`). |
| `~/.config/quickshell/` | managed | Replaced on every install and update. |
| `~/.local/share/dwm-titus/` | managed | Managed copy of the source `config/` and `scripts/`. |
| `<checkout>/config.h` | user | Compile-time options. Preserved; rebuild after editing. |
| `~/.xinitrc` | user | Seeded for `startx` only if missing. |

`$XDG_CONFIG_HOME` replaces `~/.config` when it is set.

## Command discovery

Installed helpers are on `PATH` (prefix `/usr/local` by default):

```sh
compgen -c dwm- | sort -u      # list helpers (bash)
sed -n '1,40p' "$(command -v dwm-default-apps)"   # read a helper's source
```

Most helpers print a usage line when run with no arguments or a wrong one.
Many are machine-oriented providers for the Settings UI (`snapshot`, `watch`,
`preview TOKEN SECONDS ...`, `keep TOKEN`, `revert TOKEN`). Read the source
before calling an unfamiliar subcommand; do not guess.

Everyday entry points:

| Command | Purpose |
| --- | --- |
| `dwm-settings open` | Open Settings |
| `dwm-controlcenter` | Toggle the Control Center (`Super+F1` opens it) |
| `dwm-diagnostics` | Required and optional health checks |
| `dwm-default-apps status` | Default browser, terminal, file manager |
| `dwm-settings-theme apply NAME` | Switch theme |
| `dwm-settings-wallpaper apply PATH FIT` | Set the wallpaper |
| `dwm-panel-settings status` | Panel widget visibility |
| `dwm-update-center launch system` | Open the system update terminal |
| `dwm-quickshell-controlcenter action restart-quickshell` | Restart the panel |
| `dwm-settings-picom restart` | Restart the compositor |

Press `Super+/` in the session for a searchable list of the live keybindings.

## Decision framework

1. **Installing dwm-titus?** Follow `install.md`. Dry-run first.
2. **A helper or a Settings page covers it?** Use that. Settings, the Control
   Center, and the `dwm-*` commands validate input and keep recovery data.
3. **A key, rule, or theme change?** Edit the TOML in `~/.config/dwm-titus/`
   and save. It reloads live. See `configuration.md`.
4. **A new app?** Official repositories first, then Flatpak, then AUR (only
   with an existing helper), then AppImage or a web app. See `apps.md`.
5. **A compile-time option (`config.h`) or panel/helper code?** Edit the
   source checkout and resync with `scripts/dev-sync-install.sh`. See
   `configuration.md`.
6. **Updates or something broken?** See `maintenance.md`. Start with
   `dwm-diagnostics`.
7. **Unsure whether a command exists?** List the `dwm-*` helpers and read the
   source. Do not invent commands or flags.

## Out of scope

- Developing dwm-titus itself (changing tests, opening pull requests,
  release work). Follow the repository `AGENTS.md`, `SPEC.md`, and
  `CONTRIBUTING.md` instead.
- Non-Arch systems and Arch derivatives.
- Wayland sessions. dwm-titus is X11 only.
- Gaming integrations, installer images, and third-party pacman
  repositories. The project ships none of these.

## Example requests

- "Install dwm-titus on this fresh Arch box" -> `install.md`, section A.
- "Add dwm-titus to my existing Arch desktop" -> `install.md`, section B.
- "Bind Super+Shift+F to Firefox" -> check `hotkeys.toml` for a clash, then
  add `{ mod="SUPER SHIFT", key="f", desc="Firefox", func="spawn", exec=["firefox"] },`.
- "Switch to the dracula theme" -> `dwm-settings-theme apply dracula`.
- "Make the borders thicker" -> set `borderpx = 2` under `[appearance]` in
  `themes.toml`.
- "Always open Steam on tag 5" ->
  `{ class="steam", tags=5 },` in `window-rules.toml` (check the class with
  `xprop WM_CLASS` first). Classes match as substrings, so this also sends
  every Steam game (`steam_app_NNN`) to tag 5; say so.
- "Use kitty as my terminal" -> `sudo pacman -Syu --needed kitty`, then
  `dwm-default-apps set-role terminal kitty.desktop`.
- "Make Firefox my default browser" ->
  `dwm-default-apps set-browser firefox.desktop`.
- "Install Spotify" -> `sudo pacman -Syu --needed spotify-launcher` (official
  `extra` repository). See `apps.md`.
- "Install Slack" -> not in the official repositories, so Flatpak:
  `flatpak install --user flathub com.slack.Slack`.
- "Update my system" -> `dwm-update-center launch system`, or hand the user
  `sudo pacman -Syu`.
- "The panel disappeared" ->
  `dwm-quickshell-controlcenter action restart-quickshell`, then
  `dwm-diagnostics`.
