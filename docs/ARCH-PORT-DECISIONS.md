# Arch Linux Port Decisions

This fork replaces Fedora with Arch Linux. The port was planned in phases, and
the owner settled the decisions below before implementation. They are final
unless the owner changes them, and `SPEC.md` and `AGENTS.md` implement them.
The working plan itself is kept outside the repository; this file is the
tracked record.

## Decisions

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Platform model | Arch Linux only. Fedora support, the Fedora images, and Fedora-only code are removed. Arch uses the family-keyed package map (`dwm_packages arch <profile>`) behind one `dwm_platform_family` helper. |
| D2 | Accepted identities | Plain Arch only: `ID=arch`. `ID_LIKE` is ignored. EndeavourOS, CachyOS, Manjaro, Arch Linux ARM, and every other identity are rejected before any system change, with no override flag. |
| D3 | AUR policy | Use an existing `paru` or `yay` only; never bootstrap one. AUR installs are opt-in (`--enable-aur`) and run as the invoking user. Official packages never go through the helper. Root and pkexec helpers never call an AUR helper or `makepkg`. |
| D4 | Update backend | Native pacman: unprivileged pyalpm discovery in a private database copy, and an interactive `sudo pacman -Syu` in a terminal. No PackageKit. |
| D5 | Settings updates | No in-place package mutation in Settings. "Open system update" opens the Update Center terminal flow, because pacman's prompts (replacements, conflicts, providers, `.pacnew` notices) have no safe machine defaults. |
| D6 | Update Center provider | The distribution provider is `system`, labelled from `os-release` `NAME`. State recorded under the former `fedora` id is migrated or rescanned. |
| D7 | Installer upgrade policy | The installer runs one visible `sudo pacman -Syu` before any package step. It appears in `--dry-run`, uses pacman's own prompt, adds `--noconfirm` only with `--non-interactive`, and never runs `pacman -Sy` alone. |
| D8 | pacman.conf | Ship no `pacman.conf` changes. pacman already prompts `[Y/n]` and downloads in parallel by default. |
| D9 | Arch news | Before `-Syu` in the Update Center, fetch the Arch Linux news feed (bounded and failure tolerant), show unacknowledged items, and require an explicit Continue. |
| D10 | Images and hosting | Host nothing: no installer ISO, no project package repository, no download server, and no signing keys. Users install Arch Linux themselves and then run `./install.sh`. Source releases stay as GitHub release tarballs. |
| D11 | Gaming | No gaming dependencies or integrations: no gaming profile, repository prompts, `gamemode` group handling, or multilib requirement. |
| D12 | File manager | Path is dropped and Dolphin replaces Thunar as the managed file manager, in the same install profile Thunar used. |
| D13 | LSM policy | Arch configures no LSM by default. The installer never changes SELinux, AppArmor, or other LSM state. |
| D14 | Packaging | Installation stays `make install` through `install.sh`. A PKGBUILD may come later; it would need `/usr/lib/$pkg` for helpers and a session name that does not clash with the AUR `dwm` package. |

## Phases

| Phase | Outcome | Pull request |
| --- | --- | --- |
| 0 | Contract: SPEC, AGENTS, and user docs describe the Arch-only product. | #1 |
| 1 | Fork identity: self-updates and links point at this fork. | #1 |
| 2 | Platform identity and the Arch package map. | #1 |
| 3 | Pinned Arch test container, CI, and Qt 6 QML lint. | #1 |
| 4 | Existing-system installer and runtime integrations. | #1 |
| 5 | Read-only pacman update discovery. | #2 |
| 6 | Package updates through the terminal only. | #2 |
| 7 | Desktop-update dependencies through pacman, and the optional AUR provider. | #1 and #2 |
| 8 | Remaining Settings platform work. | #2 |
| 9 | Documentation sweep. | #3 |
| 10 | Removal of Fedora-only, image, first-boot, DNF, and gaming code. | #3 |

## Recorded deviations

- Package-state change events come from inotify on `/var/lib/pacman` rather
  than a pacman hook, so no system file is installed for them.
- The desktop updater's pacman dependency path (part of Phase 7) landed with
  Phases 0-4, because the Arch test gate could not pass without it.
- Bugs found while validating on Arch were fixed in the pull request where
  they surfaced, and each is recorded in `CHANGELOG.md`.
