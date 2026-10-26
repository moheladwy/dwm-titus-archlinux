---
title: Desktop Dependencies
description: The Arch Linux packages and services behind each part of the dwm-titus desktop, including install profiles, optional AUR extras, and build tools.
navLabel: Dependencies
eyebrow: Start here
---

# Dependencies

dwm-titus combines **dwm, Quickshell, and Xorg** with services for audio,
networking, power, authentication, and application integration. Arch Linux
x86_64 is the only supported distribution.

This guide describes the major direct dependencies selected by the installer,
not an inventory of your machine or every transitive library. pacman and
Flatpak resolve additional dependencies, including Quickshell's Qt/QML runtime.
The [shared package map](https://github.com/moheladwy/dwm-titus-archlinux/blob/main/scripts/dwm-packages.sh)
(`dwm_packages arch <profile>`) is authoritative for package names; the
[installer](https://github.com/moheladwy/dwm-titus-archlinux/blob/main/install.sh)
is the source of truth for conditional installation. Arch packages ship
headers with the library, so there are no separate `-devel` packages.

Every required package comes from the official Arch repositories (`core` and
`extra`). Items marked **AUR-only** are optional, never required, and
installed only with `--enable-aur`; see [Optional AUR Packages](#optional-aur-packages).

## Installation Profiles

| Choice | What it installs |
| --- | --- |
| `core` | Build tools and libraries, X11, required runtime utilities, GNOME Keyring, media applications, and one supported terminal. It does not install the complete Quickshell desktop. |
| `recommended` | Core plus Quickshell, desktop services, system-management prerequisites, themes, fonts, and Gear Lever. Screenshot and some theme packages are attempted with failure-tolerant handling. |
| `full` | Recommended plus the Dolphin file manager, network and file-access integration, Qt theme and administration tools, and wallpapers. Installs LightDM if no display manager is detected. |

In the tables below, **Core** means every profile, **Desktop** means
recommended and full, and **Full** means an optional extra attempted by full.
These describe installer selection, not whether dwm itself requires a
component to keep running. For example, Picom is installed by the desktop
profile, but dwm can run without it.

Before any package is installed, the installer runs one visible
`sudo pacman -Syu`. Preview the actual installation plan, including that
upgrade, before making changes:

```sh
./install.sh --dry-run --non-interactive --profile recommended
```

## Window Manager and Desktop Shell

| Piece | Dependencies | Role and selection |
| --- | --- | --- |
| System foundation | Arch Linux, pacman, systemd | Host package management, system services, and user sessions. |
| Display server | `xorg-server`, `xorg-xinit` | Core. X11 graphics and `startx` support. This is not a Wayland session. |
| Window manager | Repository-built `dwm` | Tiling, floating windows, tags, focus, window rules, and monitor management. |
| Desktop shell | `quickshell` and managed repository QML | Desktop. Panels, launcher, tray, notifications, Control Center, and Settings. Requires Quickshell 0.3.0 or newer from Arch `extra`; the installer stops if the installed build is incompatible. |
| Compositor | `picom` | Desktop. Compositing, opacity, shadows, and visual effects. |
| Wallpaper | `feh` | Desktop. Applies wallpaper through the managed helpers. Full additionally attempts to download the wallpaper collection. |
| Session communication | `dbus`, systemd user services | Core D-Bus session support; graphical-session integration makes the display environment available to user services. |
| Application autostart | `dex` | Desktop. Fallback for XDG autostart when the systemd graphical-session path is unavailable. |
| Login screen | `lightdm`, `lightdm-slick-greeter` | Full when no display manager is detected. An existing display manager is retained; detected LightDM receives the project's greeter configuration with Arch's `/etc/lightdm/Xsession` session wrapper. |
| Terminal | `alacritty`, with supported fallbacks | Core. Alacritty is preferred. If unavailable, the installer checks existing Kitty, st, Warp, or xterm before attempting `kitty`. |
| Screen locking | `light-locker` | Desktop. Locking follows the saved power and locking policy. |

The managed Quickshell configuration lives under
`${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/`. The window manager stays separate
from the shell and system-service backends. Settings provides the interface;
helpers and service APIs perform the underlying operations.

## Hardware and System Services

| Piece | Dependencies | Role and selection |
| --- | --- | --- |
| Audio engine | `pipewire`, `wireplumber`, `pipewire-pulse` | Desktop. Audio processing, device/session policy, and PulseAudio compatibility. An installed `pulseaudio` is retained; the conflicting `pipewire-pulse` is skipped. |
| Audio tools | `alsa-utils`, `libpulse`, `pavucontrol` | Desktop. Mixer commands, audio controls, and a standalone configuration interface. |
| Network connections | `networkmanager` | Full and source-update reconciliation. Backend for networking controls. Arch packages Wi-Fi support in `networkmanager` itself. It may already be present on an existing system. |
| Bluetooth | `bluez`, `bluez-utils`, `blueman` | Desktop. Bluetooth services, command-line tools, and device management. |
| Battery and power profiles | `upower`, `power-profiles-daemon` | Desktop. Battery state and performance/power profiles. An installed provider such as `tuned-ppd` is retained rather than replaced. |
| Brightness | `brightnessctl` | Desktop. Backlight control where supported by the hardware. |
| Display controls | `xorg-xrandr`, `xorg-xset`, `xorg-xsetroot` | Core. Monitor layout/modes, screen power settings, and root-window utilities. |
| Input controls | `xorg-xinput`, `xorg-setxkbmap`; `xkbset` (**AUR-only**) | Core for `xinput` and `setxkbmap`: input settings and keyboard layouts. `xkbset` backs the session-wide AccessX controls, which report as unavailable without it. |
| Input driver | `xf86-input-libinput` | Desktop. Xorg keyboard and pointer driver integration. |
| Authorization dialogs | polkit, `mate-polkit` | Desktop selects the authentication agent. Privileged operations use narrow installed helpers and authorization policies; QML stays unprivileged. |
| Credential storage | `gnome-keyring` | Core. Secret storage and password-login unlock support. On Arch this package also ships `pam_gnome_keyring.so`. Arch's LightDM PAM configuration loads it; `startx` users add it to `/etc/pam.d/login` by hand, and the installer never edits PAM files. See [keyring troubleshooting](/troubleshooting.html#login-keyring-asks-for-a-password-every-login). Source and desktop updates repair a missing keyring package. |

## Applications and Desktop Integration

| Piece | Dependencies | Role and selection |
| --- | --- | --- |
| File manager | `dolphin` | Full. Fresh accounts open folders in Dolphin (`org.kde.dolphin.desktop`); existing MIME preferences are preserved. Its terminal action uses the selected terminal through `~/.config/kdeglobals`, seeded only when that file is absent. |
| Archives | `ark` | Full. Archive creation/extraction and file-manager integration. |
| Thumbnails | `ffmpegthumbs`, `kdegraphics-thumbnailers` | Full. Video, image, and document thumbnails in Dolphin. |
| Administrator file access | `kio-admin` | Full. Opens system locations with administrator rights from Dolphin. |
| Application menu | `archlinux-xdg-menu` | Full. Supplies the `applications.menu` that Dolphin's "Open With" needs outside Plasma. |
| File access | `gvfs` | Full. File-access integration for GTK applications. |
| Standard user folders | `xdg-user-dirs` | Full. Initializes standard directories such as Pictures and Downloads. |
| Default apps and desktop entries | `xdg-utils`, `desktop-file-utils` | Core. URL/file opening, associations, and desktop-entry utilities. |
| Media playback | `celluloid`, `mpv` | Core. Graphical video player and playback engine. |
| Image viewing | `sxiv` | Core. Image viewer; Feh separately handles wallpapers. |
| Media controls | `playerctl` | Desktop. Controls compatible music and video players. |
| Screenshots | `maim`, managed `dwm-screenshot` helper | Attempted for Desktop. Missing `maim` disables screenshot hotkeys without failing installation. |
| Clipboard | `xclip` | Core. X11 clipboard ownership, including completed screenshot captures. |
| Window inspection and automation | `xdotool`, `xorg-xprop` | Core. Window interaction and X11 state inspection used by desktop helpers. |
| Notifications | Quickshell, `libnotify` | Desktop. Quickshell displays notifications; libnotify supplies client tools. |
| Sandboxed applications | `flatpak`, `xdg-desktop-portal-gtk` | Desktop. Flatpak applications and portal integration such as file dialogs. The portal preference is `~/.config/xdg-desktop-portal/dwm-portals.conf`. |
| AppImage management | Gear Lever (`it.mijorus.gearlever`) | Desktop. Installed through user-scoped Flathub when needed; integrates AppImages with the launcher. |
| System management | `pyalpm`, `pacman-contrib`, `python-gobject` | Desktop. Prerequisites for the pacman-based package provider. Settings > System reads available updates through unprivileged pyalpm without touching the system databases. **Open system update** opens the Update Center terminal, which checks the Arch Linux news feed and then runs an interactive `sudo pacman -Syu`. |
| User accounts | `accountsservice`; optional `lxqt-admin` | Desktop account-service prerequisites; Full additionally attempts the delegated administration tool. |
| Printing | `cups`, `system-config-printer` | Desktop. Print service and printer-configuration tools. |

Package presence does not imply that every service is running or every hardware
feature is available. Settings reports unsupported capabilities and delegates
selected advanced operations to the relevant tools.

## Appearance and Helper Infrastructure

| Piece | Dependencies | Role and selection |
| --- | --- | --- |
| GTK settings | `xsettingsd`, `dconf` | Desktop. Session appearance settings and persistent toolkit preferences. |
| Qt appearance | `qt6ct`, `qt5ct` | Recommended attempts the first available candidate; Full attempts both. Qt toolkit theme integration. |
| Icons | `adwaita-icon-theme`, `papirus-icon-theme` | Desktop. Application and desktop icons. |
| GTK themes | `adw-gtk-theme`, `deepin-gtk-theme` | Attempted for Desktop; unavailable themes do not fail installation. Nordic is installed separately from its Git repository for the default Nord theme. |
| Additional GTK themes | `arc-gtk-theme`, `numix-gtk-theme`, `yaru-gtk-theme`, `xfce-theme-bluebird` (**AUR-only**) | Installed only with `--enable-aur`. |
| Fonts | `noto-fonts`, `noto-fonts-emoji`, `ttf-meslo-nerd` | Desktop. Text, emoji, and Meslo Nerd Font icon glyphs. |
| Helper runtime | `python` | Core. Managed desktop helpers and supporting scripts. |
| Structured data and events | `jq`, `inotify-tools` | Desktop. JSON processing and filesystem watches. `dbus` (Core) supplies the service-communication tools. |
| Update isolation | `bubblewrap`, `libseccomp` | Desktop. Sandboxing and syscall restrictions for the desktop update workflow. |
| Download and source tools | `curl`, `git`, `unzip` | Core. Downloads, source updates, and archive extraction. |
| Process and session tools | `procps-ng`, `psmisc`, `util-linux` | Core. Process inspection/control and session utilities. |
| File synchronization | `rsync` | Full. |

The source-update reconciliation group is deliberately smaller than a complete
installation profile: `xsettingsd`, `bubblewrap`, `libseccomp`,
`networkmanager`, and `gnome-keyring`. Without Quickshell installed, only
`gnome-keyring` is reconciled. Desktop updates in Settings check these with
`pacman -T` and install missing packages with `pacman -S --needed` only when
no system updates are pending; otherwise they report "Update system packages
first". Rerun the installer with `recommended` or `full` to add that profile's
complete system-management prerequisites to an older installation.

## Optional AUR Packages

The `aur-optional` profile lists the packages that exist only in the AUR:

| Package | Purpose |
| --- | --- |
| `xkbset` | Session-wide AccessX input controls. |
| `arc-gtk-theme`, `numix-gtk-theme`, `yaru-gtk-theme`, `xfce-theme-bluebird` | Additional GTK themes. |

They are installed only with `--enable-aur`, or after an interactive `[y/N]`
question that defaults to No, and only through an AUR helper you already have
(`paru` or `yay`), run as your user. The installer never bootstraps an AUR
helper, never sends official packages through it, and no required profile
depends on the AUR. Root-owned helpers and desktop updates never use the AUR.

PackageKit, `dnfdragora`, Path, Thunar and its plugins, and gaming packages
are not part of the Arch package map.

## Build and Validation Dependencies

The source installer compiles dwm, so even `core` selects these build packages:

| Dependencies | Purpose |
| --- | --- |
| `gcc`, `make`, `pkgconf` | C compiler, build system, and library discovery. `base-devel` also provides them. |
| `libx11`, `libxcb`, `xcb-util` | X11 and XCB interfaces. |
| `libxinerama` | Multi-monitor interfaces. |
| `libxrender`, `libxft` | Rendering and text drawing. |
| `freetype2`, `fontconfig` | Font rendering and discovery. |
| `imlib2` | Image handling. |

Development profiles have additional tools that are separate from the
everyday desktop:

- **QML development/validation:** `qt6-declarative`, plus Quickshell and
  `xsettingsd` for validation. Use the Qt 6 linter
  (`/usr/lib/qt6/bin/qmllint`), not the Qt 5 `/usr/bin/qmllint`. QML linting
  needs explicit Qt and Quickshell import roots; see the repository
  specification.
- **Headless smoke testing:** `xorg-server-xvfb`, `dbus`, `gawk`, `noto-fonts`,
  and the build/runtime tools in the `ci-smoke` map. The pinned Arch test
  container (`tests/containers/arch/Containerfile`) resolves these from a dated
  Arch Linux Archive snapshot.

For installation steps, return to [Installation](/install.html). For the
underlying contracts, see the
[project specification](https://github.com/moheladwy/dwm-titus-archlinux/blob/main/SPEC.md).
