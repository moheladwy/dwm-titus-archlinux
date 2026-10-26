<div align="center">
  <img alt="dwm-titus logo" src="./config/quickshell/assets/ctt_logo.png" />
  <p><strong>A fast, focused Arch Linux X11 desktop built for keyboard-driven work.</strong></p>
  <p>
    <a href="./docs/src/content/getting-started.md">Documentation</a> |
    <a href="https://github.com/moheladwy/dwm-titus-archlinux/releases/latest">Latest release</a> |
    <a href="./CHANGELOG.md">Changelog</a> |
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
</div>

![The dwm-titus desktop with its Quickshell panel](./dwm-titus-qs-4x.webp)

dwm-titus is a complete, lightweight X11 desktop with sensible defaults,
guided installation, and powerful customization. It is designed for people who
want a responsive keyboard-first workflow without having to assemble every
part themselves.

**This fork supports Arch Linux only.** Arch Linux (x86_64, `ID=arch`) is the
sole supported platform for installation, runtime behavior, package
resolution, and testing. Arch derivatives such as EndeavourOS, CachyOS,
Manjaro, and Arch Linux ARM are rejected by the installer, as is every other
distribution, including Fedora.

This is a fork of [ChrisTitusTech/dwm-titus](https://github.com/ChrisTitusTech/dwm-titus), ported from Fedora to Arch Linux.

## What You Get

| Experience | What it includes |
| --- | --- |
| **A focused desktop** | Automatic window tiling, nine workspaces, fast keyboard navigation, multi-monitor support, and flexible fullscreen modes. |
| **Everyday essentials** | A polished panel, application launcher, system tray, Control Center, Settings, notifications, screenshots, audio, brightness, and power controls. |
| **Easy discovery** | An interactive keybind viewer, guided display setup, built-in diagnostics, workstation self-heal, and clear unsupported-feature reporting. |
| **Personal configuration** | Live-reloading hotkeys, themes, and window rules, with local configuration preserved across upgrades. |
| **One installation path** | Install Arch Linux, then run one installer that adds the desktop on top. |

> dwm-titus is an X11 desktop. A Wayland-native session is not currently part
> of the project scope.

## Install

dwm-titus does not ship an installer image. Installation has two steps:

1. Install Arch Linux with the official [Arch ISO](https://archlinux.org/download/),
   either by hand following the [installation guide](https://wiki.archlinux.org/title/Installation_guide)
   or with `archinstall`. A minimal install with a user account, `sudo`, and
   network access is enough.
2. Log in as your normal user (not root) and run the installer from a checkout
   of this repository:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/moheladwy/dwm-titus-archlinux.git
cd dwm-titus-archlinux

./install.sh --dry-run --non-interactive --profile recommended
./install.sh --profile recommended
```

The dry run shows the dependency and installation plan before anything changes.
The installer accepts only Arch Linux's `/etc/os-release` identity
(`ID=arch`) and rejects every other operating-system identity before making
changes. It preserves existing personal configuration and installs the managed
desktop components.

Before it installs any package, the installer runs one visible
`sudo pacman -Syu`, because Arch does not support partial upgrades. This step
is listed in the dry run and uses pacman's own confirmation prompt. Only
`--non-interactive` adds `--noconfirm`. If the upgrade fails or you decline it,
the installation stops.

| Profile | Includes |
| --- | --- |
| `core` | The X11 session, required dependencies, and one terminal emulator. |
| `recommended` | The complete everyday desktop, including Alacritty, Quickshell, Gear Lever for AppImages, theming, screenshots, audio, brightness, and the pyalpm, AccountsService, CUPS, and printer-tool prerequisites for system management. |
| `full` | The recommended desktop plus the Dolphin file manager, wallpaper, and LightDM display-manager integration. |

All required packages come from the official Arch repositories. A few optional
extras exist only in the AUR: `xkbset` (used by the AccessX input controls) and
the Arc, Numix, Yaru, and Bluebird GTK themes. To install them, pass
`--enable-aur`. The installer then uses an AUR helper you already have
(`paru` or `yay`), running it as your user. It never installs an AUR helper for
you and never sends official packages through it. Without `--enable-aur`, the
AUR extras are skipped and everything else still works.

`maim` is an optional dependency used only by the screenshot hotkeys. If it is
unavailable, installation continues and reports that the screenshot hotkeys
remain disabled; invoking one makes `dwm-screenshot` exit with
`dwm-screenshot: maim is not installed`. `xclip` and `xdotool` remain required
runtime dependencies for the X11 desktop and its other managed helpers.
Every profile includes `gnome-keyring`, which on Arch also ships the
`pam_gnome_keyring.so` module, for credential storage and password-login
unlock support. Arch's LightDM PAM configuration already loads that module.
If you start the session with `startx`, automatic unlock requires adding the
module to `/etc/pam.d/login` yourself; the installer never edits PAM files.
Unlock also requires matching account and keyring passwords.

Package updates in Settings and the Update Center are still being ported from
Fedora. Until that work lands, update your system with `sudo pacman -Syu` in a
terminal.

## Dependencies

See [Desktop Dependencies](docs/src/content/dependencies.md) for the packages
behind each desktop component, installation-profile differences, and build
dependencies. The canonical package map is `scripts/dwm-packages.sh`. Some
pages under `docs/src/content/` still describe Fedora and are being updated.

## First Login

**Super** is the Windows key on most keyboards.

| Action | Keybind |
| --- | --- |
| Open the application launcher | <kbd>Super</kbd> + <kbd>R</kbd> |
| Open Alacritty terminal | <kbd>Super</kbd> + <kbd>X</kbd> |
| Open Control Center | <kbd>Super</kbd> + <kbd>F1</kbd> |
| Show the interactive keybind viewer | <kbd>Super</kbd> + <kbd>/</kbd> |
| Close the focused window | <kbd>Super</kbd> + <kbd>Q</kbd> |
| Switch workspace | <kbd>Super</kbd> + <kbd>1-9</kbd> |
| Open the power menu | <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> |

With a display manager, select the `dwm` session when logging in. From a TTY,
start the session with:

```bash
startx
```

## Customize Your Desktop

Most personal settings live under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/
```

Hotkeys, themes, and window rules reload when their TOML files are saved.
Advanced compile-time preferences live in the user-owned `config.h`, which the
installer and future upgrades preserve.

The installer also provides `dwm-settings-display` and its root-owned
`libexec/dwm-titus/dwm-settings-display-root` persistence helper. Live display
discovery and previews require `xrandr`; hotplug watching requires `udevadm`;
only persistent Xorg install and rollback require `pkexec`. Named profiles live
under the `display-profiles/` directory in the XDG path above.
Run `dwm-display-setup detect`, then `dwm-display-setup`, for a guided wizard
that detects outputs and configures modes, positions, rotation, and the primary
display with a reversible preview. Persistent generation selects compatible
TearFree or NVIDIA Full Composition Pipeline behavior automatically; pass
`--force-full-composition-pipeline off` to disable the NVIDIA default.
The adjacent `dwm-settings-input` provider uses `xinput`, `setxkbmap` for
keyboard settings, `xkbset` for session-wide AccessX controls, and `udevadm`
for stable device identity and hotplug events. Kept values are stored in
`input-settings.conf` in the same XDG directory; `DWM_INPUT_SETTINGS_FILE` can
select another file.

The compositor settings in **Settings -> Appearance -> Compositor** and the CLI
helper `dwm-settings-picom` manage window opacity and rendering backends. Sliders
adjust active and inactive window opacity with live persistence in the active configuration
(resolved from `DWM_PICOM_CONFIG`, a running Picom `--config` argument, or standard
fallback paths `~/.config/picom.conf` and `~/.config/picom/picom.conf`). The automatic
backend policy selects GLX for accelerated Intel/AMD graphics and falls back to XRender
on NVIDIA or software rendering, with manual GLX, XRender, and EGL overrides available.
Edits preserve custom comments and includes with up to ten automatic recovery backups.
All 15 shipped presets include offline `Dwm-<preset>` application themes,
including `Dwm-dracula`, for native GTK 2/3/4 applications.
The system install places their files under `${DATADIR}/themes` (normally
`/usr/share/themes` with the supported installer); source updates install and
verify them too.
Qt applications using qt5ct or qt6ct receive the matching installed palette,
also listed in those tools from `${DATADIR}/qt5ct/colors` and
`${DATADIR}/qt6ct/colors`;
Dolphin and other Qt 6 applications follow the qt6ct palette.
Alacritty and Kitty continue to receive the active terminal colors. Restart
Qt applications if they do not reload their platform theme dynamically.
These are dwm-titus palette adaptations of GTK's built-in widgets, not the
upstream third-party theme packages. Libadwaita and sandboxed applications may
follow only the light/dark preference rather than the custom palette.

Existing explicit `gtk_theme` values and Appearance personalization overrides
are preserved. Remove an explicit GTK theme setting to follow the bundled
preset automatically, or select a `Dwm-` theme in Appearance. The existing explicit `Nordic` selection remains supported; `Dwm-nord` is
also available offline. Existing installations need the supported source
installer once (`./install.sh --profile recommended`) to add the new system
file paths before subsequent updates can use Settings.
Maintainers regenerate assets with `python3 scripts/generate-app-themes.py`
after changing the shipped palettes.

Cursor theme changes in Settings take effect immediately across running X11
applications via `dwm-cursor-reload`.

See the [Configuration Guide](docs/src/content/configuration.md)
and [Theming Guide](docs/src/content/theming.md) for examples and
safe customization paths.

## Documentation

- [Installation](docs/src/content/install.md)
- [Getting Started](docs/src/content/getting-started.md)
- [Keybindings](docs/src/content/keybinds.md)
- [Configuration](docs/src/content/configuration.md)
- [Theming](docs/src/content/theming.md)
- [Control Center](docs/src/content/control-center.md)
- [Settings](docs/src/content/settings.md)
- [How dwm-titus Works](docs/src/content/patches.md)
- [Troubleshooting](docs/src/content/troubleshooting.md)

The technical guide explains the project architecture, what dwm is, and how
the maintained enhancements fit together. You do not need to understand or
apply dwm patches to install and use the desktop.

## Troubleshooting

System package updates in **Settings -> System** and the Update Center are not
yet ported to Arch and report an unsupported state. Run `sudo pacman -Syu` in a
terminal instead, and review pacman's prompts before confirming. Never run
`pacman -Sy` on its own.

The same section provides confirmed account, password, printer, and software-source
tool launches. Missing tools or stale provider status disable only the affected
entry. Account and repository inventories remain read-only. A successful launch
does not mean administration inside the tool completed; authorize and confirm
those changes in the tool itself. Enter passwords only in the terminal prompt.

For timezone or system locale, **Load choices**, filter and select a reported
value, then **Review change**. Network time offers fixed enable/disable previews.
Review the complete preview before **Apply change**: a sent regional change
cannot be canceled. Cancel only dismisses the preview, and closing Settings does
not undo an action. An uncertain result requires fresh status and new confirmation,
not automatic retry. Locale changes apply to new sessions; log out manually when
ready. Synchronization status is labeled as the last read.
The panel and System Settings share one minute-level local clock. A newly
reported timezone refreshes both displays without restarting Quickshell.

Start with the built-in diagnostic report:

```bash
dwm-diagnostics
```

You can also run **Control Center -> Quick Actions -> Self-Heal** to execute a
configured workstation repair script (`dwm-self-heal` on `$PATH` or referenced in
`${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/self-heal.path`) inside an interactive
terminal with visible output and authorization prompts.

You can also open **Control Center -> System Health** for a graphical overview.
If the session does not start, run `startx` from a TTY to see its error output.
The [Troubleshooting Guide](docs/src/content/troubleshooting.md)
covers common session, panel, terminal, theme, display, and NVIDIA issues.

If the problem remains, [open an issue](https://github.com/moheladwy/dwm-titus-archlinux/issues)
and include the relevant diagnostic output. Review it first and remove any
private system information.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the
development workflow and validation requirements, and report security issues
using [SECURITY.md](SECURITY.md).

The main repository check uses a managed workspace under `$HOME/tmp` and
removes it when the run finishes:

```bash
scripts/run-tests
```

Project requirements and active work are tracked in [SPEC.md](SPEC.md),
[ROADMAP.md](ROADMAP.md), and [TASKS.md](TASKS.md).
