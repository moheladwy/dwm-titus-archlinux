---
title: Troubleshooting
description: Resolve common dwm-titus startup, panel, application, theme, keybind, multi-monitor, NVIDIA, suspend, and compositor issues.
navLabel: Troubleshooting
eyebrow: Get unstuck
---

# Troubleshooting

Run the dependency checker first; it covers most common issues:

```bash
dwm-diagnostics
```

Or use the [Control Center](./control-center.html) -> **System Health**.

---

## Login keyring asks for a password every login

If the prompt says the login keyring did not get unlocked, run
`dwm-diagnostics` or open System Health. On Arch, the `gnome-keyring` package
ships both the keyring daemon and the `pam_gnome_keyring.so` login module, but
a working daemon does not prove automatic unlock is available: the login PAM
stack must also load that module. Every installer profile includes
`gnome-keyring`, and source/desktop updates reconcile it on existing
installations. To repair it by hand, use a full upgrade:

```sh
sudo pacman -Syu --needed gnome-keyring
```

Arch's LightDM PAM configuration (`/etc/pam.d/lightdm`) already loads the
module. If you start the session with `startx` from a TTY, add the module to
`/etc/pam.d/login` yourself, as described in the
[ArchWiki GNOME Keyring page](https://wiki.archlinux.org/title/GNOME/Keyring#PAM_step);
the installer never edits PAM files.

Log out and back in with your account password. If the prompt persists, use
Passwords and Keys to set the Login keyring password to match your account
password. Passwordless autologin does not pass a login password to the
keyring, so the PAM module alone cannot enable automatic unlock for that path.

## Gear Lever does not open

Gear Lever requires Flatpak's document portal. If launching it prints a
`bwrap: Can't find source path /run/user/.../doc/by-app/...` error, the portal
process has outlived its FUSE mount. Repair the current user session with:

```sh
systemctl --user restart xdg-document-portal.service
flatpak run it.mijorus.gearlever
```

The recommended and full installers include Flatpak, the GTK portal, and a
user-scoped Gear Lever installation from Flathub by default. To repair only the
application setup from an installed dwm-titus checkout, run:

```sh
install-gearlever
```

---

## dwm Won't Start

**Black screen / returns immediately to login:**
- Run `dwm-diagnostics` and resolve any required X11/session failures.
- Preview required packages with `./install.sh --dry-run --profile core`.
- If you use `startx`, check that `~/.xinitrc` exists and its last line starts
  dwm (the shipped file ends with `dbus-run-session -- sh -c 'exec dwm'`)
- Run `startx` from a TTY to see error output in the terminal

**`dwm: cannot open display`:**
- You must launch dwm from a TTY, not an existing X session
- If using a display manager, ensure `dwm.desktop` is in `/usr/share/xsessions/`

---

## No Status Bar / Quickshell Missing

- Install the recommended desktop layer: `./install.sh --profile recommended`
- Verify the managed config exists: `ls ~/.config/quickshell/shell.qml`
- Relaunch it with `Super`+`Shift`+`R` or
  `dwm-quickshell-controlcenter action restart-quickshell`
- Check fonts: `fc-list | grep -i meslo`

---

## Terminal Won't Open (`Super`+`X`)

- Run `alacritty` from an existing shell to inspect its error directly
- Install Alacritty with a full upgrade: `sudo pacman -Syu --needed alacritty`
- Confirm the fixed terminal in `~/.config/dwm-titus/hotkeys.toml`:
  ```toml
  [vars]
  terminal = "alacritty"
  ```

Herdr is an optional terminal workspace, not a graphical terminal emulator.
Install it explicitly and use `DWM_HERDR=1 dwm-terminal` to run it inside
Alacritty. The default `Super`+`X` binding remains plain Alacritty.

## Browser Won't Open (`Super`+`B`)

- Run `dwm-default-apps status` to inspect the current default browser
- Run `dwm-default-apps browsers` to list installed browser desktop files
- Set one with `dwm-default-apps set-browser firefox.desktop`
- Open Settings -> Defaults to inspect provider details, candidates, and the
  Restore Previous action
- Ensure `xdg-utils` is installed so `xdg-settings`, `xdg-mime`, and `xdg-open`
  are available

## Startup Application Change Failed

- Open Settings -> Defaults and inspect the entry origin, effective state, and
  detail. Malformed or conditional vendor entries are intentionally not
  rewritten.
- Changes apply at the next login; Settings does not start or stop the
  application in the current session.
- A stale-revision error means the entry changed after it was displayed. Use
  Refresh and retry.
- Reset to vendor removes only the managed user override. Existing vendor
  desktop files are never edited.

---

## Themes Not Applying

- Confirm `themes.toml` is at `~/.config/dwm-titus/themes.toml`
- Check the `[active]` section has a valid theme name
- Manually trigger: `kill -USR1 $(pidof dwm)`
- Run `theme-apply.sh` directly to see any errors

---

## Keybinds Not Working

- Check `~/.config/dwm-titus/hotkeys.toml` for syntax errors. Invalid TOML
  shows a critical "dwm: bad config" notification and dwm keeps its previous
  bindings
- Verify the key name is correct (use `xev` to find X11 key names)
- If a bind still doesn't work, add it as a fallback in `config.h` and recompile

---

## Brightness Keys Do Nothing

- The default brightness keys run `dwm-brightness 10%+` and
  `dwm-brightness 10%-`, which use `brightnessctl` on the backlight of the
  enabled internal panel. This matters on hybrid-graphics laptops that expose
  two backlights.
- Installs keep an existing `~/.config/dwm-titus/hotkeys.toml`. If your
  bindings still call `brightnessctl set ...` without a device, change them to
  `dwm-brightness 10%+` and `dwm-brightness 10%-`.
- Run `brightnessctl -l` to list the available backlights.

---

## Tray Icon Missing After a Panel Restart

- The panel runs `dwm-quickshell-tray resync` automatically after it starts.
  You can also run it yourself: it prints each icon it registers and prints
  nothing when nothing needed registering.
- Apps that publish no StatusNotifierItem at `/StatusNotifierItem` cannot be
  re-registered; restart those apps.

---

## Volume Shows Above 100%

- The panel shows the real output level. `pactl`-style `+5%` steps, including
  scrolling on the panel volume widget, can boost the volume past 100%.
- Lower it with the slider in the panel's audio controls, or with
  `pactl set-sink-volume @DEFAULT_SINK@ 100%`.

---

## Multi-Monitor Issues

- Tags not syncing across monitors: run `dwm-diagnostics`
- Cursor doesn't follow focus: verify cursor warp is enabled in `config.h` (`cursorwarp = 1`)
- Persistent resolution or positioning: run `dwm-display-setup detect`, then
  `dwm-display-setup`. The wizard previews changes before writing Xorg config.
- Bad persistent layout: run `dwm-display-setup rollback`, then log out and
  back in. From a TTY, remove
  `/etc/X11/xorg.conf.d/90-dwm-titus-display.conf` if Xorg cannot start.
- TearFree is enabled only when the active Xorg driver exposes a compatible
  option or RandR property. Unsupported drivers are left unchanged.
- NVIDIA Full Composition Pipeline is enabled in generated persistence only
  when the relevant output uses the NVIDIA kernel driver and an NVIDIA Xorg
  provider is available, including supported hybrid configurations. Run
  `dwm-display-setup capabilities` to inspect the detected fallback before
  saving a layout.
- Display layout profiles: run `dwm-display-profile dir` and
  `dwm-display-profile template` to create optional `xrandr` profiles

---

## NVIDIA / Suspend Issues

- Black screen on wake: run `nvidia-suspend-test.sh` to diagnose
- DPMS/screensaver issues: use Control Center -> Power, or run
  `disable-powersaving` to disable blanking and DPMS for the current
  session

---

## System Update Problems

System updates run as an interactive `sudo pacman -Syu` in the Update Center
terminal, opened from the panel update icon or Settings > System **Open system
update**.

- **The terminal reports a held pacman lock.** `/var/lib/pacman/db.lck`
  exists, usually because another pacman is running. Find the owner with
  `sudo fuser -v /var/lib/pacman/db.lck` and let it finish. The desktop never
  deletes the lock.
- **Arch news is unavailable.** The news feed could not be fetched. Read
  [Arch Linux news](https://archlinux.org/news/) yourself before answering
  the prompt to continue.
- **An update was interrupted.** pacman does not roll back. Check
  `/var/log/pacman.log` for what was applied, then choose **Recover** in the
  Update Center to start a fresh `sudo pacman -Syu`.
- **Settings shows a network warning.** The remote check failed, so the list
  comes from cached databases. Reconnect and reopen Settings to check again.
- **Settings warns that PackageKit is installed.** PackageKit clients can run
  `pacman -Sy` behind your back, which leads to partial upgrades. Consider
  removing `packagekit` if nothing else needs it.
- **No AUR row in the Update Center.** It appears only when `paru` or `yay` is
  already installed. dwm-titus never installs an AUR helper.

Never run `pacman -Sy` on its own; always use the full `sudo pacman -Syu`.

---

## Picom / Compositor Artifacts

Restart picom via the Control Center (**Quick Actions → Restart Picom**) or:
```bash
dwm-settings-picom restart
```

If artifacts persist, choose XRender or GLX in **Settings > Appearance >
Compositor**. EGL is experimental. Automatic selection uses the active renderer
and retries XRender if automatic GLX startup fails. Existing configuration choices
and `PICOM_BACKEND=glx` or `PICOM_BACKEND=egl` session overrides remain respected.

Run `dwm-settings-picom status` to see the configuration path and effective
backend. The controls remain available while Picom is stopped. Configuration
errors and concurrent edits are reported without silently replacing your choices;
activation errors identify a recovery backup and session log.


---

## Still Stuck?

- Open an issue: [github.com/moheladwy/dwm-titus-archlinux/issues](https://github.com/moheladwy/dwm-titus-archlinux/issues)
- Run the full check: `check-deps.sh`
