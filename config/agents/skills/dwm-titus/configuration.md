# Configuring dwm-titus

User configuration lives in `${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/`.
The three TOML files reload live when saved. To force a reload, run
`kill -USR1 "$(pidof dwm)"`. Back up a file before editing it, and read the
comments at the top of each file: they document the full syntax.

## Keybindings: `hotkeys.toml`

```toml
[vars]
terminal = "alacritty"
webapp   = "webapp-launch"

keys = [
  { mod="SUPER",       key="x", desc="Terminal", func="spawn", exec=["$terminal"] },
  { mod="SUPER SHIFT", key="f", desc="Firefox",  func="spawn", exec=["firefox"] },
  { mod="SUPER",       key="n", desc="Notes",    func="spawn", cmd="cd ~/notes && alacritty -e nvim" },
]

tag_keys = [
  { key="1", tag=0 },
]
```

- `mod`: space-separated `SUPER`, `SHIFT`, `CTRL`, `ALT`, or `""`.
- `key`: an X11 keysym name (`a`, `Return`, `space`, `comma`, `F1`,
  `XF86AudioMute`). Find one with `xev`.
- `func`: `spawn` (with `exec=[...]` for argv, or `cmd="..."` for a shell
  command), `killclient`, `zoom`, `focusstack`/`movestack`/`incnmaster`
  (`i=1`/`i=-1`), `setmfact` (`f=0.05`), `setcfact` (`f=0.25`), `setlayout`
  (`layout_idx=0` tile, `1` float, `2` monocle), `togglefloating`,
  `fullscreen`, `togglefakefullscreen`, `togglebar`, `focusmon`/`tagmon`
  (`i=1`/`i=-1`), `view` (`ui=-1` = all tags), `tag`, `toggleview`,
  `toggletag`, `quit`.
- `$name` expands a `[vars]` entry inside `exec` and `cmd`.
- Each `tag_keys` entry generates the view, toggle-view, move, and toggle-tag
  bindings for that tag.

Put new bindings inside the `keys = [ ... ]` array, before its closing `]`.
The commented examples under "CUSTOM SHORTCUTS" sit after the array, and
entries placed there are ignored. Before adding a binding, search for the same
`mod` and `key` pair and tell the user about any clash. Invalid TOML fails
silently, so re-read the edited lines and test the key afterwards. `SUPER`
means the build's `MODKEY` (Super unless the user chose Alt when building).

Panel and shell actions are `spawn` entries that call `quickshell ipc --path
"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml" call TARGET FUNCTION`
or a `dwm-quickshell-*` helper. The session does not export
`XDG_CONFIG_HOME`, so keep the `:-$HOME/.config` fallback. Copy an existing
entry rather than writing one from scratch.

## Window rules: `window-rules.toml`

```toml
rules = [
  { class="Alacritty", isterminal=1 },
  { class="Gimp", isfloating=1 },
  { class="steam", tags=5, monitor=1 },
  { class="mpv", title="Picture-in-Picture", isfloating=1, alwaysontop=1 },
  { class="YourGame", fakefullscreen=1, ignoresizehints=1 },
]
```

Fields: `class` (second `WM_CLASS` value), `instance` (first value), `title`
(case-sensitive substring), `monitor` (`-1` any), `tags` (`1`-`9`; `0` or
omitted = current tag), `isfloating`, `isterminal` (enables swallowing),
`noswallow`, `fullscreen` (true fullscreen on open), `fakefullscreen`
(borderless monitor-sized window without EWMH fullscreen; exit with
`Super+Shift+Y`), `ignoresizehints`, and `alwaysontop`. Flags take integer
`1`. Every matching rule applies in order, and a later match resets the flags
it omits to 0, while `tags` accumulate across matches. Keep broad class rules
before specific class-and-title rules, and repeat any flag the specific rule
must keep.

Identify a window first: run `xprop WM_CLASS WM_NAME` and click it. Rules
apply when a window opens, so close and reopen it after saving. Unmanaged
overlays (`override_redirect`) only use `alwaysontop`, and it reloads live.

## Themes: `themes.toml`

Prefer the transaction helper; it preserves comments and custom themes and
keeps recovery data:

```sh
dwm-settings-theme apply dracula
dwm-settings-theme preview p1 15 gruvbox   # live preview for 15 seconds
dwm-settings-theme keep p1                 # or: dwm-settings-theme revert p1
dwm-settings-theme reset                   # back to the default theme
dwm-settings-theme recovery-status         # after an interrupted change
```

Built-in themes: `nord` (default), `dracula`, `gruvbox`, `catppuccin`,
`tokyonight`, `onedark`, `solarized`, `rosepine`, `everforest`,
`monochrome`, and the light themes `catppuccin-latte`, `gruvbox-light`,
`solarized-light`, `rosepine-dawn`, `tokyonight-day`.

A theme recolors dwm, the panel, terminals, GTK, and Qt. Border width is
`borderpx` under `[appearance]`. A custom theme is a new `[theme.NAME]`
section with `normfgcolor`, `normbgcolor`, `normbordercolor`, `selfgcolor`,
`selbgcolor`, `selbordercolor`, `term_bg`, `term_fg`, `term_cursor`,
`term_color0` to `term_color15`, `dark_mode`, and optionally `gtk_theme`.
Copy an existing section, rename it, edit the colors, then
`dwm-settings-theme apply NAME`. If a theme does not apply, run
`theme-apply.sh` to see its errors.

## Wallpaper, fonts, cursor, icons

```sh
dwm-settings-wallpaper apply "$HOME/Pictures/backgrounds/wall.jpg" fill   # center|fill|max|scale|tile
dwm-settings-wallpaper randomize     # one-off random image from ~/Pictures/backgrounds/
dwm-settings-wallpaper reset         # random-fill session default

dwm-settings-personalization apply font "Noto Sans"
dwm-settings-personalization apply text-size 1.25   # 0.75 0.875 1.0 1.125 1.25 1.5 1.75 2.0
dwm-settings-personalization apply cursor Adwaita
dwm-settings-personalization reset font
dwm-settings-personalization status
```

The panel icon font stays Meslo Nerd Font whatever text font is chosen.

## Panel widgets

```sh
dwm-panel-settings status
dwm-panel-settings set bluetooth disabled   # workspaces|volume|bluetooth|network|power
dwm-panel-settings reset
```

The panel layout itself is Quickshell code in the managed
`~/.config/quickshell/`. Do not edit it there; see "Source changes" below.

## Displays

```sh
dwm-display-setup              # interactive wizard: preview, then a confirmed Xorg fragment
dwm-display-setup status
dwm-display-setup rollback     # restore the previous managed fragment
dwm-display-profile list       # optional named xrandr profiles
dwm-display-profile apply NAME
```

The wizard writes only `/etc/X11/xorg.conf.d/90-dwm-titus-display.conf`, with
a backup, after the user confirms a live preview. It is interactive; run it
for the user only in their own terminal. If Xorg no longer starts, delete that
one file from a TTY.

## Input, power, notifications

These are easiest in Settings (`dwm-settings open`) or the Control Center
(`Super+F1`):

- Input devices and keyboard layout: Settings > Input. Saved values live in
  `~/.config/dwm-titus/input-settings.conf` and replay at login and hotplug.
  `setxkbmap` changes last only for the current session.
- Screen blanking, auto-lock, and suspend lock: Control Center > Power
  Settings, or Settings > Power. The file is
  `~/.config/dwm-titus/power.conf`.
- Do Not Disturb and popup duration: Settings > Appearance. The file is
  `~/.config/dwm-titus/notification-settings.json`.

## Compositor (Picom)

```sh
dwm-settings-picom status     # config path and effective backend
dwm-settings-picom restart
```

Opacity and backend (Automatic, XRender, GLX, EGL) live in Settings >
Appearance > Compositor. dwm-titus seeds no Picom file. When the user has no
`~/.config/picom.conf` (or `~/.config/picom/picom.conf`), Picom reads
`/etc/xdg/picom.conf`; `dwm-settings-picom copy-config` creates an editable
user copy. Edit the user copy, never the system file, then restart Picom.
Use XRender if GLX shows artifacts.

## Application configs

`~/.config/alacritty/`, `~/.config/kitty/`, `~/.config/starship/`, and other
application directories are seeded once and then belong to the user. Edit
them directly. The active theme rewrites terminal colors, so put color
changes in a custom theme instead.

## Compile-time options: `config.h`

`config.h` sits in the source checkout (the `checkout` in
`${XDG_STATE_HOME:-$HOME/.local/state}/dwm-titus/desktop-update/installed.json`;
if that is empty, see `maintenance.md`). It holds the build options TOML does
not cover: `refresh_rate`, `cursorwarp`, `snap`, `swallowfloating`,
`showbar`, `topbar`, bar `fonts[]`, `mfact`, `nmaster`, `resizehints`, and
`MODKEY`. Keybindings and window rules are not in `config.h`; they come only
from the TOML files. Edit it, then rebuild and resync from the checkout:

```sh
cd CHECKOUT
cp -a config.h "config.h.bak.$(date +%s)"
$EDITOR config.h
./scripts/dev-sync-install.sh          # builds, syncs, reports if a restart is needed
./scripts/dev-sync-install.sh --check  # read-only audit
```

A new dwm binary takes effect only after logging out and back in.

## Source changes (panel, helpers)

Panel QML and the helper scripts are managed copies. To change them, edit
the files in the checkout (`config/quickshell/`, `scripts/`), run
`./scripts/dev-sync-install.sh`, then restart the panel with
`dwm-quickshell-controlcenter action restart-quickshell`. Never start the
panel with a repository path (`quickshell --path config/quickshell`); hotkeys
talk to the installed `~/.config/quickshell/shell.qml` instance. Local source
edits block `git pull --ff-only`, and Settings > Desktop updates refuses a
checkout with local changes, so tell the user. Changes meant for the project
follow the repository `AGENTS.md` instead of this skill.

## Resetting to defaults

Always ask first and back up. To restore a shipped TOML file, copy it from
the managed data copy:

```sh
f=hotkeys.toml   # or themes.toml, window-rules.toml
cp -a ~/.config/dwm-titus/$f ~/.config/dwm-titus/$f.bak.$(date +%s)
cp ~/.local/share/dwm-titus/config/$f ~/.config/dwm-titus/$f
```
