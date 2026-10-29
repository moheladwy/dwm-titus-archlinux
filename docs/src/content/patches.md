---
title: How dwm-titus Works
description: A plain-language guide to the window management, shell, live configuration, utilities, and multi-monitor behavior behind dwm-titus.
navLabel: How It Works
eyebrow: Under the hood
---

# How dwm-titus Works

dwm-titus uses a maintained fork of
[dwm](https://dwm.suckless.org/), a compact window manager for X11. A window
manager controls where application windows appear, how they are arranged, and
which window receives input. Unlike a full desktop environment, upstream dwm
focuses on this core job and is configured primarily in source code.

The dwm community traditionally distributes optional features as source-code
"patches." dwm-titus already integrates and maintains a curated set of those
ideas alongside its own runtime configuration, Quickshell desktop layer,
Settings experience, and system helpers. Users do not need to find or apply
patches themselves.

This page documents the major technical additions to the window-manager core
and how they support the complete desktop experience.

---

## Window Management Patches

### Pertag
Each tag independently remembers its layout, master count, and master/stack sizing. Switching tags restores the previous layout for that tag.

### Cfact
Assign per-window size weights within the stack area. Windows are no longer forced to equal height.

| Keys | Action |
|------|--------|
| `Super` + `Shift` + `H` | Grow this window's slot |
| `Super` + `Shift` + `L` | Shrink this window's slot |
| `Super` + `Shift` + `O` | Reset to equal sizing |

### Movestack
Reorder windows within the stack without using the mouse.

| Keys | Action |
|------|--------|
| `Super` + `Shift` + `J` | Move window down |
| `Super` + `Shift` + `K` | Move window up |

### Window Swallowing
When a GUI application is launched from a terminal, it replaces the terminal in the layout. Closing the app brings the terminal back.

Controlled via window rules in `~/.config/dwm-titus/window-rules.toml`:
```toml
{ class="Alacritty", isterminal=1 },
```
Mark a terminal with `isterminal=1`; add `noswallow=1` to a rule to keep that
window from ever swallowing its terminal.

### Fullscreen (3-State)
Three fullscreen modes available:

| Mode | Keys | Description |
|------|------|-------------|
| Fullscreen (monocle) | `Super` + `M` | Switches to the monocle layout and hides the bar; press again to restore |
| Fake fullscreen | `Super` + `Shift` + `Y` | Looks fullscreen, bar still usable |
| Monocle layout | — | Single window view, bar visible |

---

## Bar & EWMH

### Quickshell Integration
The managed Quickshell layer reads dwm workspace and active-window state through
EWMH-compatible helpers so the panel stays synchronized with X11 state.
The Control Center includes a Power page for screen DPMS and automatic locking
settings backed by `${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/power.conf`.

### EWMH Compliance
Implements `_NET_WM_STATE`, `_NET_CURRENT_DESKTOP`, `_NET_NUMBER_OF_DESKTOPS`, and related atoms so external tools and taskbars work correctly.

### Window Icons
Title bar icons via `_NET_WM_ICON`. Applications that set this atom display their icon in the bar.

### Systray
The system tray is part of the Quickshell panel, which hosts StatusNotifier
tray icons; it has no `config.h` options. After the panel restarts it runs
`dwm-quickshell-tray resync` to re-register icons that applications still
publish, so apps that register only once at startup reappear.

---

## Visual

### Noborder
When only one window is visible on a tag, its border is automatically removed for a cleaner look. Borders return when a second window appears.

### Cursor Warp
When focus moves to a different window or monitor (via keyboard), the mouse cursor warps to the center of the newly focused window.

---

## Live Configuration

### TOML Hotkeys (`hotkeys.toml`)
Keybindings are parsed from `~/.config/dwm-titus/hotkeys.toml` at runtime; the repository's `config/hotkeys.toml` is the shipped default. Edit and save — bindings update without recompiling or restarting dwm.

### TOML Themes (`themes.toml`)
Colors for dwm, terminal, GTK, and Qt are sourced from
`~/.config/dwm-titus/themes.toml`, with the repository's `config/themes.toml`
as the shipped default. Save the file to apply a new theme instantly across
supported apps.

---

## Scripts & Utilities

| Script | Description |
|--------|-------------|
| `dwm-controlcenter` | Quickshell control center (`Super`+`F1`) |
| `dwm-keybinds` | Searchable keybind viewer (`Super`+`/`) |
| `dwm-quickshell-launcher` | Indexes desktop entries and launches ChatGPT with a native-first web fallback |
| `dwm-screenshot` | Cursor-free `maim` wrapper (screen, full, gui, clip modes) |
| `dwm-settings-theme` | Previews, applies, resets, and recovers theme selection transactionally |
| `theme-apply.sh` | Converges the active theme from user or managed `themes.toml` across supported apps |
| `webapp-create` | Creates a web app shortcut |
| `webapp-launch` | Launches a URL as a standalone web app window |
| `autostart.sh` | Runs programs on dwm start |
| `check-deps.sh` | Checks all required dependencies |
| `disable-powersaving` | Disables DPMS and screen blanking |

---

## Multi-Monitor

Xinerama support keeps tags independent per monitor. Windows can be moved
between monitors with `Super` + `Shift` + `,`/`.`.
