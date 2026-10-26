---
title: Arch Linux Installation
description: Install the dwm-titus X11 desktop onto an existing Arch Linux system with the repository installer.
navLabel: Installation
eyebrow: Start here
---

# Arch Linux Installation

> **dwm-titus supports Arch Linux only.** Arch Linux x86_64 with Xorg is the
> sole supported platform for installation, runtime behavior, package
> resolution, and testing.

The installer reads `/etc/os-release` and accepts only `ID=arch`. `ID_LIKE` is
ignored, so Arch derivatives such as EndeavourOS, CachyOS, Manjaro, and Arch
Linux ARM are rejected, as is every other distribution. The check runs before
any package installation or system change, and there is no override flag.

dwm-titus ships no installer images, ISOs, downloads, or package repositories.
You install Arch Linux yourself, then add the desktop with `./install.sh`.

## Dependencies

See [Desktop Dependencies](/dependencies.html) for a component-by-component
breakdown of the window manager, shell, services, applications, build tools,
and the differences between installation profiles.

## 1. Install Arch Linux

Install Arch Linux with the official [Arch ISO](https://archlinux.org/download/),
either by hand following the
[installation guide](https://wiki.archlinux.org/title/Installation_guide) or
with `archinstall`. A minimal install with a user account, `sudo`, and network
access is enough. You do not need to install a desktop environment or display
manager first.

## 2. Run the Installer

Log in as your normal user (not root) and run the installer from a checkout of
[this repository](https://github.com/moheladwy/dwm-titus-archlinux):

```bash
sudo pacman -Syu --needed git
git clone https://github.com/moheladwy/dwm-titus-archlinux.git
cd dwm-titus-archlinux

./install.sh --dry-run --non-interactive --profile recommended
./install.sh --profile recommended
```

The dry run prints the resolved package and installation plan and exits
before anything changes. Interactive runs print the same plan and ask before
continuing. The installer refuses to run as root; it invokes `sudo` only for
package installation and system-wide files.

### System Upgrade First

Arch does not support partial upgrades. Before it installs any package, the
installer runs one visible `sudo pacman -Syu`:

- it is listed in the `--dry-run` plan;
- it uses pacman's own confirmation prompt;
- `--noconfirm` is added only with `--non-interactive`;
- if the upgrade fails or you decline it, the installation stops and no
  dwm-titus packages are installed.

Packages are then installed from the official repositories with
`sudo pacman -S --needed --`. The installer does not edit `/etc/pacman.conf`,
enable `multilib`, or add third-party repositories.

### Profiles

Select a profile with `--profile` or `DWM_INSTALL_PROFILE`. The default is
`full`.

- `core`: required build packages, the X11 session runtime, GNOME Keyring,
  Celluloid, mpv, sxiv, and one terminal (Alacritty, with a fallback to an
  installed or installable supported terminal). `minimal` is accepted as an
  alias.
- `recommended`: `core` plus the complete everyday desktop: Quickshell, Picom,
  Feh, Dex, a polkit agent, audio, Bluetooth, power, and brightness tools,
  Flatpak with the GTK portal, fonts, icons, the available GTK themes, the
  first available Qt theme tool (`qt6ct`, then `qt5ct`), and the
  system-management prerequisites (`pyalpm`, `pacman-contrib`,
  `python-gobject`, AccountsService, CUPS, and the printer configuration
  tool). It also adds Flathub for the target user, installs Gear Lever as the
  AppImage manager, and installs the Nordic GTK theme system-wide for the
  default Nord theme. `maim` is attempted; if it is unavailable, installation
  continues and reports that the screenshot hotkeys remain disabled.
- `full`: `recommended` plus the Dolphin file manager (`dolphin`, `ark`,
  thumbnailers, `kio-admin`, and `archlinux-xdg-menu`), `gvfs`,
  `xdg-user-dirs`, NetworkManager, `rsync`, both Qt theme tools, the optional account
  administration tool, the Nord wallpaper collection, and LightDM. There is no
  gaming profile.

When no display manager is detected, `full` installs and enables LightDM with
`lightdm-slick-greeter`. An existing GDM or SDDM is retained. When LightDM is
present, the installer deploys the project's greeter configuration with
Arch's `/etc/lightdm/Xsession` session wrapper.

Fresh accounts receive Celluloid audio/video and sxiv image defaults for their
advertised formats, and open folders in Dolphin (`org.kde.dolphin.desktop`)
when it is installed. Existing MIME preference files are preserved; change
these in Settings > Defaults on an existing account.

To add a broader profile's packages to an older installation, rerun the
installer with that profile. A dry run previews the added packages first. The
installer does not remove packages.

### Installer Options

| Option | Effect |
| --- | --- |
| `--profile PROFILE` | `core`, `recommended`, or `full`. Defaults to `DWM_INSTALL_PROFILE` or `full`. |
| `--non-interactive` | Use unattended defaults and do not prompt. Adds `--noconfirm` to pacman. Required when standard input is not a terminal. |
| `--yes` | Accept the interactive install summary. pacman still shows its own prompt. |
| `--install-herdr` | Install the verified Herdr terminal workspace. |
| `--skip-herdr` | Do not install Herdr (the default). |
| `--enable-aur` | Install the optional AUR packages with an existing `paru` or `yay`. |
| `--dry-run` | Print the resolved plan, including the system upgrade, and exit before changes. |

For CI, packaging checks, or scripted validation:

```bash
./install.sh --dry-run --non-interactive --profile core
./install.sh --non-interactive --yes --profile recommended
./install.sh --non-interactive --yes --profile full --enable-aur
```

### Optional AUR Packages

Every required package comes from the official Arch repositories. A few
optional extras exist only in the AUR: `xkbset` (used by the AccessX input
controls) and the Arc, Numix, Yaru, and Bluebird GTK themes.

They are installed only when you pass `--enable-aur`, or answer yes to the
interactive `[y/N]` question (default No) that appears when a supported helper
is found. The installer uses an AUR helper you already have (`paru` or
`yay`) and runs it as your user, never as root. It never installs an AUR
helper, and official packages never go through it. `--non-interactive`
without `--enable-aur` never uses the AUR. Without these packages, the AccessX
controls report as unavailable and everything else works.

### Dolphin File Manager

The `full` profile installs Dolphin as the managed file manager. Thunar and
Path are not part of this fork. `archlinux-xdg-menu` supplies the
applications menu that Dolphin's "Open With" needs outside Plasma.

Dolphin's terminal action reads the terminal from `~/.config/kdeglobals`. When
that file is absent, the installer seeds it with the selected terminal. An
existing `kdeglobals` is preserved. To select Dolphin on an existing account,
use Settings > Default Applications or:

```bash
dwm-default-apps set-role file-manager org.kde.dolphin.desktop
```

### GNOME Keyring

Every profile includes `gnome-keyring` for credential storage. On Arch it also
ships the `pam_gnome_keyring.so` module, and Arch's LightDM PAM configuration
already loads it. If you start the session with `startx`, automatic unlock at
password login requires adding the module to `/etc/pam.d/login` yourself; the
installer never edits PAM files. Unlock also requires matching account and
keyring passwords, and autologin does not supply a password to this path. See
[keyring troubleshooting](/troubleshooting.html#login-keyring-asks-for-a-password-every-login).

### What the Installer Preserves

Existing `config.h`, user TOML files, `.xinitrc`, and application configuration
are preserved. A missing `config.h` is created from guided compile-time
questions, or from detected defaults for an unattended run. System files are
installed with `sudo`, while configuration and data under the user's XDG
directories are installed as that user. The managed
`${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/` directory is replaced from the
repository so it matches the installed helpers.

Upgrades remove the known legacy `dwm-graphical-session.service` and
`wm-graphical-session.service` early-start configuration so XDG applications
start only after the X11 display environment is available. Customized user
units are disabled from early startup but otherwise preserved.

When matching vendor XDG entries exist for Picom, the polkit agent, or Light
Locker, the installer copies each entry to the user autostart directory and
adds only the dwm session exclusion. Original commands and vendor session
guards remain intact, no entry is created when the vendor entry is absent, and
existing user entries are preserved.

The session portal preference is
`~/.config/xdg-desktop-portal/dwm-portals.conf`, which applies only to the dwm
session. A user install removes the old desktop-wide `portals.conf` only when
it is unmodified from the previous seed; edited copies are kept.

Arch's `/etc/xdg/picom.conf` uses Picom's newer `rules` syntax. The installer's
Quickshell tooltip opacity tweak recognizes only the legacy `opacity-rule`
entry, so it leaves the file unchanged and prints a warning.

The `dwm-titus` agent skill ships in the managed data copy at
`~/.local/share/dwm-titus/config/agents/skills/`, which installs and desktop
updates replace. When `~/.claude` exists, the installer links
it as `~/.claude/skills/dwm-titus`; when `~/.agents` or `~/.codex` exists, it
links it as `~/.agents/skills/dwm-titus` for Codex and other Agent Skills
clients. An existing entry with that name is preserved, and no agent directory
is created for an agent that is not set up.

Meslo Nerd Font comes from the `ttf-meslo-nerd` package. The installer's
checksum-verified Meslo download runs only when that font is not detected.

### Herdr

Every profile defaults to Alacritty without Herdr. With `--install-herdr` (or
`DWM_INSTALL_HERDR=true`), the repository downloads the official
`https://herdr.dev/install.sh` into an isolated staging directory and verifies
repository-pinned SHA-256 checksums for both that installer and its resulting
Herdr binary before copying it into `~/.local/bin`. A checksum mismatch or
network failure leaves Alacritty usable and reports the Herdr failure. When the
`codex` or `claude` command is already available, the helper also runs Herdr's
matching `integration install` command so native Codex and Claude Code sessions
can be restored. Integration failures are reported separately from binary
installation failures.

Installation alone does not change the terminal default; set `DWM_HERDR=1` and
run `dwm-terminal` to enter the optional workspace. Herdr can also be installed
or repaired separately:

```bash
install-herdr
install-herdr --force
```

Upgrades preserve an existing `hotkeys.toml`. If an earlier installer seeded
its `terminal` variable to `dwm-terminal`, set it to `alacritty` to adopt the
current direct-terminal default. The installer does not overwrite that
user-owned choice.

## First Login

`Super` is usually the Windows key. Open the file manager with `Super+E`, open
a terminal with `Super+X`, take a full screenshot with `Super+P`, select a
region with `Super+Shift+P`, or copy a region to the clipboard with
`Super+Ctrl+P`.

## Package Updates

Settings > System lists pending system updates, and the Update Center shows
them on a system row labeled with your distribution name (for example "Arch
Linux"). Both are read-only until you start an update: discovery uses pyalpm
in a private copy of the databases and never refreshes the real sync
databases, so checking cannot leave the system partially upgraded.

Choose **Open system update** in Settings or **Update** on the Update Center
system row. Both open the same terminal, which:

1. Stops with `sudo fuser -v /var/lib/pacman/db.lck` guidance if another
   pacman holds the database lock. The lock is never deleted.
2. Fetches the Arch Linux news feed and lists unread items. Type `y` or `yes`
   to continue. Your acknowledgement is saved in
   `~/.local/state/dwm-titus/update-center/news-ack.json` only when you
   continue. If the feed cannot be fetched, the terminal says news is
   unavailable and still asks.
3. Runs `sudo pacman -Syu` with pacman's own prompts. `--noconfirm` is never
   added, so review the transaction before confirming.

pacman never rolls back. If an update is interrupted, choose **Recover** in the
Update Center: it shows the last known result, points to
`/var/log/pacman.log`, and offers a fresh `sudo pacman -Syu`. You can always
run the same command in any terminal:

```bash
sudo pacman -Syu
```

If `paru` or `yay` is already installed, the Update Center also shows an
optional AUR row. It checks your foreign packages against the AUR and updates
them with `paru -Sua` or `yay -Sua` as your user, never as root. Packages
ending in `-git`, `-svn`, `-hg`, or `-bzr` show "version unknown" and are not
counted. dwm-titus never installs an AUR helper.

Never run `pacman -Sy` on its own.

## Source Updates and Recovery

Settings > System offers **Desktop updates** above the system package section.
It checks `main` of this fork (`github.com/moheladwy/dwm-titus-archlinux`),
detects stale managed files, and installs a confirmed update with progress and
recovery records. Missing dependencies are checked with `pacman -T` and
installed with `pacman -S --needed` only when no system updates are pending;
otherwise the update stops with "Update system packages first". Run
`sudo pacman -Syu`, then try again. An installation recorded from upstream
`ChrisTitusTech/dwm-titus` is not trusted by the updater; reinstall from this
repository with `./install.sh` to record the new source. See
[Desktop updates and recovery](https://github.com/moheladwy/dwm-titus-archlinux/blob/main/docs/DESKTOP-UPDATES.md)
for the update contract, restart behavior, and interrupted-operation recovery.

Before a source update, save the current checkout and user configuration. Run
this from the checkout as your regular user in Bash, with desktop settings
closed so they cannot change during the backup:

```bash
repo_dir=$(pwd -P)
backup_dir=$(mktemp -d "$HOME/dwm-titus-backup.XXXXXX") || exit 1
chmod 700 "$backup_dir" || exit 1
tar -C "$repo_dir" -cpf "$backup_dir/source.tar" . || exit 1
printf 'export XDG_CONFIG_HOME=%q\nexport XDG_DATA_HOME=%q\n' \
    "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" \
    >"$backup_dir/xdg.env"
python3 - "$repo_dir/config.h" "${XDG_CONFIG_HOME:-$HOME/.config}" \
    "$HOME/.xinitrc" "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    >"$backup_dir/user-paths.nul" <<'PYTHON' || exit 1
import os
import sys

pending = [os.path.abspath(p) for p in sys.argv[1:] if os.path.lexists(p)]
seen = set()
while pending:
    original = pending.pop()
    # Canonicalize parents, retaining a final symlink as its own archive entry.
    path = os.path.join(os.path.realpath(os.path.dirname(original)), os.path.basename(original))
    if path in seen:
        continue
    seen.add(path)
    if os.path.islink(path):
        target = os.path.realpath(path)
        if not os.path.exists(target) or not os.access(target, os.W_OK):
            sys.exit("Back up this missing or read-only link target separately: " + path)
        pending.append(target)
    elif os.path.isdir(path):
        pending.extend(entry.path for entry in os.scandir(path))
for path in sorted(seen):
    sys.stdout.buffer.write(os.fsencode(path.lstrip("/")) + b"\0")
PYTHON
tar -C / --null --no-recursion -cpf "$backup_dir/user.tar" \
    -T "$backup_dir/user-paths.nul" || exit 1
printf 'Recovery backup: %s\n' "$backup_dir"
```

The source archive includes your `config.h` and Git state. Keep the backup
private: application configuration can contain credentials. This backs up
source and configuration, not Arch packages or all personal data. The user
archive records the effective XDG paths, symlink layout, and the contents of
referenced writable targets, including dotfiles outside the checkout. A missing
or read-only link target stops the recipe; resolve it or back it up separately
before updating. Keep the XDG parent-directory layout unchanged during recovery.

For a clean tracked checkout, update and synchronize the installed files:

```bash
git status --short
git pull --ff-only || exit 1
./install.sh --yes --profile recommended || exit 1
./scripts/dev-sync-install.sh
```

The installer starts with its full `sudo pacman -Syu` and pacman's own prompt.
Resolve local source changes before pulling. The installer preserves existing
user TOML files, `config.h`, `.xinitrc`, and application configuration. It
replaces the managed Quickshell directory to match the installed helpers.
Log out and select dwm again, then run:

```bash
./scripts/dev-sync-install.sh --check
dwm-diagnostics
```

If an update is interrupted, retain its log and rerun the same installer and
synchronization commands after fixing the reported cause. Do not interrupt an
active pacman transaction or delete the pacman lock as a recovery technique.
If the desktop is unusable, switch to a TTY with Ctrl+Alt+F3 and log in as the
same user.

To restore a backup, set `backup_dir` to the exact path printed above. Close the
desktop session first. The following restores the saved configuration and link targets over their
recorded paths and builds the saved source in a separate directory, leaving the
failed checkout available for inspection:

```bash
test -f "$backup_dir/source.tar" && test -f "$backup_dir/user.tar" || exit 1
restore_dir=$(mktemp -d "$HOME/dwm-titus-restored.XXXXXX") || exit 1
tar -C "$restore_dir" -xpf "$backup_dir/source.tar" || exit 1
tar -C / --keep-directory-symlink -xpf "$backup_dir/user.tar" || exit 1
source "$backup_dir/xdg.env"
cd "$restore_dir" || exit 1
./install.sh --yes --profile recommended || exit 1
./scripts/dev-sync-install.sh
```

Log in again and run `./scripts/dev-sync-install.sh --check` from the restored
checkout. Keep both directories until runtime verification passes. This
procedure does not downgrade packages, remove files created after the backup,
or undo external service and firmware changes. pacman owns package recovery;
desktop rollback does not uninstall packages.

### Development Checkouts

`scripts/dev-sync-install.sh` builds the checkout and synchronizes the binary,
installed helpers, managed Quickshell configuration, and data copy into the
live installation at one revision. Use it after the first `./install.sh` run;
it does not install a profile. When source-update dependencies are missing, it
installs them together with a full upgrade (`sudo pacman -Syu --needed`). Run
`./scripts/dev-sync-install.sh --check` after any requested session restart to
verify the active runtime.

## Starting dwm

**Display manager** (SDDM, GDM, LightDM): log out and select **dwm** from the session list.

When the interactive installer runs inside an active X11 session, it offers
the `dwm-display-setup` wizard after installation. The wizard previews the
chosen resolution and multi-monitor layout, then installs a backed-up Xorg
fragment. Installations run from a TTY or in non-interactive mode defer this
step; after the first X11 login, run:

```bash
dwm-display-setup
```

The installed Settings display provider is machine-oriented. Its actions are:

```text
dwm-settings-display discover
dwm-settings-display watch
dwm-settings-display save NAME SPEC...
dwm-settings-display preview TOKEN SECONDS SPEC...
dwm-settings-display preview-profile TOKEN SECONDS NAME
dwm-settings-display keep TOKEN [NAME]
dwm-settings-display revert TOKEN
dwm-settings-display preview-status [TOKEN]
dwm-settings-display install-profile NAME
dwm-settings-display rollback-system
```

Discovery and live previews require `xrandr`, and the hotplug watch requires
`udevadm`. Persistent install and rollback additionally require `pkexec` plus
the root-owned helper installed at `${PREFIX}/libexec/dwm-titus/`. Profiles are
stored under
`${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/display-profiles/`. No move is
needed for profiles created by `dwm-display-profile`, which uses the same
directory. If `DWM_DISPLAY_PROFILE_DIR` previously pointed elsewhere, either
keep that environment override or move those `.conf` files into the default
directory before using Settings.

The input provider exposes the corresponding session actions:

```text
dwm-settings-input discover
dwm-settings-input watch
dwm-settings-input watch-apply
dwm-settings-input apply-saved
dwm-settings-input preview TOKEN SECONDS DEVICE SETTING VALUE
dwm-settings-input keep TOKEN
dwm-settings-input revert TOKEN
dwm-settings-input preview-status [TOKEN]
dwm-settings-input reset DEVICE SETTING
```

Input discovery and per-device actions require `xinput`; keyboard layout and
modifier operations also require `setxkbmap`; session-wide XKB accessibility
controls require `xkbset`, which is AUR-only and installed only with
`--enable-aur`; stable hardware identity and hotplug watching use `udevadm`,
and the session watcher uses `flock` from `util-linux` to prevent duplicate
replay workers. Kept values default to
`${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/input-settings.conf`. Set
`DWM_INPUT_SETTINGS_FILE` to use a different file. The normal session startup
invokes `apply-saved` idempotently and runs `watch-apply` to debounce input
hotplug events before replaying saved values for returning devices.

**startx:**
```bash
startx
```

The provided `.xinitrc` disables screen blanking, starts the configured Quickshell panel, and runs dwm.

## Minimal Session Profile

The minimal supported profile is useful for lean Arch systems and recovery
sessions. It keeps only:

- an X11 server and either a display-manager session or `startx`
- D-Bus session support
- `dwm`
- Alacritty as the default terminal, with `dwm-terminal` available to delegated
  tools that require fallback selection
- required X11 helpers used by core startup and display commands, such as
  `xrandr`, `xset`, and `xsetroot`

Quickshell, Picom, Feh, Dex, a polkit agent, screenshot tools, wallpapers, tray
utilities, and audio or brightness helpers are optional in this profile.
Missing optional components should appear as degraded features in
`dwm-diagnostics`, not as session-fatal failures.

For `startx`, a minimal `.xinitrc` can be:

```sh
#!/bin/sh
xset s off
xset -dpms
xsetroot -cursor_name left_ptr
exec dbus-run-session dwm
```

If the login path already creates a user D-Bus session, use `exec dwm`
instead of wrapping it with `dbus-run-session`.

After installation, verify the profile with:

```bash
dwm-diagnostics
dwm-terminal --print-command
```

`dwm-diagnostics` must report zero required failures before treating the
minimal profile as ready. Optional degraded features can remain unresolved.
The default binding opens Alacritty directly. A plain `dwm-terminal` also opens
the selected emulator directly unless `DWM_HERDR=1` explicitly enables Herdr.
Commands such as `dwm-terminal -e sh -c 'command'` always bypass Herdr.

### Flatpak Prerequisites

Recommended and full installs install the Arch `flatpak` package before
configuring the official Flathub remote for the target user. Gear Lever
setup verifies the remote matching an existing app, or prepares the user remote
before a new installation. Repeated setup preserves existing apps and remotes;
an unreadable, disabled, or conflicting Flathub remote stops dependent installs
with an error. Flathub is the only third-party repository the installer adds.

After resolving a setup failure, retry `scripts/install-gearlever` from the
source checkout. To prepare the user remote independently, run
`scripts/dwm-flatpak-setup --user`. If Flatpak is missing, rerun
`./install.sh --profile recommended` first.
