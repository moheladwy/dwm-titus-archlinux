# LightDM Slick Greeter - dwm-titus

A LightDM login screen for Arch Linux using Slick Greeter with a Nord colour
palette, blurred background, and the MesloLGS NF font.

Arch packages the greeter as `lightdm-slick-greeter`. The dwm-titus LightDM
install target renders an Arch `lightdm.conf` that selects that greeter, the
`dwm` session, and the packaged `/etc/lightdm/Xsession` session wrapper. An
existing different `lightdm.conf` is backed up first.

## Files

| File | Destination |
|------|-------------|
| `lightdm.conf` | `/etc/lightdm/lightdm.conf` |
| `slick-greeter.conf` | `/etc/lightdm/slick-greeter.conf` |
| `wallpaper.jpg` | `/usr/share/pixmaps/dwm-titus.jpg` |

## Install

The main `install.sh` handles this automatically. To apply manually:

```sh
sudo make install
```

The direct `make install` defaults match Arch Linux. Prefer the top-level
`install.sh` for a complete installation.

## Customisation

Edit `slick-greeter.conf` before running `sudo make install`:

- **background** — path to a wallpaper image
- **font-name** — any font already installed on the system
- **clock-format** — strftime-style format string
- **theme-name** — GTK theme for the panel (e.g. `Adwaita-dark`)
- **show-clock** / **show-hostname** — toggle status bar items
- **activate-numlock** — enable only when `numlockx` is installed
