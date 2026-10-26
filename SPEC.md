# dwm-titus Project Specification

## 1. Product Definition

dwm-titus is an Arch Linux-only desktop environment for X11. It combines a
small, maintained fork of suckless dwm with runtime-configurable hotkeys,
themes, and window rules, a managed Quickshell shell and Settings layer, and
supporting desktop services and helpers.

This repository (`github.com/moheladwy/dwm-titus-archlinux`) is a fork of
`ChrisTitusTech/dwm-titus` that replaces Fedora with Arch Linux as the only
supported platform. The product is a cohesive desktop installed onto an
existing Arch Linux system. Users install Arch Linux themselves with the
official Arch ISO (manually or with `archinstall`), then run `./install.sh`
from a checkout of this repository. The project ships no installer image.
Other distributions, including Arch derivatives, are outside the supported
product and validation contract.

## 2. Goals

- Turn a minimal, current Arch Linux installation into a complete,
  daily-usable X11 desktop with one installer run.
- Provide one cohesive Settings experience for common display, input,
  connectivity, audio, power, appearance, default-application, update, and
  system-information workflows.
- Build and run the complete dwm-titus desktop on current Arch Linux.
- Provide safe, idempotent dependency installation and system integration that
  never leaves the system in an unsupported partial-upgrade state.
- Preserve the speed, simplicity, and direct configuration model of dwm.
- Provide consistent defaults and complete Settings behavior on Arch Linux.
- Support display-manager login and `startx`.
- Support Arch Linux x86_64. Other architectures, including Arch Linux ARM,
  are not supported.
- Keep user configuration under standard XDG paths and preserve it on upgrade.

## 3. Non-Goals

- A Wayland compositor or Wayland-native session.
- Pixel-identical behavior across every theme, driver, display manager, or
  third-party desktop utility.
- Automatic installation of proprietary GPU drivers.
- Automatic bootloader, Plymouth, firewall, kernel, initramfs, or PAM changes.
- Turning the Settings frontend into a general-purpose root shell, service
  editor, firewall editor, or partition manager.
- Bundling every optional desktop application.
- Installer images of any kind (ISO, archiso, offline, or NVIDIA variants).
- Hosted infrastructure: a project pacman repository, prebuilt AUR packages,
  download servers, or repository and image signing keys.
- Gaming integrations, including Steam, Gamescope, GameMode, MangoHud, and the
  `multilib` repository.
- Arch Linux derivatives (for example EndeavourOS, CachyOS, Manjaro, and Arch
  Linux ARM) and every other distribution.
- Bootstrapping an AUR helper, or making any AUR package a requirement.

## 4. Arch Linux Support Contract

The sole supported platform is Arch Linux:

| Target | Current contract |
| --- | --- |
| Base system | Arch Linux installed by the user from the official Arch ISO or `archinstall` |
| Installation path | `./install.sh` from a checkout of this repository |
| Package source | Official Arch repositories (`core`, `extra`) through pacman |
| Session | Xorg with dwm and the managed Quickshell shell |
| Architecture | x86_64 |
| Release model | Rolling; there is no supported version number |

The installer and every platform-aware helper must read `/etc/os-release` and
accept only `ID=arch`. `ID_LIKE` is ignored. Every derivative (including
EndeavourOS, CachyOS, Manjaro, and Arch Linux ARM) and every other
operating-system identity must be rejected with a clear message before any
package installation or system change. There is no override flag. Arch Linux
does not set `VERSION_ID`; its absence is expected and must not be treated as
an error.

The project hosts nothing. There are no installer images, project package
repositories, download servers, or signing keys. Source releases may be
published as optional GitHub release tarballs (`make release`).

Arch Linux does not configure SELinux or another mandatory access control
policy by default. The installer must never change host LSM state.

Fedora is not supported by this fork, and no Fedora-specific code, Kickstarts,
or image tooling remain in the tree.

## 5. Functional Requirements

### 5.1 Window Manager

The installed session must provide:

- Standard dwm tiling, floating, monocle, tagging, focus, and monitor behavior.
- Per-tag layout state and sizing.
- EWMH desktop and active-window integration for external bars and tools.
- Xinerama multi-monitor support.
- Window swallowing.
- Per-client size factors and stack reordering.
- Real and fake fullscreen behavior. A managed window matching a
  `fullscreen=1` TOML rule opens in true fullscreen on its assigned monitor,
  with zero borders and no reserved panel area. The rule applies at management
  time or once when a title first matches a fullscreen rule. It preserves normal
  fullscreen exit and does not change the tag layout. Late title matching does
  not reassign tags or monitors. A `fakefullscreen=1` rule uses the same
  monitor-sized borderless geometry and panel hiding without advertising
  `_NET_WM_STATE_FULLSCREEN`. It takes precedence over `fullscreen=1` in the
  same rule. While active, application fullscreen requests do not advertise
  fullscreen or cancel the geometry; `togglefakefullscreen` exits to the saved
  window state. The existing fake-fullscreen shortcut behavior is otherwise
  unchanged. Neither rule modifies application settings files.
- A managed window rule with `ignoresizehints=1` bypasses ICCCM min/max/base,
  increment, and aspect size constraints and disables fixed-hint auto-floating.
  Last matching rule wins; only integer `1` enables it. Reevaluate on title
  changes, retain the setting with its window across swallowing, and preserve
  existing size-hint behavior when disabled. It does not change application
  rendering resolution.
- Unmanaged overlays explicitly matched by an `alwaysontop=1` runtime rule
  appear above real fullscreen clients without becoming managed or taking focus.
  Ordinary shell popups and EWMH above hints retain their existing priority.
- Window icons from `_NET_WM_ICON`.
- Configured border suppression and cursor-warp behavior.
- Stable handling of applications that omit optional X properties.

### 5.2 Runtime Configuration

The product must load user configuration from:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/
```

The supported runtime files are:

- `hotkeys.toml`
- `themes.toml`
- `window-rules.toml`

Changes to these files must reload without restarting dwm when the existing
inotify-based hot reload path is available. Invalid configuration must produce
an actionable error and retain safe defaults or the last valid state.

Compile-time defaults remain in `config.def.h`. An existing `config.h` is user
owned and must not be overwritten during installation or upgrade.

Quickshell configuration is a managed shell-layer artifact owned by dwm-titus.
During installation, `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/` must be
replaced from the tracked `config/quickshell/` directory so the running shell
does not fall behind repository behavior. User-owned dwm TOML files remain
preserved, but users should not place unrelated personal configuration under
the dwm-titus-managed Quickshell directory. Quickshell integrations must use
event-driven updates whenever a state source provides a signal, subscription,
watch mode, IPC stream, or service API. Polling timers are acceptable only for
inherently sampled values, such as a clock or CPU load, or as documented
fallbacks when no event source exists. The managed Quickshell shell must remain
low overhead while idle: hidden launcher UI must not continuously filter or
render application models, timer-triggered helper processes must not overlap,
and only one shell provider should run in the dwm-titus session. On X11, the
managed shell must create one `PanelWindow` for every active screen so each
monitor has a bar. The per-screen Quickshell `Variants` design must share its
state providers and be explicitly profiled to show that it remains near idle.

The managed shell requires Quickshell 0.3.0 or newer, installed from the
official Arch `extra` repository. Because Arch is a rolling release, the
version check must also warn when it detects an untested Quickshell major
version instead of silently accepting it. Update Center opens as a popup anchored beneath its panel icon,
with content-based sizing and bounds clamped to the active screen. Its
Settings tab offers a persistent Float update terminal toggle that applies to
the next update or recovery terminal; those terminals default to tiled.
Update Center and the other anchored control popups must close on Escape and
on a click outside their visible card under X11.
Visible shell surfaces must be opaque and follow the active theme selected in
the user `themes.toml` file.

### 5.3 Session Startup

The project must support:

- A display-manager session installed as `dwm.desktop`.
- A `startx` flow whose `.xinitrc` launches dwm in a D-Bus session.
- Startup without Picom, a wallpaper, or a polkit agent.
- Detection of common polkit agent locations across `/usr/lib`,
  `/usr/lib64`, and `/usr/libexec` layouts.
- Startup helpers that do not create duplicate long-running processes when the
  session is restarted.

Missing optional components must be logged or skipped without terminating dwm.

Display-manager integration (the `full` profile) uses LightDM with
`lightdm-slick-greeter`. The installer adds the drop-in
`/etc/lightdm/lightdm.conf.d/50-dwm-titus.conf` (`[LightDM]`
`logind-check-graphical=true`; `[Seat:*]` `greeter-session=lightdm-slick-greeter`
and `user-session=dwm`) and never creates, modifies, or backs up
`/etc/lightdm/lightdm.conf`. LightDM reads `lightdm.conf` after its drop-ins,
so values the user sets there take precedence, and
`session-wrapper=/etc/lightdm/Xsession` comes from Arch's packaged
`lightdm.conf`. Enabling the display-manager service must be visible to the
user.

The default screenshot-to-clipboard binding must capture through the managed
`dwm-screenshot` helper. On X11, the helper must use `maim` to capture without
the mouse cursor and transfer region captures as raw PNG data to an
`xclip`-owned clipboard selection. It must not depend on a resident screenshot
daemon or a GUI-toolkit clipboard owner. Saved captures use JPEG, and a full
monitor capture targets the monitor under the pointer. The recommended desktop
profile must install `maim` when it is available and keep the core install
usable when it is not. `xclip` remains a required runtime package because
other shell features also use the X11 clipboard.

### 5.4 Quickshell Launcher

The Quickshell shell layer must provide the normal X11-compatible application
launching workflow.

The launcher must:

1. Open, close, and toggle through Quickshell IPC so dwm keybindings can
   control it without depending on Wayland global shortcuts.
2. Index desktop applications from the XDG `.desktop` application directories.
3. Ignore hidden, `NoDisplay=true`, and non-application desktop entries.
4. Provide a search-first UI with keyboard focus on open.
5. Filter by application name, generic name, and comment.
6. Support keyboard navigation, mouse activation, Escape-to-close, and
   close-on-launch behavior.
7. Launch applications through a helper that prefers standard desktop-entry
   launchers when available and preserves a terminal fallback for
   `Terminal=true` entries.
8. Avoid Wayland-only shell, compositor, layer-shell, or global-shortcut APIs.
9. Release application-list resources while closed so the launcher does no
   repeated filtering or rendering work when hidden.

The launcher may follow a modular QML structure with small helper scripts,
IPC-facing open/close/toggle functions, and reusable list/delegate patterns,
but X11/EWMH behavior remains the compatibility boundary for this project.

### 5.5 Installer

The supported installation flow must:

1. Read `/etc/os-release`, require `ID=arch`, and reject every other identity
   before making changes. Require `pacman`. If standard input is not a
   terminal, refuse before any change unless `--non-interactive` or
   `--dry-run` was given; a redirected standard output never changes the
   interaction mode.
2. Resolve Arch package names from one maintained dependency map.
3. Show required and optional packages before installing them. The plan,
   including the system upgrade in step 4, appears in `--dry-run` output.
4. Run exactly one visible `sudo pacman -Syu` before any package installation,
   as described in Section 5.11. Abort the installation if it fails.
5. Install only missing required packages unless the user requests a broader
   desktop setup.
6. Create a missing `config.h` from guided compile-time questions, or detected
   and documented defaults for an unattended installation. Preserve an
   existing `config.h`.
7. Build dwm with the system compiler and detected X11 flags.
8. Install the binary, man page, X session file, scripts, and default
   configuration.
9. Seed missing user configuration while preserving existing files.
10. Install Celluloid, mpv, and sxiv in every profile. Seed fresh-account
    audio/video and image MIME defaults using Celluloid and sxiv respectively;
    preserve existing MIME preference files. The fresh-account
    `inode/directory` default is Dolphin (`org.kde.dolphin.desktop`), which
    the `full` profile installs.
11. Set ownership to the invoking user for files in that user's home.
12. Support repeated execution without destructive side effects.
13. Print a summary, skipped optional features, and actionable next steps.
14. Offer interactive Xorg display setup when installation runs inside an
    active X11 session. The setup must support resolution, refresh rate,
    position, rotation, primary-output selection, and compatible TearFree
    drivers; preview changes with rollback; and preserve existing system Xorg
    configuration through an isolated managed fragment and backups. When no
    X11 session is available, print the deferred setup command instead.

The installer profiles are `core`, `recommended`, and `full`. `full` adds the
Dolphin file manager, wallpaper, and display-manager integration to
`recommended`. There is no gaming profile. Recommended and full profiles may
add the official Flathub remote for the target user and install Gear Lever
(`it.mijorus.gearlever`) as the default AppImage manager. The installer must
not enable any other third-party repository, must not enable `multilib`, and
must not edit `/etc/pacman.conf`.

AUR packages are optional and follow the AUR policy in Section 5.11. The
installer uses an AUR helper only when the user opts in with `--enable-aur`
and a supported helper is already installed. Interactive runs may instead ask
an explicit y/N question that defaults to No; `--non-interactive` without
`--enable-aur` never uses the AUR.

A source-checkout update of an existing live installation must use the complete
supported install path. Updating only the `dwm` executable is not a supported
upgrade because it can leave installed helpers, session scripts, the managed
Quickshell tree, and the user data copy at a different repository revision.
When development is performed on a machine running dwm-titus, the
repository-owned `scripts/dev-sync-install.sh` command must synchronize the
checkout to that machine's local live installation before the work is handed
off or considered complete. The command is idempotent and must enforce this
contract for every developer deployment. Every live update must:

1. Build the checked-out revision successfully before replacing installed
   files.
2. Install the system files and refresh
   `${XDG_DATA_HOME:-$HOME/.local/share}/dwm-titus/` and the managed
   `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/` tree from that same
   revision while preserving the user-owned dwm TOML files.
3. Verify the installed binary and the managed Quickshell, data, and script
   trees against the checkout instead of inferring freshness from a clean Git
   worktree.
4. Restart Quickshell through the managed control path and verify its process,
   IPC endpoints, and tray host when no full session restart is pending. If the
   running dwm executable was replaced, defer Quickshell activation to the
   required session restart so the tray host starts before tray clients, and
   distinguish installed state from active runtime state.
5. After a required session restart, verify that the new dwm executable is
   active and that the graphical-session and XDG autostart lifecycle starts
   tray clients for the new X11 session.

### 5.6 Build System

The build must:

- Use a C99-capable compiler and `make`.
- Honor standard environment overrides including `CC`, `CFLAGS`, `CPPFLAGS`,
  `LDFLAGS`, `PREFIX`, and `DESTDIR`.
- Discover compiler and linker flags with `pkg-config` where available.
- Avoid mandatory `/usr/X11R6`, `/usr/lib`, or `/usr/lib64` assumptions.
- Produce a working `dwm` binary from a clean checkout.
- Support staged, unprivileged installation through `DESTDIR`.

Required native interfaces and libraries currently include:

- Xlib
- Xft and Fontconfig
- Xinerama
- Xrender
- Imlib2
- Xlib-XCB
- XCB and XCB RES
- freetype headers
- standard Linux/POSIX process and filesystem interfaces

### 5.7 Quickshell QML Development Tooling

Quickshell QML files are part of the maintained source tree. Systems used to
edit this project should provide both the stock Qt QML tools and a
Quickshell-aware language server:

- `qmllint` is the baseline syntax/static check for individual QML files.
- `qmlls` is the stock Qt QML language server and remains useful for generic
  Qt/QML projects.
- `qml-language-server` from `cushycush/qml-language-server` is the preferred
  editor language server for this repository because it understands Quickshell
  imports, singletons, types, snippets, and workspace QML components.

Arch provides the Qt 6 tools through `qt6-declarative`. The Qt 6 `qmllint` is
`/usr/lib/qt6/bin/qmllint`, which is outside the default `PATH`. On Arch,
`/usr/bin/qmllint` may belong to the Qt 5 `qt5-declarative` package; a Qt 5
`qmllint` cannot lint this shell and must be rejected rather than used.

`qmllint` must be run with explicit Qt and Quickshell QML import roots. Without
those roots it can report false import failures for modules such as
`Quickshell`, even when the shell runs correctly. The Arch root is:

| Arch QML import root |
| --- |
| `/usr/lib/qt6/qml` |

Language-server environments should expose the same root:

```sh
export QMLLS_BUILD_DIRS="/usr/lib/qt6/qml"
export QML_IMPORT_PATH="$PWD/config/quickshell"
```

The repository wrapper prefers `/usr/lib/qt6/bin/qmllint` (or the Qt 6 binary
directory reported by `qmake6 -query QT_INSTALL_BINS`) over a bare `qmllint`,
rejects a Qt 5 `qmllint`, discovers the explicit Qt import root, and creates
the temporary `qmldir` module map needed for local `qs.*` imports:

```sh
scripts/quickshell-qmllint --root config/quickshell
```

For x86_64, install the pinned `qml-language-server` v1.7.0 Linux AMD64
asset only after verifying the repository-pinned SHA-256 checksum:

```sh
set -eu
asset=qml-language-server-v1.7.0-linux-amd64.zip
curl -fL --output "$asset" \
  "https://github.com/cushycush/qml-language-server/releases/download/v1.7.0/$asset"
printf '%s  %s\n' \
  ad6e88b0fffbe5ee03fc9f6502c0103aa047c02c4942c547715283443bf4e946 \
  "$asset" | sha256sum --check --strict
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unzip -q "$asset" -d "$tmp"
printf '%s  %s\n' \
  928bd00ddb14f00a66f18473c0a492ae7109ee45c02db8bf3f55966229bb863a \
  "$tmp/qml-language-server-v1.7.0-linux-amd64" | sha256sum --check --strict
install -Dm0755 "$tmp/qml-language-server-v1.7.0-linux-amd64" \
  "${HOME}/.local/bin/qml-language-server"
```

Do not substitute a newer release or a different platform asset without
updating and independently verifying the checksum committed here.

Editor configuration must prefer `qml-language-server` for this repository's
QML files. Zed users should install the QML extension for language registration,
copy `.zed/settings.example.json` to `.zed/settings.json`, and configure its
`qml` language server binary to the absolute local path of
`qml-language-server`; Zed requires an absolute `lsp.qml.binary.path`. The
active `.zed/settings.json` file is intentionally local-only because that path
differs by machine. Other LSP-capable editors should run `qml-language-server`
for `*.qml` files and use the repository root, `shell.qml`, or `.git` as the
workspace root marker.

Plain `qmllint` is not considered a complete Quickshell validation pass because
it does not understand every Quickshell-specific module shape. Runtime
validation still requires loading the managed shell with `quickshell --path`
and exercising the relevant IPC targets.

### 5.8 Dependency Mapping

The maintained dependency map is `scripts/dwm-packages.sh`
(`dwm_packages arch <profile>`). Package names must not be scattered across
other scripts. Arch packages ship headers with the library, so there are no
`-devel` splits. The build capabilities map to:

| Capability | Arch packages |
| --- | --- |
| Compiler and make | `gcc`, `make`, `pkgconf` (or `base-devel`) |
| Xlib | `libx11` |
| Xft and fonts | `libxft`, `fontconfig`, `freetype2` |
| Xinerama | `libxinerama` |
| Xrender | `libxrender` |
| Imlib2 | `imlib2` |
| XCB | `libxcb`, `xcb-util` |

Runtime capabilities map to these Arch names:

| Capability | Arch packages |
| --- | --- |
| X11 server and session | `xorg-server`, `xorg-xinit`, `xorg-xrandr`, `xorg-xset`, `xorg-xsetroot`, `xorg-xinput`, `xorg-setxkbmap`, `xorg-xprop` |
| Session runtime | `dbus`, `curl`, `git`, `psmisc`, `unzip`, `util-linux`, `procps-ng`, `xclip`, `xdotool`, `xdg-utils` |
| Credential storage | `gnome-keyring` (includes the PAM module) |
| Media defaults | `celluloid`, `mpv`, `sxiv`, `python`, `desktop-file-utils` |
| Desktop shell and services | `quickshell`, `picom`, `feh`, `mate-polkit`, `xsettingsd`, `dex`, `libnotify`, `light-locker`, `jq`, `inotify-tools`, `bubblewrap`, `libseccomp`, `python` |
| Audio | `pipewire`, `wireplumber`, `pipewire-pulse`, `libpulse`, `pavucontrol`, `alsa-utils`, `playerctl` |
| Bluetooth, power, input | `bluez`, `bluez-utils`, `blueman`, `upower`, `power-profiles-daemon` (or an installed provider such as `tuned-ppd`), `brightnessctl`, `xf86-input-libinput` |
| Flatpak | `flatpak`, `xdg-desktop-portal-gtk` |
| System management | `pyalpm`, `pacman-contrib`, `python-gobject`, `accountsservice`, `cups`, `system-config-printer` (optional delegate: `lxqt-admin`) |
| Source updates | `xsettingsd`, `bubblewrap`, `libseccomp`, `networkmanager` |
| File manager (`full`) | `dolphin`, `ark`, `ffmpegthumbs`, `kdegraphics-thumbnailers`, `kio-admin`, `archlinux-xdg-menu`, `gvfs`, `xdg-user-dirs`, `rsync`, `networkmanager` |
| Theme | `dconf`, `adwaita-icon-theme`, `papirus-icon-theme`, `adw-gtk-theme`, `deepin-gtk-theme`, `qt6ct`, `qt5ct` |
| Fonts | `noto-fonts`, `noto-fonts-emoji`, `ttf-meslo-nerd` |
| QML tooling | `qt6-declarative` |
| Display manager (`full`) | `lightdm`, `lightdm-slick-greeter` |
| Terminals and screenshots | `alacritty`, `kitty`, `maim` |

`pipewire-pulse` conflicts with `pulseaudio`, and `tuned-ppd` provides
`power-profiles-daemon`. The installer must detect installed providers and
conflicting packages before it asks pacman to install a package, rather than
rely on `--noconfirm` to resolve them.

The `aur-optional` profile lists AUR-only packages: `xkbset` and the
`arc-gtk-theme`, `numix-gtk-theme`, `yaru-gtk-theme`, and `xfce-theme-bluebird`
GTK themes. No required profile contains an AUR package. Features that use
them, such as the AccessX input controls that use `xkbset`, must degrade
cleanly when they are absent.

PackageKit, `dnfdragora`, Path, Thunar and its plugins, and every gaming
package are not part of the map.

These are capability mappings, not immutable package lists. Availability must
be validated against the official repositories at the pinned Arch Linux
Archive snapshot used by the test container, and against current repositories
when a rolling-release validation record is written (Section 9.4).

Runtime dependencies are classified as:

- Core: an X11 server/session, D-Bus session support, one usable terminal
  emulator, `gnome-keyring` for credential storage, and the tools required by
  configured core keybindings. Alacritty is the preferred emulator, with the
  existing supported-terminal fallback chain retained when Alacritty is
  unavailable. On Arch the keyring PAM module
  (`/usr/lib/security/pam_gnome_keyring.so`) ships in `gnome-keyring`; there
  is no separate PAM package. Source synchronization must reconcile the keyring
  package even without Quickshell installed, while keeping desktop-only update
  dependencies gated on Quickshell. Dependency diagnostics must report a
  missing package or PAM module and offer the installer repair path. Automatic
  keyring unlock at password login also requires the login PAM stack to load
  `pam_gnome_keyring.so` and matching account/keyring passwords. Arch's
  packaged `/etc/pam.d/lightdm` already loads it. For `startx`, users may add
  the module to `/etc/pam.d/login` by hand as documented; the installer never
  edits PAM files. Autologin does not supply a password to this PAM path.
- Recommended desktop: Alacritty, Quickshell, Picom, Feh, Dex, a polkit agent,
  notification tools, audio controls, screenshot tooling, Nerd/emoji fonts,
  Flatpak with its GTK portal, the system-management runtime (`pyalpm`,
  `pacman-contrib`, `python-gobject`, `accountsservice`, `cups`, and
  `system-config-printer`), and Gear Lever from a user-scoped Flathub remote.
  Existing installations add that runtime by rerunning the installer with the
  `recommended` or `full` profile; source-sync does not infer an install
  profile from independently installed programs.
- Full: the recommended desktop plus the Dolphin file manager, wallpaper, and
  LightDM display-manager integration.
- Optional: the Herdr terminal workspace (opt-in with `--install-herdr`),
  network tray, theme utilities, display-manager greeter customization, the
  `aur-optional` packages, and hardware-specific helpers.

### 5.9 System Health Dashboard

The Control Center must open System Health as a separate full-screen
Quickshell window on the selected X11 monitor. The dashboard must remain
on-demand: opening or explicitly refreshing it starts a bounded snapshot, and
closing it stops active diagnostics. It must not add idle polling.

The snapshot must provide an overall state and categorized details for:

- Current-boot journal and kernel errors, with `journalctl` preferred and
  privileged `dmesg` used as a fallback.
- Failed system and user services, time synchronization, networking, audio,
  and the dwm-titus desktop session.
- Memory, pressure, load, swap, local filesystem capacity, inode use,
  read-only mounts, and available battery, thermal, and drive-health data.
- Required and optional dwm-titus commands, libraries, configuration, and the
  distribution package database.

The dashboard must begin user-readable checks immediately and request a
privileged read-only scan. It must first use non-interactive `sudo` when the
session already has cached or `NOPASSWD` authorization; otherwise it must use
the running polkit agent and trusted installed helper for graphical
authorization. Denied, cancelled, or unavailable authorization must produce a
clearly incomplete report rather than prevent the dashboard from opening.
Journal evidence must be bounded while retaining the total matching count.

Boot-journal and kernel-error rows with matching entries must provide Copy and
Export actions. Copy uses the X11 clipboard through `xclip`. Export writes the
displayed bounded evidence to a private, non-overwriting timestamped file in
the invoking user's home directory, using `boot$DATE.txt` or
`kernel-errors$DATE.txt` naming.

Repairs require an explicit confirmation. User repairs are limited to known
desktop and audio components plus launching the interactive dependency flow.
Failed user and system services are displayed as individual rows with Start,
Stop, Restart, Disable, and Enable actions. A service action is allowed only
while that exact `.service` unit is in the corresponding failed-unit set;
system actions require polkit authorization. Other privileged repairs are
limited to NetworkManager, Bluetooth, and the detected systemd
time-synchronization provider. Filesystem repair, cleanup, reboot, and
unattended package changes are not allowed.
Only a root-owned, non-writable system installation of the health helper may
itself be executed through `sudo` or `pkexec`; repository and XDG copies must
never be elevated. Without an installed helper, the unprivileged copy may use
non-interactive `sudo` to execute only validated root-owned system commands
needed for a bounded scan or confirmed repair.

### 5.10 Desktop Settings Platform

The managed Quickshell layer must grow into one discoverable Settings
application. Settings opens fullscreen on the selected monitor, matching
System Health. Appearance scrolling stays within vertical content bounds;
cursor changes update existing named X11 cursors and toolkit settings without
requiring a reboot. The application must use a hybrid integration model:

- Common desktop state and controls are presented through consistent
  Quickshell sections.
- Small project helpers may expose stable, machine-readable state and narrowly
  scoped user-session changes.
- Privileged or high-risk administration is performed only through allowlisted,
  installed helpers or delegated to trusted platform tools.
- Providers and delegated administration tools target Arch Linux. Missing
  capabilities must expose a clean unavailable or unsupported state rather
  than failing the entire application.

System package updates follow the native pacman contract in Section 5.11:

- Discovery is read-only and unprivileged through pyalpm.
  - It works in a private temporary database directory whose `local` entry
    links to the real local database, which is read, never written.
  - It downloads the sync databases there, seeded from the real ones and a
    per-user cache under `${XDG_CACHE_HOME:-$HOME/.cache}/dwm-titus/pacman-sync`,
    with a remote check at most every five minutes.
  - It honors each repository's `SigLevel` and `IgnorePkg`/`IgnoreGroup`, and
    never refreshes or writes `/var/lib/pacman/sync` or its lock.
- The dependency preview is a pyalpm `sysupgrade` transaction prepared in the
  same private handle and always released. It is a preview, not an atomic
  frozen plan; pacman's own prompts in the terminal decide replacements and
  conflicts.
- Restart guidance:
  - A system restart is required when `/usr/lib/modules/$(uname -r)` is
    missing.
  - Pending kernels, microcode, `systemd`, `glibc`, and `nvidia*` packages are
    flagged in the preview.
  - Undeterminable restart needs are reported as unknown, never as none.
- Change events are inotify watches on `/var/lib/pacman`, its `local`
  database, and its `sync` directory. A transaction is reported once the
  pacman lock is released. Remote availability is re-checked hourly. No pacman
  hook or system file is installed for this.
- Confirmed updates run as an interactive `sudo -- /usr/bin/pacman -Syu` in the
  Update Center terminal.
  - Before upgrading, the terminal fetches the Arch Linux news feed (HTTPS,
    size and time bounded, failure tolerant) and shows unacknowledged items.
    It requires an explicit Continue, and records the acknowledgement under
    `${XDG_STATE_HOME:-$HOME/.local/state}/dwm-titus/update-center/`.
  - A held pacman lock is reported with guidance and is never removed.
  - pacman's native output and prompts (replacements, conflicts, provider
    choices, `.pacnew` notices) are preserved, and `--noconfirm` or other
    automatic consent is never supplied.
  - Recovery reports the last known result and offers a fresh interactive
    upgrade; pacman does not roll back, and the desktop never claims it did.
- Settings > System offers "Open system update", which runs
  `dwm-update-center launch system` to open that same terminal flow. Settings
  never mutates packages in place, and there is no standalone database refresh.
- The Update Center's distribution provider is named `system` and takes its
  label from `os-release` `NAME`. Cached state and operation receipts recorded
  under the former `fedora` id are migrated or rescanned, never shown as
  current Arch data.
- An optional user-scope `aur` provider appears only when `paru` or `yay` is
  already installed.
  - Discovery compares foreign packages (`pacman -Qqm`) against the AUR RPC
    with `pyalpm.vercmp`, bounded in batch size, response size, and time.
  - VCS packages (`-git`, `-svn`, `-hg`, `-bzr`) are listed as version unknown
    and not counted.
  - Updates run `<helper> -Sua` as the invoking user. It never runs as root or
    through `sudo` or `pkexec`.
- PackageKit is not used. Its ALPM backend refreshes the real sync databases
  during discovery and simulation without authorization, which produces the
  partial-upgrade state described in Section 5.11. If PackageKit is installed,
  Settings reports that its clients can do this.

The Settings platform must distinguish:

1. Read-only state available without authorization.
2. User-session changes that affect only the invoking user.
3. Privileged system changes requiring explicit confirmation and narrow
   authorization.
4. Delegated operations opened in a trusted platform tool.
5. Unsupported capabilities with an actionable explanation.

QML must not construct arbitrary privileged commands. Elevated helpers must be
root-owned, non-writable by unprivileged users, validate every argument, expose
only documented operations, and remain safe when authorization is denied or
cancelled. Repository and XDG copies must never be elevated.

Settings providers must prefer event-driven updates and stop unnecessary
watches and processes when their section closes. A failure in one provider
must not prevent other sections from opening. Risky changes must provide
preview, confirmation, rollback, or recovery behavior appropriate to their
impact.

Phase 6 permits a narrow cancellation exception for the fixed system timezone,
NTP enablement, and system locale actions. Users can cancel their confirmation
without issuing a service call. The confirmation must clearly state that a
change cannot be canceled after dispatch to timedate1 or locale1; local request
cancellation does not undo a system change. These actions still require fixed
allowlisted arguments, explicit confirmation, platform authorization, audit
evidence, and bounded verification. An ambiguous post-dispatch timeout is
`interrupted`, never success or cancellation, and must trigger a fresh bounded
read without automatically retrying or rolling back the mutation. Any later
corrective change requires new confirmation. This exception does not change
the cancellation requirements of other privileged actions.

The planned Settings surface covers:

- Displays and monitor profiles.
- Display placement uses numbered monitor cards and a proportional preview,
  with Left of, Right of, Above, and Below actions relative to another enabled
  monitor. Placement accounts for resolution and rotation, aligns the top or
  left edges, and retains the timed preview/rollback and coordinate-based
  profile formats. Choosing a placement edits the pending layout only.
- Automatic display layouts expose separate Docked and Undocked profiles,
  their saved geometry and modes, detected hardware, current applied matches,
  and default fallback. Optional autorandr integration remains unprivileged;
  edits do not apply live, saves require confirmation and backups, and the
  Undocked layout enables only the built-in screen. Profiles must not pin
  session-specific CRTC assignments. Existing system-wide Xorg persistence
  remains a separate advanced operation.
- Keyboard, pointer, touchpad, and other supported input devices.
- NetworkManager connections, VPN entry points, and Bluetooth devices.
- PipeWire/WirePlumber-compatible audio devices and application streams.
- Power profiles, battery, idle, DPMS, suspend, lid, and lock behavior.
- Default applications, MIME handlers, and user-visible autostart entries.
- Themes, wallpaper, fonts, cursors, toolkit integration, notifications, and
  practical X11 accessibility controls.
- Updates, software-source entry points, regional and time settings, user and
  printer entry points, system information, storage overview, diagnostics, and
  recovery guidance.

Phase 5 accessibility discovery uses `settings-protocol 1` to publish separate
capability records for text scaling, high contrast, reduced motion,
notification policy, and keyboard or pointer access. Text scaling derives from
one complete versioned personalization response; high contrast and reduced
motion are user-session mutations owned by the versioned managed accessibility
helper; notification readiness requires the active session D-Bus owner's
process ID and command identity to match the managed Quickshell configuration;
and input readiness derives from bounded managed XInput discovery plus a
responsive `xkbset` query. Missing
or malformed providers degrade only their own record. Notification policy owns
Do Not Disturb and one bounded ordinary-popup duration in user configuration;
history remains active while suppressed, and critical urgency bypasses Do Not
Disturb with its fixed duration.

`input-protocol 1` also publishes one session-scoped `accessx` device group.
Its fixed boolean settings cover accessibility shortcuts, sticky keys, slow
keys, bounce keys, and mouse keys. Mutations use the existing timed input
preview, keep, revert, reset, and session-start replay workflow. Missing or
unresponsive XKB tooling degrades only that group and its accessibility
capability record.

Advanced partitioning, unrestricted service control, firewall policy editing,
and similarly high-risk administration remain delegated unless a later
specification defines a narrow safe interface.

#### Desktop source updates

Desktop source updates appear first in Settings > System, above system package
updates. Opening System performs a bounded check against the `main` branch of
this fork (`github.com/moheladwy/dwm-titus-archlinux`), never the upstream
`ChrisTitusTech/dwm-titus` repository, cached for five minutes; Check again bypasses the cache.
Checking does not install files. Installation receipts record the source
revision and managed file hashes so both newer source and installed-file drift
are detected, including installs without Git metadata. Unknown or unreadable
state must never be reported as current.

Confirmed desktop updates download a fixed revision, build as the desktop user,
stage the complete system installation through the Makefile, back up managed
files, install and verify them, and activate Quickshell through the managed
control path. Personal TOML, application settings, `.xinitrc`, and `config.h`
remain preserved. Mutable source commands run in a Bubblewrap/libseccomp build
sandbox without host authorization services or socket access; sandbox setup
failure stops the update instead of running an unconfined build. Git checkouts
must be clean, on `main`, and fast-forwardable;
linked worktrees require the documented source update procedure.

A root-owned installed helper accepts existing managed destinations and additions
within its desktop-owned namespaces: dwm-prefixed commands and helpers, Dwm
application themes and Qt palettes, Capitaine cursors, and dwm-titus licenses.
New files must not overwrite an unmanaged destination. Retired files are removed
only if they still match the previous receipt. Missing trusted directories are
created as root-owned 0755 directories; recovery may leave empty directories.
Administrator approval authorizes replacement contents at those destinations,
including the dwm binary, commands, and privileged helpers. Candidate hashes
verify the new payload; they do not have to match the previous installation.
The helper records the new hashes after installation and verification, retaining
the previous files and manifest for rollback. Each authorized apply is bound to
its prepared archive digest and confirmed revision; substitutions during
authorization are rejected.
It never executes a staged Makefile or repository helper as root. Changes to
installation roots still require the source installer. Changes to the release's
build/source-update package list are handled within the reserved transaction.
On Arch, the helper first checks missing packages with `pacman -T` and then
verifies that no package updates are pending: `pacman -Qu` lists nothing other
than entries held back by `IgnorePkg` (marked `[ignored]`). Otherwise it blocks
with "Update system packages first". This reflects the last database sync; the
helper never refreshes the sync databases itself, and pacman's own lock
reports a concurrent package manager. It then passes only validated
repository package names (lowercase, no paths, URLs, versions, or options) to
`/usr/bin/pacman -S --needed --noconfirm --`, and the resulting manifest must
match that prepared list. The root helper never installs AUR
packages. pacman owns package recovery; desktop rollback does not uninstall
packages. After explicit update or recovery confirmation, authorization
reuses an existing non-interactive sudo grant when available. Otherwise it uses
polkit for one visible approval. The updater must not create passwordless sudo
rules, store passwords, or change configured credential timeouts. A root-owned helper
retains its operation-bound authorization only for the transaction. Updates bind
the operation, generation, and selected revision; recovery remains limited to the original operation and its owner.
A private pipe carries at most eight allowlisted phase requests; EOF, completion,
or the one-hour session deadline ends the grant. Passwords are never saved, and
the updater creates no blanket authorization cache for other programs or updates.
Existing installations bootstrap this support through the source
installer; the GUI does not elevate a repository copy.

The update worker runs independently in a transient user service and retains
progress, result, and recovery records. The UI watches those records rather than
polling. Unknown-duration stages use an indeterminate progress bar; file
verification reports measured progress. Closing Settings does not cancel an
update. A normal, unprivileged GTK progress window runs in a separate user
service and survives managed Quickshell restarts. Its first appearance waits
for pending polkit authorization, so it cannot cover the password dialog. It yields focus to polkit,
shows elapsed time, stage, measured or indeterminate progress, a bounded log
viewer, and completion or recovery guidance. Hiding it leaves installation
running; a panel indicator reopens it. Both surfaces watch durable status
changes without polling. Completion produces a desktop notification.
GTK 3 is provided by the required desktop GTK portal; Python GObject is already
required by system management. Interrupted installation blocks another update until recovery is
resolved. If dwm changed, installation success remains distinct from activation:
show logout guidance and defer Quickshell activation to the new session.

### 5.10.1 Picom Appearance

Appearance provides a stable Compositor section backed by Picom configuration,
independent of process polling. Active and inactive window opacity are global
0-100 percent settings, saved on slider release (keyboard edits debounce for
250 ms). Theme application reapplies current values without storing them in
individual themes or overwriting them during theme rollback. Custom window
rules retain precedence over managed defaults.

The unprivileged `dwm-settings-picom` JSON protocol version 1 supplies `status`,
`watch`, `set-opacity ACTIVE INACTIVE REVISION`, `set-backend BACKEND REVISION`,
and `copy-config REVISION`. Mutations require the displayed source revision,
validate before publication, preserve unrelated libconfig source and include
files, back up changed files, and roll back failed activation. Missing Picom
remains optional. Missing configuration shows 100 percent defaults and is
created only on edit. Read-only system configurations require an explicit user
copy, including referenced configuration files.

`start`, `restart`, `reload`, `stop`, and `toggle` share user-and-display-scoped
session handling. Valid syntax outside the editor's supported subset remains
usable for session actions, with configuration parsing and backend policy
delegated to Picom while explicit session overrides remain respected.
Explicit `DWM_PICOM_CONFIG` and existing session `--config`
paths precede standard Picom XDG discovery. `PICOM_BACKEND` overrides an
explicit config backend; absent both, Automatic uses active-renderer diagnostics
(GLX for accelerated Intel/AMD, XRender for NVIDIA, software, or unknown), with
one XRender retry if automatic GLX startup fails. EGL is an explicit experimental
choice. PCI passthrough devices do not determine the active renderer. NVIDIA
synchronization defaults respect explicit configuration. Stopped Picom stays
stopped during opacity edits or theme application. File watches end when
Settings closes; no recurring compositor-state poll is required.

### 5.11 Arch Package Management Contract

Arch Linux supports only full system upgrades. Every package operation in the
installer, helpers, and Settings must preserve that rule:

- Never run `pacman -Sy` (a database refresh without an upgrade) on its own,
  and never trigger a component that does so, such as a PackageKit client.
- Never run `pacman -S <package>` while updates are pending, that is while
  `pacman -Qu` is non-empty, unless the same transaction is the full upgrade.
- Never delete the pacman database lock (`/var/lib/pacman/db.lck`). Report
  lock contention and let the user resolve it.
- Ship no `pacman.conf` changes. pacman's own defaults (a `[Y/n]` prompt and
  parallel downloads) are used as configured by the administrator.

The installer runs one visible `sudo pacman -Syu` before any package
installation. That step:

- appears in the `--dry-run` plan;
- uses pacman's own confirmation prompt;
- adds `--noconfirm` only when the user passes `--non-interactive`;
- aborts the installation if it fails or is declined.

Package installation after that step uses
`sudo pacman -S --needed -- <names>`, again adding `--noconfirm` only for
`--non-interactive` runs.

The AUR policy is:

- AUR use is opt-in through `--enable-aur`. It is never required, and no
  required install profile contains an AUR package.
- Only an AUR helper that is already installed (`paru` or `yay`) is used. The
  project never bootstraps, builds, or installs an AUR helper.
- The AUR helper runs as the invoking user, never under `sudo`, `pkexec`, or
  root. It installs with `"$helper" -S --needed --`.
- Official repository packages never go through the AUR helper; they are
  always installed with pacman.
- Root-owned and pkexec helpers never call an AUR helper or `makepkg`.
- AUR-only packages are listed only in the `aur-optional` profile (Section
  5.8). Without an AUR helper or without opt-in, they are reported as skipped.

## 6. Filesystem and Installation Contract

Default system installation locations:

```text
${PREFIX}/bin/dwm
${PREFIX}/share/man/man1/dwm.1
/usr/share/xsessions/dwm.desktop
```

Default user locations:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/
${XDG_DATA_HOME:-$HOME/.local/share}/dwm-titus/
```

System paths must be overridable for packaging and staged installs. User data
must not be written during a package build using `DESTDIR`.

User-scoped installation runs as the target user. Any default XDG parent
directory created by the installer must be owned by that user
and their primary group. Existing XDG parent permissions must be preserved,
and installation must not recursively change ownership outside project-managed
directories.

Uninstall must remove only files owned by this project. It must preserve user
configuration and unrelated application configuration by default.

## 7. User Experience Requirements

- The default session must remain usable when optional visual components fail.
- Common desktop settings must be discoverable from one Settings application;
  unsupported sections must not make the rest of Settings unusable.
- System changes must show pending state, success, failure, and recovery
  guidance rather than relying on silent background commands.
- Error messages must identify the missing command, library, package
  capability, or file and provide the next action.
- The default terminal binding must launch Alacritty directly.
- A plain `dwm-terminal` launch must open the selected emulator directly unless
  the user explicitly enables the optional Herdr layer with `DWM_HERDR=1`.
  Explicit terminal arguments such as `dwm-terminal -e command` must bypass
  Herdr so delegated commands retain their existing execution contract.
- The `dwm-terminal` helper must prefer Alacritty, select another installed
  supported emulator when needed, and provide a clear configuration path.
- Font aliases must accommodate common Meslo Nerd Font naming differences.
- Multi-monitor setup must expose EWMH tags correctly to Quickshell and EWMH
  inspection tools.
- Each Quickshell panel must show only the tags owned by its monitor, using the
  `_DWM_MONITOR_DESKTOPS` root property to match screen geometry with dwm's
  logical monitor order and current tag.
- Defaults should work at 1080p and remain usable at lower and higher
  resolutions.
- Installation output must be readable in both interactive terminals and logs.

## 8. Security and Safety Requirements

- Do not execute remote scripts through a shell as part of the required
  installation path.
- Do not download or execute unverified binaries.
- Third-party executable installers must run as the target user in an isolated
  staging directory. Both the reviewed installer and resulting binary must
  match repository-pinned checksums before the binary is installed.
- Do not run user configuration or desktop helpers as root.
- Quote paths and arguments that may contain whitespace.
- Prevent command injection through distribution metadata, configuration
  values, filenames, and environment variables.
- Avoid broad recursive ownership or permission changes outside project-owned
  directories.
- Preserve existing user files or create explicit backups before replacement.
- Keep the Quickshell Settings frontend unprivileged.
- Require explicit confirmation for privileged or destructive settings.
- Use polkit or an equivalently narrow authorization mechanism rather than
  broad passwordless sudo access for desktop settings.
- Continue showing readable state when authorization is denied, cancelled, or
  unavailable.

## 9. Validation and Acceptance Criteria

A release is Arch-ready only when all of the following pass and a
rolling-release validation record (Section 9.4) has been written.

Automated validation must run through `scripts/run-tests`, which creates a
unique workspace under `${DWM_TEST_TMP_ROOT:-$HOME/tmp}` and removes that exact
workspace on success, failure, or interruption. Tests that install packages,
run the real installer, or change system state must run in an isolated
container or virtual machine, never on a developer's host system.

### 9.1 Static Validation

- Clean C build with warnings enabled.
- Shell syntax checks for every changed shell script.
- ShellCheck and shfmt checks, with documented justified exceptions.
- Configured Qt 6 QML lint for changed Quickshell files (Section 5.7).
- No generated build artifacts unintentionally included in the change.

### 9.2 Arch Validation

The reproducible Arch gate is the test container defined by
`tests/containers/arch/Containerfile`. Its base image is pinned by digest, and
its mirrorlist is pinned to one dated Arch Linux Archive snapshot
(`https://archive.archlinux.org/repos/YYYY/MM/DD/`), which is the official
archive and not project-hosted infrastructure. The snapshot date and image
digest are bumped together. `scripts/run-tests-podman` builds and runs it as
`localhost/dwm-titus-tests:arch`. Docker may be used locally to run the same
container when Podman is unavailable.

In that container, or on a disposable Arch system:

- Distribution detection accepts `ID=arch` and rejects every other identity
  before mutation, including `ID=endeavouros`, `ID=cachyos`, and `ID=manjaro`
  with `ID_LIKE=arch`, and an `os-release` file without `VERSION_ID` is
  accepted for `ID=arch`.
- Every official package name in the dependency map resolves with pacman.
  `aur-optional` names are checked against the AUR when the network is
  available, and that check is optional.
- A clean checkout builds successfully.
- `make install DESTDIR=<staging-dir>` installs the expected system files
  without writing to the test user's home.
- `./install.sh --dry-run` lists the up-front `pacman -Syu`, and a real
  `--profile core` run completes in a clean Arch container.
- The real installer preserves pre-existing user configuration.
- Dependency checks report both missing and satisfied capabilities correctly.
- A `--profile recommended` installation with LightDM completes in a virtual
  machine with a fresh Arch installation.

### 9.3 Runtime Validation

In a real or nested X11 session:

- dwm starts and can launch a terminal.
- The default terminal binding opens Alacritty directly even when Herdr is
  installed. With `DWM_HERDR=1`, a plain `dwm-terminal` command opens Herdr
  inside Alacritty; explicit `dwm-terminal -e` commands still bypass Herdr.
- Tiling, floating, tags, focus, and close-window actions work.
- Runtime TOML configuration loads and reloads.
- A display-manager session and `startx` path both launch.
- Missing optional desktop processes do not terminate the session.
- EWMH integration works with Quickshell or an equivalent inspection tool.
- Each active monitor has one managed Quickshell panel.
- With the launcher closed, the managed Quickshell process remains near idle
  in a short CPU sample, and no second Quickshell-based shell provider is
  running in the same session.
- A source-checkout update of a live installation leaves the installed binary,
  commands, managed Quickshell tree, and user data copy at the same revision.
  After any required dwm session restart, the new executable is active and XDG
  autostart tray clients register with the managed Quickshell tray host.
- Multi-monitor behavior is tested where suitable hardware or nested displays
  are available.
- The default screenshot-to-clipboard binding invokes the managed helper, and
  its completed capture is advertised as `image/png` by an `xclip` clipboard
  owner. Active-monitor and saved-region captures produce non-empty JPEG files
  through `maim`.
- Recommended and full installs expose Gear Lever in the application launcher,
  and it opens a visible window in the supported X11 session.
- On a fresh account of a full install, `Super+E` opens Dolphin, its "Open
  With" menu is populated outside Plasma, and it follows the active Qt palette.

### 9.4 Rolling-Release Validation Record

Arch has no release number, so every validation record must state:

- the test date and, for container runs, the Arch Linux Archive snapshot date
  and base image digest;
- the versions of pacman, Quickshell, Qt, and the kernel that were tested;
- the architecture, whether the run used a container, a virtual machine, or
  hardware, and the display path (nested Xvfb/Xephyr, LightDM, or `startx`);
- every path that was not tested.

A record against the pinned snapshot does not prove behavior against current
repositories. No automated job checks current repositories yet: drift is found
by a manual run against live mirrors, recorded as such, and tracked as a
follow-up in `TASKS.md`.

## 10. Current Gap

The port from Fedora to Arch Linux following the decisions in
`docs/ARCH-PORT-DECISIONS.md` is complete. Fedora feature history
(Phases 1-8 and the 0.7.2 work) is archived in
`docs/COMPLETED-ROADMAP-20260911.md`, the `docs/P*-*.md` evidence files, and
`CHANGELOG.md`; it is not a claim about Arch behavior.

Plan Phases 0-4 deliver this contract, fork endpoints, the Arch platform
identity and package map, the pinned Arch test container and Qt 6 QML lint,
and the existing-system installer and runtime integrations, including Dolphin
and the LightDM defaults. Phases 5-8 deliver the native pacman update stack
(pyalpm discovery, terminal-only upgrades with the news gate, the `system`
and optional `aur` Update Center providers) and the remaining Settings platform
work (Arch identity, regional actions, delegates, and security rows). Phases
9-10 deliver the Arch documentation site and reference docs, and remove the
Fedora-only code: Kickstarts, image tooling, the first-boot initial update,
the DNF defaults helper, the Fedora package profiles and test container, and
the `protonrestart` gaming helper.

The following have no Arch validation record yet and are untested until one
says otherwise (Section 9.4):

- physical hardware in general, including NVIDIA drivers and composition,
  Secure Boot systems, suspend and resume, laptop power and brightness,
  Wi-Fi and Bluetooth radios, audio devices, and multi-monitor hotplug;
- a real `--profile recommended` installation with LightDM in a virtual
  machine with a fresh Arch installation, and display managers other than
  LightDM;
- the `startx` path with the manual `pam_gnome_keyring.so` login PAM change;
- in a real or nested X11 login session: Dolphin's "Open With" menu outside
  Plasma (`XDG_MENU_PREFIX=arch-` and `kbuildsycoca6`), Dolphin following the
  `qt6ct` palette, and `quickshell --no-duplicate` staying near idle with the
  launcher closed (the automated suites measure shell idle CPU only under
  Xvfb);
- the `--enable-aur` install path and the optional `aur` Update Center
  provider against the live AUR with a real `paru` or `yay`;
- validation against current repositories rather than the pinned archive
  snapshot.

Intermittent failures in the automated suites must be investigated rather than
reported as passing coverage. The races found during the port (the Picom
renderer probe, deferred Settings panes, and several QML test checks) are
fixed; a timeout that occurs only when several heavy suites share one loaded
host is recorded as such.

Arch Linux x86_64 and X11 are the supported scope.

## 11. Definition of Done

A roadmap feature is complete when:

- Its behavior meets the active roadmap phase and task acceptance criteria.
- Arch behavior is implemented and runtime validated, or the change is
  explicitly scoped as preparatory work.
- Installation attempts without `ID=arch` fail clearly before making changes.
- No code path runs `pacman -Sy` without a full upgrade, installs packages
  while updates are pending, or runs an AUR helper as root.
- Relevant automated and manual validation is recorded, including a
  rolling-release validation record (Section 9.4) for runtime claims.
- On a development machine running dwm-titus, the checkout has been
  synchronized to the local live installation with
  `scripts/dev-sync-install.sh`, including the post-relogin check when one is
  required.
- User-facing installation and troubleshooting documentation is updated.
- No existing user configuration is overwritten.
- Known limitations and untested platforms are stated precisely.
