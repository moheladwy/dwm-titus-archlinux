---
title: Updates
description: Keep dwm-titus, Arch Linux packages, Flatpak applications, and mise tools current from the panel Update Center or Settings.
navLabel: Updates
eyebrow: Stay current
---

# Updates

dwm-titus has two update surfaces: the **Update Center** in the panel and the
**Desktop updates** card in Settings > System. Both report failures instead of
claiming success. Settings previews desktop changes before starting, and the
system update shows pacman's own transaction prompts in the terminal.

## Panel Update Center

Click the update indicator beside the clock to open the Update Center popup.
It lists the providers that are available on the machine:

- system packages, labeled with your distribution name ("Arch Linux")
- the managed dwm-titus desktop
- Flatpak applications
- mise-managed tools, when mise is installed
- AUR packages, only when `paru` or `yay` is already installed

Expand a provider to inspect its available updates, then choose **Update** for
that provider. Updates run in a dedicated terminal using the saved window mode.
Closing the popup leaves the operation running. **Progress** reopens the desktop
update progress window while desktop work is active or needs attention. Read the
terminal result and press a key to close it.

In the Update Center's Settings tab, **Float update terminal** controls whether
the next update or recovery terminal floats. It does not change the Update
Center popup itself. Refresh preferences set the periodic repository check and
whether the indicator stays visible when everything is current. Reconnecting a
network triggers a fresh check; manual refresh still works offline.

The system update first checks the Arch Linux news feed and asks you to
continue past unread items, then runs an interactive `sudo pacman -Syu` with
pacman's own prompts. No `--noconfirm` is supplied, and nothing reboots the
machine automatically. Update discovery reads pacman's databases through
pyalpm in a private copy, so checking never refreshes the real sync databases
and cannot cause a partial upgrade. AUR updates run `paru -Sua` or `yay -Sua`
as your user, never as root.

Choosing **Recover** reattaches to or reconciles interrupted provider work,
including a desktop update that is still running. Recovery is not a rollback and does not prove the earlier attempt
succeeded.

## Desktop updates in Settings

The first card in **Settings > System** checks the desktop against the `main`
branch of this fork. It covers the managed Quickshell configuration, dwm,
installed commands, managed data, and cursor assets. System package updates
below it continue to manage the Quickshell package and other packages through
pacman.

Opening System checks once with a five-minute cache; **Check again** bypasses it.
**Update desktop** previews the operation and any missing required packages.
**Confirm update** installs them with one administrator authorization for the
whole operation. Settings closes while the password dialog is shown, and a
separate progress window stays open through shell restarts with the current
stage and elapsed time. **Hide** keeps the update running; **View log** opens a
bounded log viewer. Nothing is installed just by opening Settings.

An interrupted desktop update blocks further updates until it is recovered or
completed. Closing Settings does not stop an update. Reopening Settings reads
the saved operation and resumes progress reporting.

Updates preserve personal TOML files, application configuration, `.xinitrc`,
and `config.h`. They replace the managed Quickshell tree and the managed
`config` and `scripts` data trees from a fixed official revision. Local branches,
edits, generated caches, worktrees, and divergent Git history do not block
installation updates. The full previous data tree, including local work in those
managed directories, remains in the recovery backup. Local Git metadata and
unrelated files are retained without advancing Git HEAD; external development
checkouts are left untouched. Keep development work in a separate checkout so
managed installation updates do not replace its files.

## Existing installations

An older source installation must run the
[source update procedure](/install.html#source-updates-and-recovery) once to
install the desktop updater and its root-owned authorization helper. After that,
the Update Center and Settings > System can manage later updates.

For the complete contract, see
[Desktop updates and recovery](https://github.com/moheladwy/dwm-titus-archlinux/blob/main/docs/DESKTOP-UPDATES.md).
