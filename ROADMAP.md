# Arch Linux Port Roadmap

## Current scope

Replace Fedora with Arch Linux as the only supported platform for this fork
(`github.com/moheladwy/dwm-titus-archlinux`). The approved plan, with final
decisions D1-D14, is [arch-linux-port.md](.github/plans/arch-linux-port.md).
Installer images, hosted package repositories, signing keys, and gaming
integrations are out of scope.

Each phase is one independently testable review boundary. The current pull
request covers Phases 0-4. Phases 5-10 are future work and must not start in
that pull request. Merge, release publication, and deployment require explicit
owner authorization.

## Phases

0. Contract change: `SPEC.md`, `AGENTS.md`, and the contributor and user docs
   make Arch Linux (`ID=arch` only) the documented target and record the
   pacman, AUR, and validation rules.
1. Fork endpoints and identity: desktop updates, the Update Center, metadata,
   and issue templates point at this fork instead of upstream.
2. Platform identity and package map: one `dwm_platform_family` helper and
   `arch:<profile>` entries in `scripts/dwm-packages.sh`, including the
   `aur-optional` profile, with platform and package tests.
3. Test container, CI, and QML lint: `tests/containers/arch/Containerfile`
   pinned to an Arch Linux Archive snapshot, `scripts/run-tests-podman` and CI
   on that image, and Qt 6 `qmllint` selection.
4. Existing-system installer and runtime: Arch install path with one up-front
   `sudo pacman -Syu`, `--enable-aur`, gaming removed, Dolphin replacing
   Thunar and Path, LightDM with `lightdm-slick-greeter`, keyring checks, and
   Arch wording in runtime helpers.
5. Update stack, read-only discovery: an unprivileged pyalpm provider and a
   pacman hook replace PackageKit discovery. (Future.)
6. Update stack, mutation: confirmed updates run as interactive
   `sudo pacman -Syu` in a terminal; PackageKit paths are removed. (Future.)
7. Desktop-update dependencies through pacman with a pending-update preflight
   (landed with Phases 0-4, because the Arch gate needed it), and an optional
   user-scope AUR provider. (AUR provider: future.)
8. Remaining Settings and system-management platform work. (Future.)
9. Documentation site and reference-doc sweep. (Future.)
10. Retire Fedora-only, image, and gaming code. (Future.)

Exit for the current pull request: Phases 0-4 meet their plan validation, with
evidence that separates host-safe checks, Arch container runs, VM installs, and
nested X11 runtime checks, and states every path that was not tested.

## History

The previous active phase was the Fedora 0.7.2 initial-update work (issues
#347, #344, #346, and #345). It is recorded in `CHANGELOG.md` under 0.7.2,
[INITIAL-UPDATE-QUALIFICATION.md](docs/INITIAL-UPDATE-QUALIFICATION.md), and
[P8-QUALIFICATION.md](docs/P8-QUALIFICATION.md). Earlier roadmap detail is
archived in [COMPLETED-ROADMAP-20260911.md](docs/COMPLETED-ROADMAP-20260911.md).
