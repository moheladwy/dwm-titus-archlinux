# LightDM Slick Greeter - dwm-titus

A LightDM login screen for Arch Linux using Slick Greeter with a Nord colour
palette, blurred background, and the MesloLGS NF font.

Arch packages the greeter as `lightdm-slick-greeter`. The dwm-titus LightDM
install target adds a drop-in, `/etc/lightdm/lightdm.conf.d/50-dwm-titus.conf`,
that enables `logind-check-graphical` and selects that greeter and the `dwm`
session. It never creates, replaces, or edits `/etc/lightdm/lightdm.conf`.

LightDM reads `lightdm.conf.d/*.conf` drop-ins before `lightdm.conf`, so any
value set in `lightdm.conf` takes precedence over the drop-in. Local settings
such as `autologin-user` are preserved, and Arch's packaged `lightdm.conf`
keeps providing the `/etc/lightdm/Xsession` session wrapper. To override a
dwm-titus choice, set the key in `lightdm.conf` or in a later-sorting drop-in.

## Files

| File | Destination |
|------|-------------|
| `50-dwm-titus.conf` | `/etc/lightdm/lightdm.conf.d/50-dwm-titus.conf` |
| `slick-greeter.conf` | `/etc/lightdm/slick-greeter.conf` |
| `wallpaper.jpg` | `/usr/share/pixmaps/dwm-titus.jpg` |
| `../dwm-titus.png` | `/usr/share/pixmaps/dwm-titus-logo.png` |

## Install

The main `install.sh` handles this automatically. To apply manually:

```sh
sudo make install
```

The direct `make install` defaults match Arch Linux and honour `DESTDIR`.
Prefer the top-level `install.sh` for a complete installation.

## Customisation

Edit `slick-greeter.conf` before running `sudo make install`:

- **background** - path to a wallpaper image
- **font-name** - any font already installed on the system
- **clock-format** - strftime-style format string
- **theme-name** - GTK theme for the panel (e.g. `Adwaita-dark`)
- **show-clock** / **show-hostname** - toggle status bar items
- **activate-numlock** - enable only when `numlockx` is installed
