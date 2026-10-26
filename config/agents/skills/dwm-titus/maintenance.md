# Updates, diagnostics, and recovery

## System updates

Arch supports only full upgrades. The desktop never refreshes the real sync
databases in the background; Settings and the Update Center read a private
copy, so checking for updates is always safe.

To update:

- Update Center (the panel update icon) > System > **Update**, or
  `dwm-update-center launch system`. It opens a terminal that checks the
  pacman lock, shows unread Arch Linux news and asks to continue, then runs
  `sudo pacman -Syu` with pacman's own prompts.
- Or hand the user `sudo pacman -Syu` to run in a terminal.

Before a large update, suggest reading https://archlinux.org/news/. Never add
`--noconfirm`, never run `pacman -Sy` on its own, and never interrupt a
running transaction.

Other Update Center providers: `aur` (only with `paru` or `yay`; runs
`-Sua` as the user), `dwm-titus` (the desktop itself), `flatpak`, and `mise`.
Each opens with `dwm-update-center launch PROVIDER`. `dwm-update-center
snapshot` prints the current state for all of them (machine format).

## Updating dwm-titus itself

Two supported ways:

1. **Settings > System > Desktop updates.** Checks `main` of
   `github.com/moheladwy/dwm-titus-archlinux`, shows what changes, and
   installs a confirmed update with progress and recovery records. It needs
   a fully upgraded system; otherwise it stops with "Update system packages
   first". Run `sudo pacman -Syu` and retry.
2. **From the checkout** (clean tree required):

   ```sh
   cd CHECKOUT                    # "checkout" in ~/.local/state/dwm-titus/desktop-update/installed.json
   git status --short             # must be empty; ask the user about local changes
   git pull --ff-only
   ./install.sh --yes --profile recommended   # use the profile they installed with
   ./scripts/dev-sync-install.sh
   ```

   Log out, log back in to dwm, then run `./scripts/dev-sync-install.sh --check`
   and `dwm-diagnostics`.

User TOML files, `config.h`, `~/.xinitrc`, and app configs survive updates.
`~/.config/quickshell/` and `~/.local/share/dwm-titus/` are replaced. For a
full backup recipe before updating, see the "Source Updates and Recovery"
section of `docs/src/content/install.md` in the checkout.

An install recorded from upstream `ChrisTitusTech/dwm-titus` is not trusted
by the updater. Reinstall from this fork with `./install.sh`.

## Diagnostics

Start here for any problem:

```sh
dwm-diagnostics                       # required failures must be zero
dwm-system-health scan-user           # structured session health snapshot
check-deps.sh                         # dependency check
journalctl --user -b --no-pager | tail -n 200
journalctl -b -p err --no-pager | tail -n 100
```

System Health (Control Center > System Health) shows the same checks with
confirmed repair buttons. For a source checkout, also run
`./scripts/dev-sync-install.sh --check` to compare installed files with it.

## Common fixes

| Symptom | Fix |
| --- | --- |
| Panel missing or frozen | `dwm-quickshell-controlcenter action restart-quickshell` (or `Super+Shift+R`). Check `ls ~/.config/quickshell/shell.qml`. |
| Hotkey or rule ignored | Re-read the TOML for syntax errors, check the key name with `xev`, then `kill -USR1 "$(pidof dwm)"`. |
| Theme not applied | `theme-apply.sh` shows errors; check `[active]` in `themes.toml`. |
| Compositor artifacts | `dwm-settings-picom restart`; choose XRender in Settings > Appearance > Compositor. |
| `Super+X` opens nothing | Run the terminal from a shell to see its error; check `terminal` under `[vars]`. |
| `Super+B` opens nothing | `dwm-default-apps status`, then `dwm-default-apps set-browser ID`. |
| Keyring password at every login | `startx` needs `pam_gnome_keyring.so` in `/etc/pam.d/login` (manual, on request only). The keyring and account passwords must match. |
| Gear Lever will not open | `systemctl --user restart xdg-document-portal.service`, then `flatpak run it.mijorus.gearlever`. |
| Bad monitor layout after login | `dwm-display-setup rollback`, then log out and in. |
| Xorg will not start | From a TTY (`Ctrl+Alt+F3`): remove `/etc/X11/xorg.conf.d/90-dwm-titus-display.conf` if the wizard wrote it; run `startx` to see errors. |
| Pacman lock held | `sudo fuser -v /var/lib/pacman/db.lck`; wait for that process. Never delete the lock. |
| Interrupted system update | Read `/var/log/pacman.log`, then Update Center > **Recover**, or run `sudo pacman -Syu` again. pacman does not roll back. |
| Settings warns about PackageKit | PackageKit frontends can run `pacman -Sy` behind the user's back. Suggest removing `packagekit` if nothing needs it. |
| NVIDIA black screen after suspend | `nvidia-suspend-test.sh` diagnoses the setup. |

## Recovery from a broken session

1. Switch to a TTY with `Ctrl+Alt+F3` and log in as the same user.
2. Run `dwm-diagnostics` and read the session journal.
3. Undo the last change: restore the `.bak` copy of any edited file, or
   `dwm-display-setup rollback` for display changes.
4. Rerun `./install.sh` and `./scripts/dev-sync-install.sh` from the checkout
   if installed files are missing or stale.
5. Log back in, or run `startx` from the TTY to see errors directly.

## Reporting a bug

Collect `dwm-diagnostics` output, the relevant journal lines, and the steps
to reproduce. Include the rolling-release record: the date and the versions
of pacman, Quickshell, Qt, and the kernel:

```sh
date -I; pacman -Q pacman quickshell qt6-base; uname -r
```

Issues: https://github.com/moheladwy/dwm-titus-archlinux/issues. Remove
personal data from logs before sharing, and ask the user before filing.
