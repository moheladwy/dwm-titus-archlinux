# Applications

## Choosing a source

Try these in order, and tell the user which source you picked and why:

1. **Official Arch repositories** (pacman). Search first:
   `pacman -Ss TERM`, then `pacman -Si NAME` for details.
2. **Flathub** (Flatpak), set up as a per-user remote by the `recommended`
   and `full` profiles. Good for proprietary or fast-moving desktop apps.
   Search: `flatpak search TERM`.
3. **AUR**, only when `paru` or `yay` is already installed and the user
   agrees to an AUR package. Check: `command -v paru yay`.
4. **AppImage** through Gear Lever, or a **web app** for sites without a
   native client.

## Official packages

Always install together with a full upgrade. Never `pacman -Sy` alone, and
never `pacman -S NAME` while `pacman -Qu` lists updates:

```sh
sudo pacman -Syu --needed firefox
```

Let pacman show its transaction and prompt. Do not add `--noconfirm`. If
`sudo` needs a password you cannot type, hand the user the exact command.
If another pacman holds the lock, point to `sudo fuser -v
/var/lib/pacman/db.lck` and wait. Never delete the lock.

## Flatpak

```sh
flatpak install --user flathub com.slack.Slack
flatpak run com.slack.Slack
flatpak list --user --app
flatpak uninstall --user com.slack.Slack
```

Use `--user`, which matches the remote the installer configured. If the
Flathub remote is missing, run `dwm-flatpak-setup --user`. Flatpak updates
appear in the Update Center.

## AUR

Only with an existing helper and the user's agreement. First bring the system
fully up to date, then build as the user, never as root and never with
`sudo`:

```sh
sudo pacman -Syu
paru -S --needed PACKAGE      # or: yay -S --needed PACKAGE
```

Show the user the PKGBUILD review prompts; do not skip them. Never install
an AUR helper on your own. AUR updates appear in the Update Center row
"AUR" and run `paru -Sua` or `yay -Sua` as the user.

## AppImages

Gear Lever (`it.mijorus.gearlever`, a Flatpak) integrates AppImages with the
launcher. Have the user open the `.AppImage` file with Gear Lever, or run
`flatpak run it.mijorus.gearlever`. If it fails to start, see
`maintenance.md`. Repair the setup with `install-gearlever`.

## Web apps

```sh
webapp-create create 'Gmail' 'https://mail.google.com' 'https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gmail.png' webapp-launch
webapp-create list
webapp-create remove 'Gmail'
```

Always pass `webapp-launch` as the fourth argument. Without it the entry
falls back to a command named webapp-launcher, which is not installed, and
the launcher item does nothing.

This writes a `.desktop` entry to `~/.local/share/applications/`, so the app
shows up in the launcher (`Super+R`). To bind it to a key, use
`webapp-launch URL` in `hotkeys.toml` (the `$webapp` variable).

## Removing apps

Check that a package is not part of the desktop before removing it:

```sh
for p in full lightdm terminal terminal-primary aur-optional; do dwm-packages.sh arch "$p"; done | sort -u | grep -x NAME
pacman -Qi NAME                       # "Required By" shows dependents
pacman -Rns --print NAME              # preview; changes nothing
sudo pacman -Rns NAME                 # then review pacman's own prompt
```

If `NAME` is in the dwm-titus package map, explain what breaks and ask
before removing it. `dwm-diagnostics` afterwards shows anything degraded.

## Default applications

```sh
dwm-default-apps status
dwm-default-apps browsers                              # list browser desktop ids
dwm-default-apps set-browser firefox.desktop
dwm-default-apps set-role file-manager org.kde.dolphin.desktop
dwm-default-apps set-role terminal kitty.desktop
dwm-default-apps set-mime application/pdf org.gnome.Evince.desktop
dwm-default-apps reset-role browser                    # restore the value before the last change
```

`reset-role` restores what the role was before the last `dwm-default-apps`
change to it. Without that recovery record, or when the file changed since,
it fails with "recovery is unavailable"; then set the role explicitly.

Desktop ids are the `.desktop` file names in `/usr/share/applications/` or
`~/.local/share/applications/`. `set-mime` accepts only these types:
`x-scheme-handler/http`, `x-scheme-handler/https`, `text/html`,
`application/xhtml+xml`, `inode/directory`, `text/plain`, `application/pdf`,
`image/png`, `image/jpeg`, `image/gif`, `image/bmp`, `image/tiff`,
`audio/mpeg`, `video/mp4`. For any other type use
`xdg-mime default ID TYPE`. Settings > Defaults does the same and offers
Restore Previous.

### Changing the terminal

`dwm-default-apps set-role terminal ID` rewrites `terminal` under `[vars]` in
`hotkeys.toml` (the `Super+X` binding), with rollback on failure. Supported
ids: `Alacritty.desktop`, `org.alacritty.Alacritty.desktop`, `kitty.desktop`,
`st.desktop`, `xterm.desktop`, `warp-terminal.desktop`,
`dev.warp.Warp.desktop`, `dwmterm.desktop`. Also:

- `dwm-terminal`, used by helpers that open a terminal, reads `DWM_TERMINAL`
  if it is set in the session environment.
- Dolphin's "Open Terminal" reads `TerminalApplication` under `[General]` in
  `~/.config/kdeglobals`.

Install the terminal first with `sudo pacman -Syu --needed NAME`.

### Changing the file manager or browser

Install the app, then set its role as above. `Super+E` runs `xdg-open .` and
`Super+B` runs `dwm-default-apps open`, so both follow the defaults; no
hotkey edit is needed.

## Launching an app from a key

Add a `spawn` entry to `~/.config/dwm-titus/hotkeys.toml` after checking for
clashes (see `configuration.md`):

```toml
{ mod="SUPER SHIFT", key="n", desc="Obsidian", func="spawn", exec=["obsidian"] },
{ mod="SUPER SHIFT", key="s", desc="Slack",    func="spawn", exec=["flatpak", "run", "com.slack.Slack"] },
```

dwm starts commands with the session `PATH`, which usually does not include
`~/.local/bin`. `exec=[...]` runs the program directly and expands only
`[vars]` entries, so for a script there use `cmd=`, which runs through
`/bin/sh -c` and expands `$HOME`:

```toml
{ mod="SUPER SHIFT", key="t", desc="My tool", func="spawn", cmd="$HOME/.local/bin/tool" },
```

Pair it with a window rule if the app should open on a tag, float, or stay
on top.

## Autostart

dwm-titus starts XDG autostart entries at login.

- Easiest: Settings > Defaults lists every autostart entry with its origin
  and lets the user enable, disable, or reset it for the next login. Vendor
  files are never edited.
- From a terminal: `dwm-xdg-autostart snapshot` prints entries with their
  revisions; `dwm-xdg-autostart set ID enabled|disabled REVISION` changes
  one. Session-critical entries (locker, compositor, polkit agent) also
  need `confirm-session-critical`; ask the user first.
- A new program: write `~/.config/autostart/NAME.desktop`:

  ```ini
  [Desktop Entry]
  Type=Application
  Name=Syncthing
  Exec=syncthing serve --no-browser
  X-GNOME-Autostart-enabled=true
  ```

Changes apply at the next login.
