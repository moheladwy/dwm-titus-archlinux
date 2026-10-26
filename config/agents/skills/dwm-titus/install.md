# Installing dwm-titus

dwm-titus installs onto an Arch Linux system that the user has already
installed (official ISO by hand, or `archinstall`). The project ships no ISO,
image, or package repository. Everything goes through `./install.sh` in a Git
checkout.

## Preconditions

Check all of these before installing. Stop and explain if one fails.

```sh
. /etc/os-release && test "$ID" = arch && echo "Arch Linux"   # exact ID=arch
test "$(uname -m)" = x86_64 && echo "x86_64"
test "$(id -u)" -ne 0 && echo "normal user"                     # never root
command -v sudo git
sudo -v                                                          # user can sudo
ping -c1 -W3 archlinux.org >/dev/null && echo "network ok"
```

- Derivatives (EndeavourOS, CachyOS, Manjaro, Arch Linux ARM) are rejected by
  the installer with no override. Do not edit `/etc/os-release` or the check.
- The installer needs a terminal on standard input. Without one it refuses to
  run unless `--non-interactive` (or `--dry-run`) is given.

## Installer reference

```sh
./install.sh --dry-run --non-interactive --profile PROFILE   # plan only, no changes
./install.sh --profile PROFILE                               # interactive install
```

| Option | Effect |
| --- | --- |
| `--profile core\|recommended\|full` | Package set. Default `full` (or `$DWM_INSTALL_PROFILE`). `minimal` = `core`. |
| `--dry-run` | Print the full plan, including the system upgrade, then exit. |
| `--yes` | Accept the install summary. pacman still asks for its own confirmation. |
| `--non-interactive` | No prompts; adds `--noconfirm` to pacman. Only on explicit request. |
| `--enable-aur` | Install the optional AUR extras with an existing `paru` or `yay`. |
| `--install-herdr` / `--skip-herdr` | Optional Herdr terminal workspace (default: skip). |

Profiles:

- `core`: build tools, the X11 session, GNOME Keyring, Celluloid, mpv, sxiv,
  and Alacritty. No panel or display manager.
- `recommended`: `core` plus the full everyday desktop: Quickshell panel,
  Picom, wallpaper, polkit agent, audio, Bluetooth, power and brightness
  tools, Flatpak with Flathub (user remote) and Gear Lever, fonts, icons,
  GTK/Qt themes, and the Settings system-management tools. No display
  manager.
- `full`: `recommended` plus Dolphin, NetworkManager, `gvfs`,
  `xdg-user-dirs`, wallpapers, and LightDM when no display manager is found.

What the installer does, in order: Arch check, plan and summary, one visible
`sudo pacman -Syu` (aborts the install if it fails or is declined), official
packages with `sudo pacman -S --needed --`, optional AUR extras, build
options (`scripts/configure-build.sh` asks for refresh rate, font size,
modifier key, and layout defaults when `config.h` is missing), display
manager handling, `make` as the user, `sudo make install` (system files to
`/usr/local`, user files as the user), default apps, Gear Lever, and the
display wizard when run inside an X11 session.

For an unattended run, the build questions take their answers from
`DWM_REFRESH_RATE`, `DWM_FONT_SIZE`, `DWM_MODKEY`, `DWM_MFACT`,
`DWM_NMASTER`, `DWM_CURSORWARP`, `DWM_SWALLOWFLOATING`, and
`DWM_RESIZEHINTS`, with detected defaults otherwise.

Agent shells usually have no terminal on standard input and cannot answer
`sudo` or pacman prompts. Run the dry run yourself, then hand the user the
real install command to run in their own terminal, unless they explicitly ask
for an unattended `--non-interactive` run.

The installer preserves an existing `config.h`, user TOML files,
`~/.xinitrc`, application configuration, and `mimeapps.list`. It **replaces**
`~/.config/quickshell/` entirely. It never removes packages and never edits
`pacman.conf`, PAM, or the bootloader.

Always show the user the dry-run plan and get a go-ahead before the real run.

## A. Fresh or minimal Arch (no desktop yet, including servers)

A minimal Arch install with a user account, `sudo`, and network is enough.
No desktop environment or display manager is needed first.

1. **Make sure a sudo user exists.** If only root exists, ask the user before
   creating an account, then as root:

   ```sh
   pacman -Syu --needed sudo git
   useradd -m -G wheel USERNAME
   passwd USERNAME
   printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
   chmod 0440 /etc/sudoers.d/10-wheel
   visudo -c    # must report the sudoers files as parsed OK
   ```

   Log in as that user for every following step.

2. **Graphics driver.** Xorg needs a working driver. Intel, AMD, and most
   virtual machines work with the kernel modesetting driver built into
   `xorg-server`. NVIDIA needs its driver package (for example
   `nvidia-open`, chosen per the ArchWiki NVIDIA page), installed with a full
   upgrade: `sudo pacman -Syu --needed nvidia-open`. In a virtual machine,
   give it a virtio-gpu or QXL display.

3. **Clone, dry-run, install.** `full` is the right profile for a fresh
   system, because it adds LightDM so there is a graphical login:

   ```sh
   sudo pacman -Syu --needed git
   git clone https://github.com/moheladwy/dwm-titus-archlinux.git
   cd dwm-titus-archlinux
   ./install.sh --dry-run --non-interactive --profile full
   ./install.sh --profile full
   ```

4. **Over SSH.** Use `ssh -t` so `sudo` and pacman can prompt. Only when the
   user explicitly wants an unattended run:

   ```sh
   ./install.sh --non-interactive --yes --profile full
   ```

   That adds `--noconfirm` to pacman, so state it to the user first.

5. **Start the session.** Reboot (or `sudo systemctl start lightdm`), then pick
   the **dwm** session. With no display manager (`core`/`recommended`), log in
   on a TTY and run `startx`; the seeded `~/.xinitrc` starts dwm.

A headless server with no monitor or virtual console cannot show the desktop.
dwm-titus does not set up VNC, RDP, or other remote displays; say so if the
user expects remote graphical access.

## B. Existing Arch desktop

The user already has another desktop or display manager.

1. Run the dry run and review it with the user:

   ```sh
   ./install.sh --dry-run --non-interactive --profile recommended
   ```

2. **Back up an existing Quickshell setup.** If `~/.config/quickshell/` holds
   another shell (for example DankMaterialShell or Caelestia), the install
   replaces it. Copy it first:
   `cp -a ~/.config/quickshell ~/.config/quickshell.bak.$(date +%s)`.
   Do not run another Quickshell shell alongside the dwm-titus panel.

3. **Display manager.** Find the active one:

   ```sh
   readlink -f /etc/systemd/system/display-manager.service
   ```

   - GDM and SDDM are detected and kept. Log out and choose **dwm**.
   - LightDM is detected and kept, but the installer then makes
     `lightdm-slick-greeter` the greeter and `dwm` the default session (drop-in
     `/etc/lightdm/lightdm.conf.d/50-dwm-titus.conf`; `lightdm.conf` is
     untouched) and replaces `/etc/lightdm/slick-greeter.conf`. On this path
     it does not install the greeter, so a LightDM that uses another greeter
     would be left without a login screen. Tell the user about both changes,
     back up `/etc/lightdm/slick-greeter.conf` if it exists, and install the
     greeter first: `sudo pacman -Syu --needed lightdm-slick-greeter`.
   - Other display managers (ly, greetd, lxdm, xdm, and so on) are not
     detected. With `--profile full`, the installer then installs LightDM and
     runs `systemctl enable lightdm.service`, which fails while another
     display manager owns `display-manager.service`, and the installer stops
     there. Use `--profile recommended` on those systems, then select the dwm
     session (it is installed as `/usr/share/xsessions/dwm.desktop`), or add
     the missing `full` apps by hand afterwards.

4. **Install:**

   ```sh
   ./install.sh --profile recommended
   ```

   Rerun with `--profile full` later to add the larger profile; the dry run
   shows what it adds.

5. Other desktops keep working. The portal preference
   (`~/.config/xdg-desktop-portal/dwm-portals.conf`) applies only to the dwm
   session.

## Optional AUR extras

Only `xkbset` (AccessX keyboard accessibility) and the Arc, Numix, Yaru, and
Bluebird GTK themes come from the AUR. They are installed only with
`--enable-aur` or a "yes" to the installer's `[y/N]` question, and only when
`paru` or `yay` already exists. Without them, those controls show as
unavailable and everything else works.

## GNOME Keyring with startx

LightDM already unlocks the login keyring. For `startx` from a TTY, automatic
unlock needs `pam_gnome_keyring.so` in `/etc/pam.d/login` (see the ArchWiki
"GNOME/Keyring" PAM step). The installer never edits PAM; only do it on an
explicit request and show the diff first.

## Verify the install

After logging into the dwm session:

```sh
dwm-diagnostics                         # zero required failures expected
cd ~/dwm-titus-archlinux                # the clone install.sh ran from
./scripts/dev-sync-install.sh --check   # installed files match the checkout
```

First keys: `Super+X` terminal, `Super+R` launcher, `Super+E` file manager,
`Super+B` browser, `Super+F1` Control Center, `Super+/` keybinding list.
After an install from a TTY, run `dwm-display-setup` once in the session to
set resolution and monitor layout.

## Uninstall

From the checkout, `sudo make uninstall DATADIR=/usr/share` removes the
installed binaries, helpers, session file, themes, and cursors.
`DATADIR=/usr/share` matches what `install.sh` used. Uninstalling does not
remove packages, user configuration, the LightDM drop-in and
`slick-greeter.conf` (which still select the dwm session), a display-setup
Xorg fragment, or the agent skill links in `~/.claude/skills/` and
`~/.agents/skills/`. List those for the user and ask before removing any of
them, or anything under `~/.config` or `~/.local/share/dwm-titus`.
